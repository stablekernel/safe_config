part of safe_config;

/// A [ConfigurationItem] to represent a database connection configuration.
class DatabaseConnectionConfiguration extends ConfigurationItem {

  /// Default constructor.
  DatabaseConnectionConfiguration();

  /// A named constructor that contains all of the properties of this instance.
  DatabaseConnectionConfiguration.withConnectionInfo(this.username, this.password, this.host, this.port, this.databaseName, {bool temporary: false}) {
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
}

/// A [ConfigurationItem] to represent an external HTTP API.
class APIConfiguration extends ConfigurationItem {

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