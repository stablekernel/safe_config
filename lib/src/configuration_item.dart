part of safe_config;

/// Subclasses of [ConfigurationItem] read YAML strings and files, assigning values from the YAML to properties
/// of the subclass.
abstract class ConfigurationItem {

  /// Default constructor.
  ConfigurationItem() {
    
  }

  ConfigurationItem.fromMap(Map map) {
    readFromMap(map);
  }

  /// Loads a YAML-compliant string into this instance's properties.
  ConfigurationItem.fromString(String contents) {
    var config = loadYaml(contents);
    readFromMap(config);
  }

  /// Opens a file and reads its string contents into this instance's properties.
  ///
  /// If [name] is a relative path, it will be interpreted relative to the current working directory.
  /// If [name] is an absolute path, it will ignore the current working directory.
  ConfigurationItem.fromFile(String name) : this.fromString(new File(name).readAsStringSync());

  List<String> get _missingRequiredValues {
    var reflectedThis = reflect(this);
    return reflectedThis.type.declarations.values
        .where((dm) {
          if (dm is! VariableMirror) {
            return false;
          }

          ConfigurationItemAttribute metadata = dm.metadata.firstWhere((im) => im.reflectee is ConfigurationItemAttribute,
              orElse: () => reflect(requiredConfiguration)).reflectee;
          return metadata.type == ConfigurationItemAttributeType.required;
        })
        .map((dm) => dm as VariableMirror)
        .where((VariableMirror vm) => reflectedThis.getField(vm.simpleName).reflectee == null)
        .map((VariableMirror vm) => MirrorSystem.getName(vm.simpleName))
        .toList();
  }

  void set _subItem(dynamic item) {
    if (item is! Map) {
      decode(item);

      var missing = _missingRequiredValues;
      if (missing.length > 0) {
        throw new ConfigurationException("Missing items for ${this.runtimeType}: $missing.");
      }
    } else {
      readFromMap(item);
    }
  }

  void readFromMap(Map<String, dynamic> items) {
    var reflectedThis = reflect(this);

    reflectedThis.type.declarations.forEach((sym, decl) {
      if (decl is! VariableMirror) {
        return;
      }

      VariableMirror variableMirror = decl;
      var value = items[MirrorSystem.getName(sym)];

      if (value != null) {
        _readConfigurationItem(sym, variableMirror, value);
      } else if (_isVariableRequired(sym, variableMirror)) {
        throw new ConfigurationException("${MirrorSystem.getName(sym)} is required but was not found in configuration.");
      }
    });
  }

  /// Subclasses may override this method to read from something that is not a Map.
  ///
  /// Sometimes a configuration value can be represented in multiple ways. For example, a DatabaseConnectionConfiguration
  /// can be a [Map] of each component or a single URI [String] that can be decomposed into each component. Subclasses may override
  /// this method to provide this type of behavior. This method is executed when an instance of [ConfigurationItem] is ready to be parsed,
  /// but the value from the YAML is *not* a [Map]. By default, this method throws an exception.
  void decode(dynamic anything) {
    throw new ConfigurationException("${this.runtimeType} attempted to decode value $anything, but did not override decode.");
  }

  bool _isVariableRequired(Symbol symbol, VariableMirror m) {
    ConfigurationItemAttribute attribute = m.metadata
        .firstWhere((im) => im.type.isSubtypeOf(reflectType(ConfigurationItemAttribute)), orElse: () => null)
        ?.reflectee;

    return attribute == null || attribute.type == ConfigurationItemAttributeType.required;
  }

  void _readConfigurationItem(Symbol symbol, VariableMirror mirror, dynamic value) {
    var reflectedThis = reflect(this);

    if (value is String && value.startsWith("\$")) {
      value = Platform.environment[value.substring(1)];

      if (value == null) {
        return;
      }

      if (mirror.type.isSubtypeOf(reflectType(int))) {
        value = int.parse(value);
      } else if (mirror.type.isSubtypeOf(reflectType(bool))) {
        value = value == "true";
      }
    }

    var decodedValue = null;
    if (mirror.type.isSubtypeOf(reflectType(ConfigurationItem))) {
      decodedValue = _decodedConfigurationItem(mirror.type, value);
    } else if (mirror.type.isSubtypeOf(reflectType(List))) {
      decodedValue = _decodedConfigurationList(mirror.type, value);
    } else if (mirror.type.isSubtypeOf(reflectType(Map))) {
      decodedValue = _decodedConfigurationMap(mirror.type, value);
    } else {
      decodedValue = value;
    }

    reflectedThis.setField(symbol, decodedValue);
  }

  dynamic _decodedConfigurationItem(TypeMirror typeMirror, dynamic value) {
    ConfigurationItem newInstance = (typeMirror as ClassMirror).newInstance(new Symbol(""), []).reflectee;
    newInstance._subItem = value;
    return newInstance;
  }

  List<dynamic> _decodedConfigurationList(TypeMirror typeMirror, YamlList value) {
    var decoder = (v) {
      return v;
    };

    if (typeMirror.typeArguments.first.isSubtypeOf(reflectType(ConfigurationItem))) {
      var innerClassMirror = typeMirror.typeArguments.first as ClassMirror;
      decoder = (v) {
        ConfigurationItem newInstance = (innerClassMirror as ClassMirror).newInstance(new Symbol(""), []).reflectee;
        newInstance._subItem = v;
        return newInstance;
      };
    }

    return value.map(decoder).toList();
  }

  Map<String, dynamic> _decodedConfigurationMap(TypeMirror typeMirror, YamlMap value) {
    var decoder = (v) {
      return v;
    };

    if (typeMirror.typeArguments.last.isSubtypeOf(reflectType(ConfigurationItem))) {
      var innerClassMirror = typeMirror.typeArguments.last as ClassMirror;
      decoder = (v) {
        ConfigurationItem newInstance = (innerClassMirror as ClassMirror).newInstance(new Symbol(""), []).reflectee;
        newInstance._subItem = v;
        return newInstance;
      };
    }

    var map = {};
    value.keys.forEach((k) {
      map[k] = decoder(value[k]);
    });
    return map;
  }

  dynamic noSuchMethod(Invocation i) {
    return null;
  }
}

/// Possible options for a configuration item property's optionality.
enum ConfigurationItemAttributeType {
  /// [ConfigurationItem] properties marked as [required] will throw an exception if their source YAML doesn't contain a matching key.
  required,

  /// [ConfigurationItem] properties marked as [optional] will be silently ignored if their source YAML doesn't contain a matching key.
  optional
}

/// [ConfigurationItem] properties may be attributed with these.
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

/// Thrown when [ConfigurationItem]s encounter an error.
class ConfigurationException {
  ConfigurationException(this.message);

  /// The reason for the exception.
  String message;

  String toString() {
    return "ConfigurationException: $message";
  }
}
