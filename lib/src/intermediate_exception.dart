class IntermediateException implements Exception {
  IntermediateException(this.underlying, this.keyPath);

  final dynamic underlying;

  final List<dynamic> keyPath;
}