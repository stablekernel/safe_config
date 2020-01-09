import 'dart:mirrors';

import 'package:safe_config/src/configuration.dart';
import 'package:safe_config/src/intermediate_exception.dart';

class MirrorConfigurationProperty {
  MirrorConfigurationProperty(this.property);

  final VariableMirror property;

  String get key => MirrorSystem.getName(property.simpleName);
  bool get isRequired => _isVariableRequired(property);

  static bool _isVariableRequired(VariableMirror m) {
    final attribute = m.metadata
        .firstWhere(
            (im) =>
                im.type.isSubtypeOf(reflectType(ConfigurationItemAttribute)),
            orElse: () => null)
        ?.reflectee as ConfigurationItemAttribute;

    return attribute == null ||
        attribute.type == ConfigurationItemAttributeType.required;
  }

  dynamic decode(dynamic input) {
    final type = property.type;
    return _decodeValue(type, Configuration.getEnvironmentOrValue(input));
  }

  dynamic _decodeValue(TypeMirror type, dynamic value) {
    if (type.isSubtypeOf(reflectType(int))) {
      return _decodeInt(value);
    } else if (type.isSubtypeOf(reflectType(bool))) {
      return _decodeBool(value);
    } else if (type.isSubtypeOf(reflectType(Configuration))) {
      return _decodeConfig(type, value);
    } else if (type.isSubtypeOf(reflectType(List))) {
      return _decodeList(type, value as List);
    } else if (type.isSubtypeOf(reflectType(Map))) {
      return _decodeMap(type, value as Map);
    }

    return value;
  }

  bool _decodeBool(dynamic value) {
    if (value is String) {
      return value == "true";
    }

    return value as bool;
  }

  int _decodeInt(dynamic value) {
    if (value is String) {
      return int.parse(value);
    }

    return value as int;
  }

  Configuration _decodeConfig(TypeMirror type, dynamic object) {
    final item = (type as ClassMirror)
        .newInstance(const Symbol(""), []).reflectee as Configuration;

    item.decode(object);

    return item;
  }

  List<dynamic> _decodeList(TypeMirror typeMirror, List value) {
    final out = (typeMirror as ClassMirror).newInstance(const Symbol(''), []).reflectee as List;
    for (var i = 0; i < value.length; i++) {
      try {
        final v = _decodeValue(typeMirror.typeArguments.first, value[i]);
        out.add(v);
      } on IntermediateException catch (e) {
        e.keyPath.add(i);
        rethrow;
      } catch (e) {
        throw IntermediateException(e, [i]);
      }
    }
    return out;
  }

  Map<dynamic, dynamic> _decodeMap(TypeMirror typeMirror, Map value) {
    final map = (typeMirror as ClassMirror)
      .newInstance(const Symbol(""), []).reflectee as Map;

    value.forEach((key, val) {
      if (key is! String) {
        throw StateError('cannot have non-String key');
      }

      try {
        map[key] = _decodeValue(typeMirror.typeArguments.last, val);
      } on IntermediateException catch (e) {
        e.keyPath.add(key);
        rethrow;
      } catch (e) {
        throw IntermediateException(e, [key]);
      }
    });

    return map;
  }

  String get expectedType {
    return property.type.reflectedType.toString();
  }

  String get source {
    if (property.type.isSubtypeOf(reflectType(int))) {
      return _decodeIntSource;
    } else if (property.type.isSubtypeOf(reflectType(bool))) {
      return _decodeBoolSource;
    } else if (property.type.isSubtypeOf(reflectType(Configuration))) {
      return _decodeConfigSource;
    } /*else if (property.type.isSubtypeOf(reflectType(List))) {
      return _decodeList(type, value as List);
    } else if (property.type.isSubtypeOf(reflectType(Map))) {
      return _decodeMap(type, value as Map);

      // package:runtime should have something that can 'decompose' a nested List/Map
      // e.g. if Map<String, List<Foo>>... should be able to generate a func
      // that takes dynamic map and hard casts each element to the necessary
      // type to fit into a strictly typed variable
    } */else {
      return "return v;";
    }

    return "";
  }

  String get _decodeConfigSource {
    return """
    final item = ${expectedType}();

    item.decode(v);

    return item;
    """;

  }

  String get _decodeIntSource {
    return """
    if (v is String) {
      return int.parse(v);
    }

    return v as int;     
""";
  }

  String get _decodeBoolSource {
    return """
    if (v is String) {
      return v == "true";
    }

    return v as bool;    
    """;
  }

}
