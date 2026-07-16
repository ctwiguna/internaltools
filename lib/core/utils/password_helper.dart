import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class PasswordHelper {
  static const Uuid _uuid = Uuid();

  /// Generate a salt
  static String generateSalt() {
    return _uuid.v4().replaceAll('-', '').substring(0, 16);
  }

  /// Hash password with salt
  /// Returns: "salt:hashedPassword"
  static String hashPassword(String password) {
    final salt = generateSalt();
    final saltedPassword = '$salt$password';
    final hash = sha256.convert(utf8.encode(saltedPassword)).toString();
    return '$salt:$hash';
  }

  /// Verify password against stored hash
  /// storedHash format: "salt:hashedPassword"
  static bool verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final hash = parts[1];

      final saltedPassword = '$salt$password';
      final computedHash = sha256.convert(utf8.encode(saltedPassword)).toString();

      return hash == computedHash;
    } catch (e) {
      return false;
    }
  }

  /// Validate password strength
  /// Returns null if valid, error message if invalid
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (password.length < 6) {
      return 'Password minimal 6 karakter';
    }
    if (password.length > 20) {
      return 'Password maksimal 20 karakter';
    }
    return null;
  }

  /// Validate username
  /// Returns null if valid, error message if invalid
  static String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username tidak boleh kosong';
    }
    if (username.length < 3) {
      return 'Username minimal 3 karakter';
    }
    if (username.length > 20) {
      return 'Username maksimal 20 karakter';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username hanya boleh huruf, angka, dan underscore';
    }
    return null;
  }
}
