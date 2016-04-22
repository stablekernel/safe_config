/// A utility for adding type and name safety to YAML configuration files.
library safe_config;

import 'package:yaml/yaml.dart';
import 'dart:io';
import 'dart:mirrors';

part 'src/configuration_item.dart';
part 'src/default_configuration_items.dart';


