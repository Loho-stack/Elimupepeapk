/// Strict readers for the models. A missing or wrongly typed required field
/// throws a [FormatException]; the repositories turn that into a `ParseError`.
/// Unknown extra fields are ignored, so the server can add fields safely.
extension JsonRead on Map<String, dynamic> {
  Never _fail(String key, String want) =>
      throw FormatException('"$key" should be $want');

  String str(String key) {
    final v = this[key];
    return v is String ? v : _fail(key, 'a string');
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    return v is String ? v : _fail(key, 'a string or null');
  }

  int integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    return _fail(key, 'an integer');
  }

  int? intOrNull(String key) {
    final v = this[key];
    return v == null ? null : integer(key);
  }

  /// MySQL decimal columns reach the JSON as numeric strings ("18.00"); both forms are numbers.
  double number(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? _fail(key, 'a number');
    return _fail(key, 'a number');
  }

  double? numberOrNull(String key) {
    final v = this[key];
    return v == null ? null : number(key);
  }

  bool boolean(String key) {
    final v = this[key];
    return v is bool ? v : _fail(key, 'a boolean');
  }

  bool? boolOrNull(String key) {
    final v = this[key];
    return v == null ? null : boolean(key);
  }

  DateTime? timeOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is! String) return _fail(key, 'a date string or null');
    return DateTime.tryParse(v) ?? _fail(key, 'an ISO 8601 date');
  }

  DateTime time(String key) => timeOrNull(key) ?? _fail(key, 'an ISO 8601 date');

  Map<String, dynamic> obj(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : _fail(key, 'an object');
  }

  Map<String, dynamic>? objOrNull(String key) {
    final v = this[key];
    return v == null ? null : obj(key);
  }

  List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
    final v = this[key];
    if (v is! List) return _fail(key, 'a list');
    return [
      for (final item in v)
        item is Map ? parse(Map<String, dynamic>.from(item)) : _fail(key, 'a list of objects'),
    ];
  }
}
