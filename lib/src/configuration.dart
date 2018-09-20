import 'dart:io';
import 'dart:mirrors';

import 'package:safe_config/src/default_configurations.dart';
import 'package:yaml/yaml.dart';

/// Subclasses of [Configuration] read YAML strings and files, assigning values from the YAML document to properties
/// of an instance of this type.
abstract class Configuration {
  /// Default constructor.
  Configuration();

  Configuration.fromMap(Map<dynamic, dynamic> map) {
    _read(reflect(this).type, map);
  }

  /// [contents] must be YAML.
  Configuration.fromString(String contents) {
    final config = loadYaml(contents) as Map<dynamic, dynamic>;
    _read(reflect(this).type, config);
  }

  /// Opens a file and reads its string contents into this instance's properties.
  ///
  /// [file] must contain valid YAML data.
  Configuration.fromFile(File file) : this.fromString(file.readAsStringSync());

  /// Subclasses may override this method to read from something that is not a Map.
  ///
  /// Sometimes a configuration value can be represented in multiple ways. For example, a [DatabaseConfiguration]
  /// can be a [Map] of each component or a single URI [String] that can be decomposed into each component. Subclasses may override
  /// this method to provide this type of behavior. This method is executed when an instance of [Configuration] is ready to be parsed,
  /// but the value from the YAML is *not* a [Map]. By default, this method throws an exception.
  void decode(dynamic anything) {
    throw ConfigurationException(runtimeType, "Unexpected value '$anything'.");
  }

  /// Subclasses may override this method in order to validate the values of properties.
  ///
  /// This method is executed when an instance of [Configuration] is parsed.
  /// If it returns a nonempty list, the parser will thrown a ConfigurationException.
  List<String> validate() => [];

  static bool _isVariableRequired(VariableMirror m) {
    ConfigurationItemAttribute attribute = m.metadata
        .firstWhere((im) => im.type.isSubtypeOf(reflectType(ConfigurationItemAttribute)), orElse: () => null)
        ?.reflectee;

    return attribute == null || attribute.type == ConfigurationItemAttributeType.required;
  }

  static Map<String, VariableMirror> _getProperties(ClassMirror type) {
    var declarations = <VariableMirror>[];

    var ptr = type;
    while (ptr != null) {
      declarations.addAll(ptr.declarations.values
          .whereType<VariableMirror>()
          .where((vm) => !vm.isStatic && !vm.isPrivate));
      ptr = ptr.superclass;
    }

    final output = <String, VariableMirror>{};
    declarations.forEach((vm) {
      output[MirrorSystem.getName(vm.simpleName)] = vm;
    });
    return output;
  }

  void _read(TypeMirror type, dynamic object) {
    final expandErrorKeys = (Iterable keys) => keys.map((k) => "'$k'").join(",");
    final reflectedThis = reflect(this);
    final properties = _getProperties(reflectedThis.type);

    if (object is! Map) {
      decode(object);
    } else {
        properties.forEach((name, property) {
          final actualValue = _getActualValue(object[name]);
          if (actualValue == null) {
            return;
          }

          final value = _decode(property.type, name, actualValue);
          if (!property.type.isAssignableTo(reflect(value).type)) {
            throw ConfigurationException(runtimeType, "The value '${actualValue}' is not assignable to the field '$name'.");
          }

          reflectedThis.setField(property.simpleName, value);
        });

      final unexpectedKeys = (object as Map).keys.where((key) => !properties.keys.contains(key));
      if (unexpectedKeys.isNotEmpty) {
        throw ConfigurationException(runtimeType,
          "Extraneous keys found: '${expandErrorKeys(unexpectedKeys)}'");
      }
    }

    final requiredValuesThatAreMissing = properties.values.where(_isVariableRequired)
      .where((VariableMirror vm) => reflectedThis.getField(vm.simpleName).reflectee == null)
      .map((VariableMirror vm) => MirrorSystem.getName(vm.simpleName))
      .toList();

    if (requiredValuesThatAreMissing.isNotEmpty) {
      throw ConfigurationException(runtimeType,
        "Missing required values: ${expandErrorKeys(requiredValuesThatAreMissing)}");
    }

    final validationErrors = validate();
    if (validationErrors.isNotEmpty) {
      throw ConfigurationException(runtimeType,
        "Validation errors occurred: $validationErrors.");
    }
  }

