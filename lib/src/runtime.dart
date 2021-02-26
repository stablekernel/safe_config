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

  late Map<String, MirrorConfigurationProperty> properties;

  @override
  void decode(Configuration configuration, Map input) {
    final values = Map.from(input);
    properties.forEach((name, property) {
      final takingValue = values.remove(name);
      if (takingValue == null) {
        return;
      }

      var decodedValue =
          tryDecode(configuration, name, () => property.decode(takingValue));

      if (!reflect(decodedValue).type.isAssignableTo(property.property.type)) {
        throw ConfigurationException(configuration, "input is wrong type",
            keyPath: [name]);
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
      buf.writeln(
          "final v = Configuration.getEnvironmentOrValue(valuesCopy.remove('$k'));");
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
    var declarations = <VariableMirror>[];

    var ptr = type;
    while (ptr.isSubclassOf(reflectClass(Configuration))) {
      declarations.addAll(ptr.declarations.values
          .whereType<VariableMirror>()
          .where((vm) => !vm.isStatic && !vm.isPrivate));
      ptr = ptr.superclass!;
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
        uri: type.originalDeclaration.location!.sourceUri,
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
}
