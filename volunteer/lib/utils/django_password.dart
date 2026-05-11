import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Implements just enough of Django's password machinery to verify and
/// generate hashes in the `pbkdf2_sha256$<iterations>$<salt>$<base64hash>`
/// format that Django uses by default.
class DjangoPassword {
  static const int _defaultIterations = 600000;
  static const String _algorithm = 'pbkdf2_sha256';

  /// Verify that [password] matches the encoded Django hash [encoded].
  /// Returns false for unknown algorithms or malformed input.
  static bool verify(String password, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4) return false;
    if (parts[0] != _algorithm) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;
    final salt = parts[2];
    final expected = parts[3];
    final actual = _pbkdf2(password, salt, iterations);
    return _constantTimeEquals(actual, expected);
  }

  /// Build a Django-compatible encoded hash for [password] using a fresh
  /// random salt and the default iteration count.
  static String makePassword(String password, {int? iterations}) {
    final iters = iterations ?? _defaultIterations;
    final salt = _randomSalt();
    final hash = _pbkdf2(password, salt, iters);
    return '$_algorithm\$$iters\$$salt\$$hash';
  }

  static String _pbkdf2(String password, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = utf8.encode(salt);

    // Derive a single 32-byte block (sha256 output size).
    final block = Uint8List(4);
    block[3] = 1;

    var u = hmac.convert([...saltBytes, ...block]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64.encode(result);
  }

  static String _randomSalt({int length = 22}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
