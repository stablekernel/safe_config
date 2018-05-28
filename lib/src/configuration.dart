import 'package:yaml/yaml.dart';
import 'dart:io';
import 'dart:mirrors';

/// Subclasses of [Configuration] read YAML strings and files, assigning values from the YAML to properties
/// of the subclass.
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
  /// If [name] is a relative path, it will be interpreted relative to the current working directory.
  /// If [name] is an absolute path, it will ignore the current working directory.
  Configuration.fromFile(String name) : this.fromString(new File(name).readAsStringSync());

  /// Subclasses may override this method to read from something that is not a Map.
  ///
  /// Sometimes a configuration value can be represented in multiple ways. For example, a DatabaseConnectionConfiguration
  /// can be a [Map] of each component or a single URI [String] that can be decomposed into each component. Subclasses may override
  /// this method to provide this type of behavior. This method is executed when an instance of [Configuration] is ready to be parsed,
  /// but the value from the YAML is *not* a [Map]. By default, this method throws an exception.
  void decode(dynamic anything) {
    throw new ConfigurationException(this.runtimeType, "Unexpected value '$anything'.");
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
    var declarations = List<VariableMirror>();

    while (type != null) {
      declarations.addAll(type.declarations.values
          .where((dm) => dm is VariableMirror && !dm.isStatic && !dm.isPrivate)
          .map((dm) => dm as VariableMirror));
      type = type.superclass;
    }

    return Map<String, VariableMirror>.fromIterable(declarations, key: (property) {
      return MirrorSystem.getName(property.simpleName);
    }, value: (property) {
      return property;
    });
  }

  void _read(TypeMirror type, dynamic object) {
    final expandErrorKeys = (Iterable keys) => keys.map((k) => "'$k'").join(",");
    final reflectedThis = reflect(this);
    final properties = _getProperties(reflectedThis.type);

    if (object is! Map) {
      decode(object);
    } else {
      properties.forEach((name, property) {
        final value = _decode(property.type, object[name]);
        reflectedThis.setField(property.simpleName, value);
      });

      final unexpectedKeys = (object as Map).keys.where((key) => !properties.keys.contains(key));
      if (unexpectedKeys.length > 0) {
        throw new ConfigurationException(runtimeType,
          "Extraneous keys found: '${expandErrorKeys(unexpectedKeys)}'");
      }
    }

    final requiredValuesThatAreMissing = properties.values.where((VariableMirror vm) => _isVariableRequired(vm))
      .where((VariableMirror vm) => reflectedThis.getField(vm.simpleName).reflectee == null)
      .map((VariableMirror vm) => MirrorSystem.getName(vm.simpleName))
      .toList();

    if (requiredValuesThatAreMissing.length > 0) {
      throw ConfigurationException(runtimeType,
        "Missing required values: ${expandErrorKeys(requiredValuesThatAreMissing)}");
    }

    final validationErrors = validate();
    if (validationErrors.length > 0) {
      throw new ConfigurationException(runtimeType,
        "Validation errors occurred: $validationErrors.");
    }
  }

  dynamic _decode(TypeMirror type, dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String && value.startsWith("\$")) {
      final envKey = value.substring(1);
      if (!Platform.environment.containsKey(envKey)) {
        return null;
      }

      value = Platform.environment[envKey];
    }

    if (type.isSubtypeOf(reflectType(int))) {
      if (value is String) {
        return int.parse(value);
      }
      return value;
    } else if (type.isSubtypeOf(reflectType(bool))) {
      return value == "true";
    } else if (type.isSubtypeOf(reflectType(Configuration))) {
      return _decodeConfig(type, value);
    } else if (type.isSubtypeOf(reflectType(List))) {
      return _decodeList(type, value);
    } else if (type.isSubtypeOf(reflectType(Map))) {
      return _decodeMap(type, value);
    }

    return value;
  }

  Configuration _decodeConfig(TypeMirror type, dynamic object) {
    try {
      Configuration item = (type as ClassMirror)
        .newInstance(new Symbol(""), [])
        .reflectee;
      item._read(type, object);
      return item;
    } on NoSuchMethodError {
      throw new ConfigurationError(runtimeType,
        "No default constructor found. Add '${type.reflectedType}();' to "
          "class declaration.");
    }
  }

  List<dynamic> _decodeList(TypeMirror typeMirror, YamlList value) {
    final decodedElements = value.map((v) => _decode(typeMirror.typeArguments.first, v));
    return (typeMirror as ClassMirror).newInstance(#from, [decodedElements]).reflectee;
  }

  Map<dynamic, dynamic> _decodeMap(TypeMirror typeMirror, YamlMap value) {
    final decoded = value.map((key, val) {
      return MapEntry(key, _decode(typeMirror.typeArguments.last, val));
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
const ConfigurationItemAttribute requiredConfiguration = const ConfigurationItemAttribute(ConfigurationItemAttributeType.required);

/// A [ConfigurationItemAttribute] for optional properties.
const ConfigurationItemAttribute optionalConfiguration = const ConfigurationItemAttribute(ConfigurationItemAttributeType.optional);

/// Thrown when reading data into a [Configuration] fails.
class ConfigurationException {
  ConfigurationException(this.type, this.message);

  /// The type of [Configuration] in which this exception occurred.
  final Type type;

  /// The reason for the exception.
  final String message;

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

  String toString() {
    return "Invalid configuration type 'type'. $message";
  }
}
