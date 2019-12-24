import 'dart:io';

import 'package:runtime/runtime.dart';
import 'package:yaml/yaml.dart';
import 'package:safe_config/src/intermediate_exception.dart';

/// Subclasses of [Configuration] read YAML strings and files, assigning values from the YAML document to properties
/// of an instance of this type.
abstract class Configuration {
  /// Default constructor.
  Configuration();

  Configuration.fromMap(Map<dynamic, dynamic> map) {
    decode(map.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)));
  }

  /// [contents] must be YAML.
  Configuration.fromString(String contents) {
    final yamlMap = loadYaml(contents) as Map<dynamic, dynamic>;
    final map =
        yamlMap.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
    decode(map);
  }

  /// Opens a file and reads its string contents into this instance's properties.
  ///
  /// [file] must contain valid YAML data.
  Configuration.fromFile(File file) : this.fromString(file.readAsStringSync());

  Map<String, ConfigurationProperty> get properties => _runtime.properties;

  ConfigurationRuntime get _runtime =>
      RuntimeContext.current[runtimeType] as ConfigurationRuntime;

  /// Ingests [value] into the properties of this type.
  ///
  /// Override this method to provide decoding behavior other than the default behavior.
  void decode(dynamic value) {
    if (value is! Map) {
      throw ConfigurationException(
          this, "input is not an object (is a '${value.runtimeType}')");
    }

    final valuesCopy = Map.from(value as Map);
    properties.forEach((name, property) {
      try {
        final takingValue = valuesCopy.remove(name);
        property.apply(this, takingValue);
      } on ConfigurationException catch (e) {
        throw ConfigurationException(this, e.message,
            keyPath: [name]..addAll(e.keyPath));
      } on TypeError catch (e) {
        throw ConfigurationException(this, "input is wrong type (${e.message})",
            keyPath: [name]);
      } on IntermediateException catch (e) {
        final underlying = e.underlying;
        if (underlying is TypeError) {
          throw ConfigurationException(
              this, "input is the wrong type (${underlying.message})",
              keyPath: [name]..addAll(e.keyPath));
        } else if (underlying is ConfigurationException) {
          final keyPaths = [
            [name],
            e.keyPath,
            underlying.keyPath
          ].expand((i) => i).toList();
          throw ConfigurationException(this, underlying.message,
              keyPath: keyPaths);
        }

        throw ConfigurationException(this, underlying.toString(),
            keyPath: [name]..addAll(e.keyPath));
      } catch (e) {
        throw ConfigurationException(this, e.toString(), keyPath: [name]);
      }
    });

    if (valuesCopy.isNotEmpty) {
      throw ConfigurationException(this,
          "unexpected keys found: ${valuesCopy.keys.map((s) => "'$s'").join(", ")}.");
    }

    validate();
  }

  /// Override this method to perform validations on input data.
  ///
  /// Return the empty array if there are no validation errors. If there are errors,
  /// return a description of them in an list of strings.
  void validate() {
    _runtime.validate(this);
  }
}

abstract class ConfigurationRuntime {
  Map<String, ConfigurationProperty> get properties;

  void validate(Configuration configuration);
}

abstract class ConfigurationProperty {
  ConfigurationProperty(this.key, {this.isRequired = true});

  final String key;
  final bool isRequired;

  static dynamic actualize(dynamic value) {
    if (value is String && value.startsWith(r"$")) {
      final envKey = value.substring(1);
      if (!Platform.environment.containsKey(envKey)) {
        return null;
      }

      return Platform.environment[envKey];
    }
    return value;
  }

  void apply(Configuration instance, dynamic input);

  bool decodeBool(dynamic value) {
    if (value is String) {
      return value == "true";
    }

    return value as bool;
  }

  int decodeInt(dynamic value) {
    if (value is String) {
      return int.parse(value);
    }

    return value as int;
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
const ConfigurationItemAttribute requiredConfiguration =
    ConfigurationItemAttribute(ConfigurationItemAttributeType.required);

/// A [ConfigurationItemAttribute] for optional properties.
const ConfigurationItemAttribute optionalConfiguration =
    ConfigurationItemAttribute(ConfigurationItemAttributeType.optional);

/// Thrown when reading data into a [Configuration] fails.
class ConfigurationException {
  ConfigurationException(this.configuration, this.message,
      {this.keyPath = const []});

  /// The [Configuration] in which this exception occurred.
  final Configuration configuration;

  /// The reason for the exception.
  final String message;

  /// The key of the object being evaluated.
  ///
  /// Either a string (adds '.name') or an int (adds '\[value\]').
  final List<dynamic> keyPath;

  @override
  String toString() {
    if (keyPath?.isEmpty ?? true) {
      return "Failed to read '${configuration.runtimeType}'\n\t-> $message";
    }

    final joinedKeyPath = StringBuffer();
    for (var i = 0; i < keyPath.length; i ++) {
      final thisKey = keyPath[i];

      if (thisKey is String) {
        if (i != 0) {
          joinedKeyPath.write(".");
        }
        joinedKeyPath.write(thisKey);
      } else if (thisKey is int) {
        joinedKeyPath.write("[$thisKey]");
      } else {
        throw StateError("not an int or String");
      }
    }

    return "Failed to read key '${joinedKeyPath}' for '${configuration.runtimeType}'\n\t-> $message";
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
    return "Invalid configuration type '$type'. $message";
  }
}
