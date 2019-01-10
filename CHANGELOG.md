# Changelog

# 2.0.2
- Fixes issue when a database connection Uri has percent encoded values for username/password segments.

# 2.0.1

- Better error messaging for incorrect types
- Allow 'bool' data type, fix regression in 2.0.0
- Allow default values, fix regression in 2.0.0

# 2.0.0

- Dart 2.0 compatability.
- Rename `ConfigurationItem` -> `Configuration`.
- Rename `DatabaseConnectionConfiguration` -> `DatabaseConfiguration`.

# 1.2.2

- Fixes issue where environment variables could not be decoded as ConfigurationItems

# 1.2.1

- Throws exception when parsing if environment variable does not exist and is required.

# 1.2.0

- Allow `ConfigurationItem` to validate their values by overriding `validate` (Thanks to Denis Albuquerque, [@zidenis](https://github.com/zidenis))

# 1.1.3

- Ignore private variables declared in ConfigurationItem subclasses

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


