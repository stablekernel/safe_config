import 'dart:io';

import 'package:safe_config/src/configuration.dart';

/// A [Configuration] to represent a database connection configuration.
class DatabaseConfiguration extends Configuration {

  /// Default constructor.
  DatabaseConfiguration();

  DatabaseConfiguration.fromFile(File file) : super.fromFile(file);

  DatabaseConfiguration.fromString(String yaml) : super.fromString(yaml);

  DatabaseConfiguration.fromMap(Map<dynamic, dynamic> yaml) : super.fromMap(yaml);

  /// A named constructor that contains all of the properties of this instance.
  DatabaseConfiguration.withConnectionInfo(this.username, this.password, this.host, this.port, this.databaseName, {bool temporary= false}) {
    isTemporary = temporary;
  }

  /// The host of the database to connect to.
  ///
  /// This property is required.
  String host;

  /// The port of the database to connect to.
  ///
  /// This property is required.
  int port;

  /// The name of the database to connect to.
  ///
  /// This property is required.
  String databaseName;

  /// A username for authenticating to the database.
  ///
  /// This property is optional.
  @optionalConfiguration
  String username;

  /// A password for authenticating to the database.
  ///
  /// This property is optional.
  @optionalConfiguration
  String password;

  /// A flag to represent permanence.
  ///
  /// This flag is used for test suites that use a temporary database to run tests against,
  /// dropping it after the tests are complete.
  /// This property is optional.
  @optionalConfiguration
  bool isTemporary;

  @override
  void decode(dynamic anything) {
    if (anything is! String) {
      throw ConfigurationException(runtimeType,
        "Invalid value '$anything'. Must be 'String' or 'Map'.");
    }

    var uri = Uri.parse(anything as String);
    host = uri.host;
    port = uri.port;
    if (uri.pathSegments.length == 1) {
      databaseName = uri.pathSegments.first;
    }

    if (uri.userInfo == null || uri.userInfo == '') {
      return;
    }

    var authority = uri.userInfo.split(":");
    if (authority != null) {
      if (authority.isNotEmpty) {
        username = Uri.decodeComponent(authority.first);
      }
      if (authority.length > 1) {
        password = Uri.decodeComponent(authority.last);
      }
    }
  }
}

/// A [Configuration] to represent an external HTTP API.
class APIConfiguration extends Configuration {
  APIConfiguration();

  APIConfiguration.fromFile(File file) : super.fromFile(file);

  APIConfiguration.fromString(String yaml) : super.fromString(yaml);

  APIConfiguration.fromMap(Map<dynamic, dynamic> yaml) : super.fromMap(yaml);

  /// The base URL of the described API.
  ///
  /// This property is required.
  /// Example: https://external.api.com:80/resources
  String baseURL;

  /// The client ID.
  ///
  /// This property is optional.
  @optionalConfiguration
  String clientID;

  /// The client secret.
  ///
  /// This property is optional.
  @optionalConfiguration
  String clientSecret;
}