import 'package:test/test.dart';
import 'package:safe_config/safe_config.dart';
import 'dart:io';

void main() {
  test("Success case", () {
    var yamlString =
        "port: 80\n"
        "name: foobar\n"
        "database:\n"
        "  host: stablekernel.com\n"
        "  username: bob\n"
        "  password: fred\n"
        "  databaseName: dbname\n"
        "  port: 5000";

    var t = new TopLevelConfiguration(yamlString);
    expect(t.port, 80);
    expect(t.name, "foobar");
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);

    var asMap = {
      "port" : 80,
      "name" : "foobar",
      "database" : {
        "host" : "stablekernel.com",
        "username" : "bob",
        "password" : "fred",
        "databaseName" : "dbname",
        "port" : 5000
      }
    };
    t = new TopLevelConfiguration.fromMap(asMap);
    expect(t.port, 80);
    expect(t.name, "foobar");
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);
  });

  test("Configuration subclasses success case", () {
    var yamlString =
        "port: 80\n"
        "extraValue: 2\n"
        "database:\n"
        "  host: stablekernel.com\n"
        "  username: bob\n"
        "  password: fred\n"
        "  databaseName: dbname\n"
        "  port: 5000\n"
        "  extraDatabaseValue: 3";

    var t = new ConfigurationSubclass(yamlString);
    expect(t.port, 80);
    expect(t.extraValue, 2);
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);
    expect(t.database.extraDatabaseValue, 3);

    var asMap = {
      "port" : 80,
      "extraValue" : 2,
      "database" : {
        "host" : "stablekernel.com",
        "username" : "bob",
        "password" : "fred",
        "databaseName" : "dbname",
        "port" : 5000,
        "extraDatabaseValue" : 3
      }
    };
    t = new ConfigurationSubclass.fromMap(asMap);
    expect(t.port, 80);
    expect(t.extraValue, 2);
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);
    expect(t.database.extraDatabaseValue, 3);
  });

  test("Extra property", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n"
          "extraKey: 2\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000";

      var _ = new TopLevelConfiguration(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "TopLevelConfiguration contained unexpected keys: extraKey");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar",
        "extraKey" : 2,
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000
        }
      };
      var _ = new TopLevelConfiguration.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "TopLevelConfiguration contained unexpected keys: extraKey");
    }
  });

  test("Missing required top-level explicit", () {
    try {
      var yamlString =
          "name: foobar\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000";

      var _ = new TopLevelConfiguration(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "name" : "foobar",
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000
        }
      };
      var _ = new TopLevelConfiguration.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }
  });

  test("Missing required top-level implicit", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n";
      var _ = new TopLevelConfiguration(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "database is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar"
      };
      var _ = new TopLevelConfiguration.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "database is required but was not found in configuration.");
    }
  });

  test("Invalid value for top-level property", () {
    try {
      var yamlString =
          "name: foobar\n"
          "port: 65536\n";

      var _ = new TopLevelConfigurationWithValidation(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "TopLevelConfigurationWithValidation invalid property: [port: 65536]");
    }

    try {
      var asMap = {
        "name" : "foobar",
        "port" : 65536
      };
      var _ = new TopLevelConfigurationWithValidation.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "TopLevelConfigurationWithValidation invalid property: [port: 65536]");
    }
  });

  test("Missing required top-level from superclass", () {
    try {
      var yamlString =
          "name: foobar\n"
          "extraValue: 2\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000\n"
          "  extraDatabaseValue: 3";

      var _ = new ConfigurationSubclass(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "name" : "foobar",
        "extraValue" : 2,
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000,
          "extraDatabaseValue" : 3
        }
      };
      var _ = new ConfigurationSubclass.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }
  });

  test("Missing required top-level from subclass", () {
    try {
      var yamlString =
          "name: foobar\n"
          "port: 80\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000\n"
          "  extraDatabaseValue: 3";

      var _ = new ConfigurationSubclass(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "extraValue is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "name" : "foobar",
        "port" : 80,
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000,
          "extraDatabaseValue" : 3
        }
      };
      var _ = new ConfigurationSubclass.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "extraValue is required but was not found in configuration.");
    }
  });

  test("Missing required nested property from superclass", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n"
          "extraValue: 2\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  extraDatabaseValue: 3";

      var _ = new ConfigurationSubclass(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar",
        "extraValue" : 2,
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "extraDatabaseValue" : 3
        }
      };
      var _ = new ConfigurationSubclass.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "port is required but was not found in configuration.");
    }
  });

  test("Missing required nested property from subclass", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n"
          "extraValue: 2\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000\n";

      var _ = new ConfigurationSubclass(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "extraDatabaseValue is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar",
        "extraValue" : 2,
        "database" : {
          "host" : "stablekernel.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000,
        }
      };
      var _ = new ConfigurationSubclass.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "extraDatabaseValue is required but was not found in configuration.");
    }
  });

  test("Validation of the value of property from subclass", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n"
          "database:\n"
          "  host: not a host.com\n"
          "  username: bob\n"
          "  password: fred\n"
          "  databaseName: dbname\n"
          "  port: 5000\n";

      var _ = new ConfigurationSubclassWithValidation(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "DatabaseConfigurationSubclassWithValidation invalid property: [host: not a host.com]");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar",
        "database" : {
          "host" : "not a host.com",
          "username" : "bob",
          "password" : "fred",
          "databaseName" : "dbname",
          "port" : 5000,
        }
      };
      var _ = new ConfigurationSubclassWithValidation.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "DatabaseConfigurationSubclassWithValidation invalid property: [host: not a host.com]");
    }
  });

  test("Optional can be missing", () {
    var yamlString =
        "port: 80\n"
        "database:\n"
        "  host: stablekernel.com\n"
        "  username: bob\n"
        "  password: fred\n"
        "  databaseName: dbname\n"
        "  port: 5000";

    var t = new TopLevelConfiguration(yamlString);
    expect(t.port, 80);
    expect(t.name, isNull);
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);

    var asMap = {
      "port" : 80,
      "database" : {
        "host" : "stablekernel.com",
        "username" : "bob",
        "password" : "fred",
        "databaseName" : "dbname",
        "port" : 5000
      }
    };
    t = new TopLevelConfiguration.fromMap(asMap);
    expect(t.port, 80);
    expect(t.name, isNull);
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);
  });

  test("Nested optional can be missing", () {
    var yamlString =
        "port: 80\n"
        "name: foobar\n"
        "database:\n"
        "  host: stablekernel.com\n"
        "  password: fred\n"
        "  databaseName: dbname\n"
        "  port: 5000";

    var t = new TopLevelConfiguration(yamlString);
    expect(t.port, 80);
    expect(t.name, "foobar");
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, isNull);
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);

    var asMap = {
      "port" : 80,
      "name" : "foobar",
      "database" : {
        "host" : "stablekernel.com",
        "password" : "fred",
        "databaseName" : "dbname",
        "port" : 5000
      }
    };
    t = new TopLevelConfiguration.fromMap(asMap);
    expect(t.port, 80);
    expect(t.name, "foobar");
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, isNull);
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);
  });

  test("Nested required cannot be missing", () {
    try {
      var yamlString =
          "port: 80\n"
          "name: foobar\n"
          "database:\n"
          "  host: stablekernel.com\n"
          "  password: fred\n"
          "  port: 5000";

      var _ = new TopLevelConfiguration(yamlString);
    } on ConfigurationException catch (e) {
      expect(e.message, "databaseName is required but was not found in configuration.");
    }

    try {
      var asMap = {
        "port" : 80,
        "name" : "foobar",
        "database" : {
          "host" : "stablekernel.com",
          "password" : "fred",
          "port" : 5000
        }
      };
      var _ = new TopLevelConfiguration.fromMap(asMap);
    } on ConfigurationException catch (e) {
      expect(e.message, "databaseName is required but was not found in configuration.");
    }
  });

  test("Map and list cases", () {
    var yamlString =
        "strings:\n"
        "-  abcd\n"
        "-  efgh\n"
        "databaseRecords:\n"
        "- databaseName: db1\n"
        "  port: 1000\n"
        "  host: stablekernel.com\n"
        "- username: bob\n"
        "  databaseName: db2\n"
        "  port: 2000\n"
        "  host: stablekernel.com\n"
        "integers:\n"
        "  first: 1\n"
        "  second: 2\n"
        "databaseMap:\n"
        "  db1:\n"
        "    host: stablekernel.com\n"
        "    databaseName: db1\n"
        "    port: 1000\n"
        "  db2:\n"
        "    username: bob\n"
        "    databaseName: db2\n"
        "    port: 2000\n"
        "    host: stablekernel.com\n";

    var special = new SpecialInfo(yamlString);
    expect(special.strings, ["abcd", "efgh"]);
    expect(special.databaseRecords.first.host, "stablekernel.com");
    expect(special.databaseRecords.first.databaseName, "db1");
    expect(special.databaseRecords.first.port, 1000);

    expect(special.databaseRecords.last.username, "bob");
    expect(special.databaseRecords.last.databaseName, "db2");
    expect(special.databaseRecords.last.port, 2000);
    expect(special.databaseRecords.last.host, "stablekernel.com");

    expect(special.integers["first"], 1);
    expect(special.integers["second"], 2);
    expect(special.databaseMap["db1"].databaseName, "db1");
    expect(special.databaseMap["db1"].host, "stablekernel.com");
    expect(special.databaseMap["db1"].port, 1000);
    expect(special.databaseMap["db2"].username, "bob");
    expect(special.databaseMap["db2"].databaseName, "db2");
    expect(special.databaseMap["db2"].port, 2000);
    expect(special.databaseMap["db2"].host, "stablekernel.com");
  });

  test("From file works the same", () {
    var yamlString =
        "port: 80\n"
        "name: foobar\n"
        "database:\n"
        "  host: stablekernel.com\n"
        "  username: bob\n"
        "  password: fred\n"
        "  databaseName: dbname\n"
        "  port: 5000";

    var file = new File("tmp.yaml");
    file.writeAsStringSync(yamlString);

    var t = new TopLevelConfiguration.fromFile("tmp.yaml");
    expect(t.port, 80);
    expect(t.name, "foobar");
    expect(t.database.host, "stablekernel.com");
    expect(t.database.username, "bob");
    expect(t.database.password, "fred");
    expect(t.database.databaseName, "dbname");
    expect(t.database.port, 5000);

    file.deleteSync();
  });

  test("Optional nested ConfigurationItem can be omitted", () {
    var yamlString = "port: 80";

    var config = new OptionalEmbeddedContainer(yamlString);
    expect(config.port, 80);
    expect(config.database, isNull);

    yamlString =
      "port: 80\n"
      "database:\n"
      "  host: here\n"
      "  port: 90\n"
      "  databaseName: db";

    config = new OptionalEmbeddedContainer(yamlString);
    expect(config.port, 80);
    expect(config.database.host, "here");
    expect(config.database.port, 90);
    expect(config.database.databaseName, "db");
  });

  test("Optional nested ConfigurationItem obeys required items", () {
    // Missing host intentionally
    var yamlString =
    "port: 80\n"
        "database:\n"
        "  port: 90\n"
        "  databaseName: db";

    try {
      var _ = new OptionalEmbeddedContainer(yamlString);
      expect(true, false);
    } on ConfigurationException {}
  });

  test("Database configuration can come from string", () {
    var yamlString =
        "port: 80\n"
        "database: \"postgres://dart:pw@host:5432/dbname\"\n";

    var values = new OptionalEmbeddedContainer(yamlString);
    expect(values.port, 80);
    expect(values.database.username, "dart");
    expect(values.database.password, "pw");
    expect(values.database.port, 5432);
    expect(values.database.databaseName, "dbname");
  });

  test("Omitting optional values in a 'decoded' config still returns succees", () {
    var yamlString =
        "port: 80\n"
        "database: \"postgres://host:5432/dbname\"\n";

    var values = new OptionalEmbeddedContainer(yamlString);
    expect(values.port, 80);
    expect(values.database.username, isNull);
    expect(values.database.password, isNull);
    expect(values.database.port, 5432);
    expect(values.database.databaseName, "dbname");
  });

  test("Not including required values in a 'decoded' config still yields error", () {
    var yamlString =
        "port: 80\n"
        "database: \"postgres://dart:pw@host:5432\"\n";

    try {
      var _ = new OptionalEmbeddedContainer(yamlString);
      expect(true, false);
    } on ConfigurationException catch (e) {
      expect(e.message, contains("DatabaseConnectionConfiguration"));
      expect(e.message, contains("databaseName"));
    }
  });

  test("Environment variable escape values read from Environment", () {
    print("This test must be run with environment variables of TEST_VALUE=1 and TEST_BOOL=true");

    var yamlString = "path: \$PATH\noptionalDooDad: \$XYZ123\ntestValue: \$TEST_VALUE\ntestBoolean: \$TEST_BOOL";
    var values = new EnvironmentConfiguration(yamlString);
    expect(values.path, Platform.environment["PATH"]);
    expect(values.testValue, int.parse(Platform.environment["TEST_VALUE"]));
    expect(values.testBoolean, true);
    expect(values.optionalDooDad, isNull);
  });

  test("Static variables get ignored", () {
    var yamlString = "value: 1";
    var values = new StaticVariableConfiguration(yamlString);
    expect(values.value, 1);
  });

  test("Private variables get ignored", () {
    var yamlString = "value: 1";
    var values = new PrivateVariableConfiguration(yamlString);
    expect(values.value, 1);
    expect(values._privateVariable, null);
  });
}

