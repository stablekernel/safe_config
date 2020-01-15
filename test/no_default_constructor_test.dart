import 'package:runtime/runtime.dart';
import 'package:safe_config/safe_config.dart';
import 'package:test/test.dart';

void main() {
  test("Configuration without unnamed constructor is an error at compile time", () {
    try {
      RuntimeContext.current;
      fail('unreachable');
    } on StateError catch (e) {
      expect(e.toString(), contains("Failed to compile 'BadConfig'"));
    }
  });
}

class BadConfig extends Configuration {
  BadConfig.from(this.id);
  String id;
}