import 'dart:mirrors';

import 'package:runtime/runtime.dart';
import 'package:safe_config/src/configuration.dart';

import 'mirror_property.dart';

class ConfigurationRuntimeImpl extends ConfigurationRuntime
    implements SourceCompiler {
  ConfigurationRuntimeImpl(this.type) {
    properties = _properties;
  }

  final ClassMirror type;

  Map<String, MirrorConfigurationProperty> properties;

  @override
  void decode(Configuration configuration, Map input) {
    final values = Map.from(input);
    properties.forEach((name, property) {
      final takingValue = values.remove(name);
      if (takingValue == null) {
        return;
      }

      dynamic decodedValue;
      MirrorConfigurationProperty propertyBackup;
      if (property.property is MethodMirror) { // -- getter
        propertyBackup = property;
        property       = MirrorConfigurationProperty(getSetterForGetter(property.property as MethodMirror));
      }
      decodedValue = tryDecode(configuration, name, () => property.decode(takingValue));

      var valueType = reflect(decodedValue).type;
      if (!valueType.isAssignableTo(property.codec.type)) {
        throw ConfigurationException(configuration, "input is wrong type. Expected: `${property.codec.type.reflectedType}` but Found: ${valueType.reflectedType}", keyPath: [name]);
      }

      if (propertyBackup != null) {
        property = propertyBackup;
      }

      final mirror = reflect(configuration);
      mirror.setField(property.property.simpleName, decodedValue);
    });

    if (values.isNotEmpty) {
      throw ConfigurationException(configuration,
          "unexpected keys found: ${values.keys.map((s) => "'$s'").join(", ")}.");
    }
  }

  String get decodeImpl {
    final buf = StringBuffer();

    buf.writeln("final valuesCopy = Map.from(input);");
    properties.forEach((k, v) {
      buf.writeln("{");
      buf.writeln("final v = Configuration.getEnvironmentOrValue(valuesCopy.remove('$k'));");
      buf.writeln("if (v != null) {");
      buf.writeln(
          "  final decodedValue = tryDecode(configuration, '$k', () { ${v.source} });");
      buf.writeln("  if (decodedValue is! ${v.codec.expectedType}) {");
      buf.writeln(
          "    throw ConfigurationException(configuration, 'input is wrong type', keyPath: ['$k']);");
      buf.writeln("  }");
      buf.writeln(
          "  (configuration as ${type.reflectedType.toString()}).$k = decodedValue as ${v.codec.expectedType};");
      buf.writeln("}");
      buf.writeln("}");
    });

    buf.writeln("""if (valuesCopy.isNotEmpty) {
      throw ConfigurationException(configuration,
          "unexpected keys found: \${valuesCopy.keys.map((s) => "'\$s'").join(", ")}.");
    }
    """);

    return buf.toString();
  }

  @override
  void validate(Configuration configuration) {
    final configMirror = reflect(configuration);
    final requiredValuesThatAreMissing = properties.values
        .where((v) => v.isRequired)
        .where((v) => configMirror.getField(Symbol(v.key)).reflectee == null)
        .map((v) => v.key)
        .toList();

    if (requiredValuesThatAreMissing.isNotEmpty) {
      throw ConfigurationException.missingKeys(
          configuration, requiredValuesThatAreMissing);
    }
  }

  Map<String, MirrorConfigurationProperty> get _properties {
    var declarations = <DeclarationMirror>[];

    var ptr = type;
    while (ptr.isSubclassOf(reflectClass(Configuration))) {
      var properties = ptr.declarations.values.whereType<VariableMirror>();
      var computed   = ptr.declarations.values.whereType<MethodMirror>().where((vm) {
        if (vm.isGetter) {
          return getSetterForGetter(vm) != null;
        } else if (vm.isSetter) {
          return getGetterForSetter(vm) != null;
        } else {
          return false;
        }
      }).toList()..removeWhere((MethodMirror vm) => vm.isSetter);

      declarations.addAll(properties.where((vm) => !vm.isPrivate && !vm.isStatic));
      declarations.addAll(computed  .where((vm) => !vm.isPrivate && !vm.isStatic));

      ptr = ptr.superclass;
    }

    final m = <String, MirrorConfigurationProperty>{};
    declarations.forEach((vm) {
      final name = MirrorSystem.getName(vm.simpleName);
      m[name] = MirrorConfigurationProperty(vm);
    });
    return m;
  }

  String get validateImpl {
    final buf = StringBuffer();

    buf.writeln("final missingKeys = <String>[];");
    properties.forEach((name, property) {
      if (property.isRequired) {
        buf.writeln(
            "if ((configuration as ${type.reflectedType.toString()}).$name == null) {");
        buf.writeln("  missingKeys.add('$name');");
        buf.writeln("}");
      }
    });
    buf.writeln("if (missingKeys.isNotEmpty) {");
    buf.writeln(
        "  throw ConfigurationException.missingKeys(configuration, missingKeys);");
    buf.writeln("}");

    return buf.toString();
  }

  @override
  String compile(BuildContext ctx) {
    final directives = ctx.getImportDirectives(
        uri: type.originalDeclaration.location.sourceUri,
        alsoImportOriginalFile: true)
      ..add("import 'package:safe_config/src/intermediate_exception.dart';");

    return """${directives.join("\n")}    
final instance = ConfigurationRuntimeImpl();    
class ConfigurationRuntimeImpl extends ConfigurationRuntime {
  @override
  void decode(Configuration configuration, Map input) {    
    $decodeImpl        
  }

  @override
  void validate(Configuration configuration) {
    $validateImpl
  }
}    
    """;
  }

  MethodMirror getSetterForGetter(MethodMirror getter) {
    var targetName = MirrorSystem.getName(getter.simpleName) + '=';

    return (getter.owner as ClassMirror).declarations.values
      .whereType<MethodMirror>()
      .firstWhere((maybe) => maybe.isSetter && MirrorSystem.getName(maybe.simpleName) == targetName, orElse: () => null);
  }

  MethodMirror getGetterForSetter(MethodMirror setter) {
    return (setter.owner as ClassMirror).declarations.values
      .whereType<MethodMirror>()
      .firstWhere((maybe) {
        var targetName = MirrorSystem.getName(maybe.simpleName) + '=';

        return maybe.isGetter && MirrorSystem.getName(setter.simpleName) == targetName;
      }
      , orElse: () => null);
  }
}
