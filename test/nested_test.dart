import 'package:safe_config/safe_config.dart';
import 'package:test/test.dart';

void main() {
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

  String? id;

  @optionalConfiguration
  List<List<Parent>>? listOfListOfParents;

  @optionalConfiguration
  List<Parent>? peers;

  @optionalConfiguration
  Map<String, Child>? namedChildren;
}

class Child extends Configuration {
  String? id;

  @optionalConfiguration
  Parent? parent;

  @optionalConfiguration
  List<Child>? peers;
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
