import 'dart:mirrors';

import 'package:runtime/runtime.dart';
import 'package:safe_config/src/configuration.dart';

import 'mirror_property.dart';

class ConfigurationRuntimeImpl extends ConfigurationRuntime
    implements SourceCompiler {
  ConfigurationRuntimeImpl(this.type) {
      final classHasDefaultConstructor = type.declarations.values.any((dm) {
        return dm is MethodMirror &&
          dm.isConstructor &&
          dm.constructorName == const Symbol('') &&
          dm.parameters.every((p) => p.isOptional == true);
      });

      if (!classHasDefaultConstructor) {
        throw StateError("Failed to compile '${type.reflectedType}'\n\t-> all 'Configuration' subclasses MUST declare an unnammed constructor (i.e. '${type.reflectedType}();')");
      }

    properties = _properties;
  }

  final ClassMirror type;

  @override
  Map<String, ConfigurationProperty> properties;

  @override
  void validate(Configuration configuration) {
    final configMirror = reflect(configuration);
    final requiredValuesThatAreMissing = properties.values
        .where((v) => v.isRequired)
        .where((v) => configMirror.getField(Symbol(v.key)).reflectee == null)
        .map((v) => v.key)
        .toList();

    if (requiredValuesThatAreMissing.isNotEmpty) {
      throw ConfigurationException(configuration,
          "missing required key(s): ${requiredValuesThatAreMissing.map((s) => "'$s'").join(", ")}");
    }
  }

  Map<String, ConfigurationProperty> get _properties {
    var declarations = <VariableMirror>[];

    var ptr = type;
    while (ptr.isSubclassOf(reflectClass(Configuration))) {
      declarations.addAll(ptr.declarations.values
          .whereType<VariableMirror>()
          .where((vm) => !vm.isStatic && !vm.isPrivate));
      ptr = ptr.superclass;
    }

    final m = <String, ConfigurationProperty>{};
    declarations.forEach((vm) {
      final name = MirrorSystem.getName(vm.simpleName);
      m[name] = MirrorConfigurationProperty(vm);
    });
    return m;
  }

  String get directives {
    return "";
  }

  String get transferImpl {
    return "";
  }

  @override
  String get source {
    // for each type, we have to make sure we import the same packages
    // (what about relative packages?). do we have to 'absolute' all import paths
    // to do this?

    // OK so we have to import all supported types and Configuration subclasses.
    // we can look at their source location. Gotta look at List and Map types
    return """
$directives
    
final instance = ConfigurationRuntimeImpl();    
class ConfigurationRuntimeImpl extends ConfigurationRuntime {
  void transfer(dynamic input, Configuration configuration) {
    $transferImpl
  }
}    
    """;
  }
}
