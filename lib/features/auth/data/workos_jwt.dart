import 'dart:convert';

Map<String, Object?>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payload = jsonDecode(decoded);
    if (payload is! Map) {
      return null;
    }
    return payload.map((key, value) => MapEntry(key.toString(), value));
  } catch (_) {
    return null;
  }
}

String? workosSubjectFromAccessToken(String accessToken) {
  final sub = decodeJwtPayload(accessToken)?['sub'];
  if (sub is! String || sub.trim().isEmpty) {
    return null;
  }
  return sub.trim();
}

bool accessTokenStillValid(
  String accessToken, {
  DateTime? now,
  Duration skew = const Duration(seconds: 30),
}) {
  final payload = decodeJwtPayload(accessToken);
  final exp = payload?['exp'];
  if (exp is! num) {
    return false;
  }
  final nowSeconds =
      (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  return exp.toInt() - skew.inSeconds > nowSeconds;
}