  dynamic _getActualValue(dynamic input) {
    if (input != null && input is String && input.startsWith(r"$")) {
      final envKey = input.substring(1);
      if (!Platform.environment.containsKey(envKey)) {
        return null;
      }

      return Platform.environment[envKey];
    }

    return input;
  }

  dynamic _decode(TypeMirror type, String name, dynamic input) {
    if (input == null) {
      return null;
    }

    var value = input;
    if (value is String && value.startsWith(r"$")) {
      final envKey = value.substring(1);
      if (!Platform.environment.containsKey(envKey)) {
        return null;
      }

      value = Platform.environment[envKey];
    }

    if (type.isSubtypeOf(reflectType(int))) {
      if (value is String) {
        final out = int.tryParse(value);
        if (out == null) {
          throw ConfigurationException(runtimeType, "The value '${value}' could not be parsed as an integer, and therefore cannot be assigned to the field '$name'.");
        }
        return out;
      }
      return value;
    } else if (type.isSubtypeOf(reflectType(bool))) {
      if (value is String) {
        return value == "true";
      }

      return value;
    } else if (type.isSubtypeOf(reflectType(Configuration))) {
      return _decodeConfig(type, value);
    } else if (type.isSubtypeOf(reflectType(List))) {
      return _decodeList(type, name, value as List);
    } else if (type.isSubtypeOf(reflectType(Map))) {
      return _decodeMap(type, name, value as Map);
    } else if (type.isSubtypeOf(reflectType(String))) {
      return value;
    }

    return value;
  }

  Configuration _decodeConfig(TypeMirror type, dynamic object) {
    try {
      Configuration item = (type as ClassMirror)
        .newInstance(const Symbol(""), [])
        .reflectee;
      item._read(type, object);
      return item;
    } on NoSuchMethodError {
      throw ConfigurationError(runtimeType,
        "No default constructor found. Add '${type.reflectedType}();' to "
          "class declaration.");
    }
  }

  List<dynamic> _decodeList(TypeMirror typeMirror, String name, List value) {
    final decodedElements = value.map((v) => _decode(typeMirror.typeArguments.first, name, v));
    return (typeMirror as ClassMirror).newInstance(#from, [decodedElements]).reflectee as List;
  }

  Map<dynamic, dynamic> _decodeMap(TypeMirror typeMirror, String name, Map value) {
    final decoded = value.map((key, val) {
      return MapEntry(key, _decode(typeMirror.typeArguments.last, name, val));
    });

    Map map = (typeMirror as ClassMirror).newInstance(const Symbol(""), []).reflectee;
    decoded.forEach((k, v) {
      map[k] = v;
    });
    return map;
  }
}

/// Possible options for a configuration item property's optionality.
enum ConfigurationItemAttributeType {
  /// [Configuration] properties marked as [required] will throw an exception if their source YAML doesn't contain a matching key.
  required,

  /// [Configuration] properties marked as [optional] will be silently ignored if their source YAML doesn't contain a matching key.
  optional
}

/// [Configuration] properties may be attributed with these.
///
/// See [ConfigurationItemAttributeType].
class ConfigurationItemAttribute {
  const ConfigurationItemAttribute(this.type);

  final ConfigurationItemAttributeType type;
}

/// A [ConfigurationItemAttribute] for required properties.
const ConfigurationItemAttribute requiredConfiguration = ConfigurationItemAttribute(ConfigurationItemAttributeType.required);

/// A [ConfigurationItemAttribute] for optional properties.
const ConfigurationItemAttribute optionalConfiguration = ConfigurationItemAttribute(ConfigurationItemAttributeType.optional);

/// Thrown when reading data into a [Configuration] fails.
class ConfigurationException {
  ConfigurationException(this.type, this.message);

  /// The type of [Configuration] in which this exception occurred.
  final Type type;

  /// The reason for the exception.
  final String message;

  @override
  String toString() {
    return "Invalid configuration data for '$type'. $message";
  }
}

/// Thrown when [Configuration] subclass is invalid and requires a change in code.
class ConfigurationError {
  ConfigurationError(this.type, this.message);

  /// The type of [Configuration] in which this error appears in.
  final Type type;

  /// The reason for the error.
  String message;

  @override
  String toString() {
    return "Invalid configuration type 'type'. $message";
  }
}
