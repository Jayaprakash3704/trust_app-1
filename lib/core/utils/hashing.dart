import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPii(String value, String salt) {
  final bytes = utf8.encode('$value:$salt');
  return sha256.convert(bytes).toString();
}

String last4(String value) {
  if (value.length <= 4) {
    return value;
  }
  return value.substring(value.length - 4);
}