class TopLevelConfiguration extends ConfigurationItem {
  TopLevelConfiguration(String contents) : super.fromString(contents);
  TopLevelConfiguration.fromFile(String fileName) : super.fromFile(fileName);
  TopLevelConfiguration.fromMap(Map map) : super.fromMap(map);

  @requiredConfiguration
  int port;

  @optionalConfiguration
  String name;

  DatabaseConnectionConfiguration database;
}

class TopLevelConfigurationWithValidation extends ConfigurationItem {
  TopLevelConfigurationWithValidation(String contents) : super.fromString(contents);
  TopLevelConfigurationWithValidation.fromFile(String fileName) : super.fromFile(fileName);
  TopLevelConfigurationWithValidation.fromMap(Map map) : super.fromMap(map);

  @requiredConfiguration
  int port;

  List<String> validate() {
    if(port < 0 || port > 65535) {
      return ["port: $port"];
    }
  }

  @optionalConfiguration
  String name;
}

class DatabaseConfigurationSubclass extends DatabaseConnectionConfiguration {
  DatabaseConfigurationSubclass();

  int extraDatabaseValue;
}

class ConfigurationSuperclass extends ConfigurationItem {
  ConfigurationSuperclass(String contents) : super.fromString(contents);
  ConfigurationSuperclass.fromFile(String fileName) : super.fromFile(fileName);
  ConfigurationSuperclass.fromMap(Map map) : super.fromMap(map);

