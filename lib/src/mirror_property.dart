import 'dart:mirrors';

import 'package:safe_config/src/configuration.dart';
import 'package:safe_config/src/intermediate_exception.dart';

class MirrorConfigurationProperty extends ConfigurationProperty {
  MirrorConfigurationProperty(this.property)
      : super(MirrorSystem.getName(property.simpleName),
            isRequired: _isVariableRequired(property));

  VariableMirror property;

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

  @override
  void apply(Configuration instance, dynamic input) {
    if (input == null) {
      return null;
    }

    final type = property.type;
    final mirror = reflect(instance);
    final value = _decodeValue(type, ConfigurationProperty.actualize(input));
    mirror.setField(property.simpleName, value);
  }

  dynamic _decodeValue(TypeMirror type, dynamic value) {
    if (type.isSubtypeOf(reflectType(int))) {
      return decodeInt(value);
    } else if (type.isSubtypeOf(reflectType(bool))) {
      return decodeBool(value);
    } else if (type.isSubtypeOf(reflectType(Configuration))) {
      return _decodeConfig(type, value);
    } else if (type.isSubtypeOf(reflectType(List))) {
      return _decodeList(type, value as List);
    } else if (type.isSubtypeOf(reflectType(Map))) {
      return _decodeMap(type, value as Map);
    }

    return value;
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
}
