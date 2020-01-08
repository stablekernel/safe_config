import 'dart:io';

import 'package:runtime/runtime.dart';
import 'package:safe_config/safe_config.dart';
import 'package:test/test.dart';

void main() {
  test("Foo", () async {
    // Current issue is that if there are any declarations in the script file,
    // they are not included when generating runtimes; the declarations are not found in MirrorContext.
    // Need to find a way to get those into the current mirror context.
    // This can be complicated because the original script will contain a main function... that we are supposed
    // to run.
    // so we need to grab all of the class declarations from the source file
    // and move them into a separate file, including all the imports of the original
    // that have been 'normalized' according to the context.
    // The best place to do this is BuildExecutable.packageImportString... we should
    // instead be stripping any main function from a copy of this file and importing it instead.
    final ctx = BuildContext(
        Directory.current.uri.resolve("lib/").resolve("safe_config.dart"),
        Directory.current.uri.resolve("_build/"),
        Directory.current.uri.resolve("out"),
        File.fromUri(Directory.current.uri
                .resolve("test/")
                .resolve("config_test.dart"))
            .readAsStringSync(),
        includeDevDependencies: true);
    final bm = BuildManager(ctx);
    final gen = await bm.build();
  });

  test("Root", () {
    final message = getMessage({
      "id": 1,
    });
    expect(message, contains("Failed to read key 'id' for 'Parent'"));
  });

  test("Root.Array", () {
    var msg = getMessage({"id": "1", "peers": 1});
    expect(msg, contains("Failed to read key 'peers' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "peers": [0]
    });
    expect(msg, contains("Failed to read key 'peers[0]' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "peers": [
        {"id": 0}
      ]
    });
    expect(msg, contains("Failed to read key 'peers[0].id' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "peers": [
        {"id": "2"},
        {"id": 0}
      ]
    });
    expect(msg, contains("Failed to read key 'peers[1].id' for 'Parent'"));
  });

  test("Root.Array.Array", () {
    var msg = getMessage({
      "id": "1",
      "peers": [
        {
          "id": "2",
          "peers": [0]
        }
      ]
    });
    expect(
        msg, contains("Failed to read key 'peers[0].peers[0]' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "peers": [
        {
          "id": "2",
          "peers": [
            {"id": "1"},
            {}
          ]
        }
      ]
    });
    expect(
        msg, contains("Failed to read key 'peers[0].peers[1]' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "peers": [
        {
          "id": "2",
          "peers": [
            {"id": "1"},
            {"id": 0}
          ]
        }
      ]
    });
    expect(msg,
        contains("Failed to read key 'peers[0].peers[1].id' for 'Parent'"));
  });

  test("Root.Map", () {
    var msg = getMessage({
      "id": "1",
      "namedChildren": {1: "key"}
    });
    expect(msg, contains("Failed to read key 'namedChildren' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "namedChildren": {"key": 0}
    });
    expect(
        msg, contains("Failed to read key 'namedChildren.key' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "namedChildren": {
        "2": {"id": "2"},
        "3": {}
      }
    });
    expect(msg, contains("Failed to read key 'namedChildren.3' for 'Parent'"));
  });

  test("Root.Map.Array", () {
    var msg = getMessage({
      "id": "1",
      "namedChildren": {
        "key": {"id": "2", "peers": 0}
      }
    });
    expect(msg,
        contains("Failed to read key 'namedChildren.key.peers' for 'Parent'"));

    msg = getMessage({
      "id": "1",
      "namedChildren": {
        "key": {
          "id": "2",
          "peers": [
            {"id": 0}
          ]
        }
      }
    });
    expect(
        msg,
        contains(
            "Failed to read key 'namedChildren.key.peers[0].id' for 'Parent'"));
  });

  test("Root.Map.Array.Config.Array", () {
    var msg = getMessage({
      "id": "1",
      "namedChildren": {
        "k1": {
          "id": "2",
          "parent": {
            "id": "3",
            "peers": [
              {"id": 0}
            ]
          }
        }
      }
    });
    expect(
        msg,
        contains(
            "Failed to read key 'namedChildren.k1.parent.peers[0].id' for 'Parent'"));
  });

  test("Root.List.List", () {
    var msg = getMessage({
      "id": "1",
      "listOfListOfParents": [
        [
          {"id": "1"}
        ],
        [
          {"id", 0}
        ]
      ]
    });

    expect(
        msg,
        contains(
            "Failed to read key 'listOfListOfParents[0][1]' for 'Parent'"));
  });
}

class Parent extends Configuration {
  Parent();

  Parent.fromMap(Map m) : super.fromMap(m);

  String id;

  @optionalConfiguration
  List<List<Parent>> listOfListOfParents;

  @optionalConfiguration
  List<Parent> peers;

  @optionalConfiguration
  Map<String, Child> namedChildren;
}

class Child extends Configuration {
  String id;

  @optionalConfiguration
  Parent parent;

  @optionalConfiguration
  List<Child> peers;
}

String getMessage(Map object) {
  try {
    Parent.fromMap(object);
  } on ConfigurationException catch (e) {
    final msg = e.toString();
    print(msg);
    return msg;
  }

  fail('did not throw');
}