  @requiredConfiguration
  int port;

  @optionalConfiguration
  String name;
}

class ConfigurationSubclass extends ConfigurationSuperclass {
  ConfigurationSubclass(String contents) : super(contents);
  ConfigurationSubclass.fromFile(String fileName) : super.fromFile(fileName);
  ConfigurationSubclass.fromMap(Map map) : super.fromMap(map);

  int extraValue;

  DatabaseConfigurationSubclass database;
}

class ConfigurationSubclassWithValidation extends ConfigurationSuperclass {
  ConfigurationSubclassWithValidation(String contents) : super(contents);
  ConfigurationSubclassWithValidation.fromFile(String fileName) : super.fromFile(fileName);
  ConfigurationSubclassWithValidation.fromMap(Map map) : super.fromMap(map);

  DatabaseConfigurationSubclassWithValidation database;
}

class DatabaseConfigurationSubclassWithValidation extends DatabaseConnectionConfiguration {
  DatabaseConfigurationSubclassWithValidation();

  List<String> validate() {
    RegExp validHost = new RegExp(r"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$");
    if (!validHost.hasMatch(host)) {
      return ["host: $host"];
    }
  }
}

class SpecialInfo extends ConfigurationItem {
  SpecialInfo(String contents) : super.fromString(contents);

  List<String> strings;
  List<DatabaseConnectionConfiguration> databaseRecords;
  Map<String, int> integers;
  Map<String, DatabaseConnectionConfiguration> databaseMap;
}

class OptionalEmbeddedContainer extends ConfigurationItem {
  OptionalEmbeddedContainer(String contents) : super.fromString(contents);

  int port;

  @optionalConfiguration
  DatabaseConnectionConfiguration database;
}

class EnvironmentConfiguration extends ConfigurationItem {
  EnvironmentConfiguration(String contents) : super.fromString(contents);

  String path;
  int testValue;
  bool testBoolean;

  @optionalConfiguration
  String optionalDooDad;
}

class StaticVariableConfiguration extends ConfigurationItem {
  static String staticVariable;

  StaticVariableConfiguration(String contents) : super.fromString(contents);

  int value;
}

class PrivateVariableConfiguration extends ConfigurationItem {
  PrivateVariableConfiguration(String contents) : super.fromString(contents);

  String _privateVariable;
  int value;
}