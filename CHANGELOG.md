# Changelog

# 1.1.2

- Ignore static variables declared in ConfigurationItem subclasses

# 1.1.1

- Throw exception if an unexpected key is found when reading configuration.

# 1.1.0

- Enable support for reading environment variables.
- Allow decoders for ConfigurationItem subclasses that may have multiple representations, e.g. a DatabaseConnectionConfiguration from a database connection string.

# 1.0.4

- Fix issue where nested ConfigurationItems marked as optional would fail to parse.

# 1.0.3

- Add ConfigurationItem.fromMap to pass a Map as the source for a ConfigurationItem.

## 1.0.2

- Add library level documentation.

## 1.0.1

- Add documentation generation.
- Update readme.

## 1.0.0

- Initial version.


