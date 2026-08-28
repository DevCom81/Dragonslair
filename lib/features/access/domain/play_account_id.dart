import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Google Play obfuscatedAccountId. SHA-256 of the Supabase user UUID.
/// Never pass PII. Max 64 chars (Play Billing limit).
String playObfuscatedAccountId(String userId) {
  final trimmed = userId.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return sha256.convert(utf8.encode('dragons_lair:$trimmed')).toString();
}
