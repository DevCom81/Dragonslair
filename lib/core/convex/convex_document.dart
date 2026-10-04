import '../errors/app_exception.dart';

Map<String, dynamic> convexObject(Object? value, {required String label}) {
  if (value == null) {
    throw GameException('$label is missing.');
  }
  if (value is! Map) {
    throw GameException('$label is not an object.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, dynamic>? convexObjectOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw const GameException('Expected an object or null.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> convexObjectList(
  Object? value, {
  required String label,
}) {
  if (value is! List) {
    throw GameException('$label is not a list.');
  }
  return [
    for (final item in value) convexObject(item, label: label),
  ];
}

String convexId(Map<String, dynamic> json) {
  final id = json['_id'] ?? json['id'];
  if (id == null) {
    throw const GameException('Convex document is missing _id.');
  }
  final text = id.toString().trim();
  if (text.isEmpty) {
    throw const GameException('Convex document is missing _id.');
  }
  return text;
}

String? convexOptionalId(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime convexDateTime(Object? value, {required String label}) {
  final parsed = convexOptionalDateTime(value);
  if (parsed == null) {
    throw GameException('$label is missing.');
  }
  return parsed;
}

DateTime? convexOptionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int convexInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double convexDouble(Object? value, {required String label}) {
  if (value is! num) {
    throw GameException('$label must be a number.');
  }
  return value.toDouble();
}

String convexString(Object? value, {required String label}) {
  if (value is! String || value.trim().isEmpty) {
    throw GameException('$label is required.');
  }
  return value;
}

String? convexOptionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> convexStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList();
}

Map<String, dynamic> convexNestedMap(Object? value) {
  if (value is! Map) {
    return {};
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}
