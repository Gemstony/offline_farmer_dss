import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _usernameKey = 'username';
  static const String _passwordHashKey = 'password_hash';
  static const String _saltKey = 'salt';
  static const String _sessionKey = 'is_logged_in';

  /// Check if a user has already registered
  Future<bool> isUserRegistered() async {
    final username = await _secureStorage.read(key: _usernameKey);
    final hash = await _secureStorage.read(key: _passwordHashKey);
    return username != null && hash != null;
  }

  /// Register a new user
  Future<bool> register(String username, String password) async {
    if (await isUserRegistered()) {
      return false;
    }
    final salt = _generateSalt();
    final hashedPassword = _hashPassword(password, salt);
    await _secureStorage.write(key: _usernameKey, value: username);
    await _secureStorage.write(key: _saltKey, value: salt);
    await _secureStorage.write(key: _passwordHashKey, value: hashedPassword);
    return true;
  }

  /// Login existing user
  Future<bool> login(String username, String password) async {
    final storedUsername = await _secureStorage.read(key: _usernameKey);
    final storedSalt = await _secureStorage.read(key: _saltKey);
    final storedHash = await _secureStorage.read(key: _passwordHashKey);

    if (storedUsername == null || storedSalt == null || storedHash == null) {
      return false;
    }
    if (storedUsername != username) {
      return false;
    }

    final hashedInput = _hashPassword(password, storedSalt);
    if (hashedInput == storedHash) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      return true;
    }
    return false;
  }

  /// Check if user is already logged in (session exists)
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionKey) ?? false;
  }

  /// Logout – clear session flag
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  String _hashPassword(String password, String salt) {
    final saltedPassword = password + salt;
    final bytes = utf8.encode(saltedPassword);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Get the username of the currently logged‑in user
  Future<String?> getCurrentUsername() async {
    return await _secureStorage.read(key: _usernameKey);
  }

  /// Update username (only if new username is different and not empty)
  Future<bool> updateUsername(String newUsername) async {
    if (newUsername.trim().isEmpty) return false;
    final currentUsername = await getCurrentUsername();
    if (currentUsername == newUsername) return false;
    await _secureStorage.write(key: _usernameKey, value: newUsername);
    return true;
  }

  /// Change password: requires current password for verification
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final storedSalt = await _secureStorage.read(key: _saltKey);
    final storedHash = await _secureStorage.read(key: _passwordHashKey);
    if (storedSalt == null || storedHash == null) return false;

    final hashedCurrent = _hashPassword(currentPassword, storedSalt);
    if (hashedCurrent != storedHash) return false;

    final newSalt = _generateSalt();
    final newHashed = _hashPassword(newPassword, newSalt);
    await _secureStorage.write(key: _saltKey, value: newSalt);
    await _secureStorage.write(key: _passwordHashKey, value: newHashed);
    return true;
  }


  /// Check if a username exists (for password reset)
Future<bool> usernameExists(String username) async {
  final storedUsername = await _secureStorage.read(key: _usernameKey);
  return storedUsername == username;
}

/// Reset password (forgot password flow)
/// Requires username and new password
Future<bool> resetPassword(String username, String newPassword) async {
  if (!await usernameExists(username)) return false;
  final newSalt = _generateSalt();
  final newHashed = _hashPassword(newPassword, newSalt);
  await _secureStorage.write(key: _saltKey, value: newSalt);
  await _secureStorage.write(key: _passwordHashKey, value: newHashed);
  return true;
}
}
