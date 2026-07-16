import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserName = 'user_name';
  static const String _keyIsLoggedIn = 'is_logged_in';

  static SessionService? _instance;
  static SharedPreferences? _prefs;

  SessionService._();

  static Future<SessionService> getInstance() async {
    _instance ??= SessionService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Save user session after successful login
  Future<void> saveSession({
    required int userId,
    required String username,
    required String role,
    required String name,
  }) async {
    await _prefs!.setInt(_keyUserId, userId);
    await _prefs!.setString(_keyUsername, username);
    await _prefs!.setString(_keyUserRole, role);
    await _prefs!.setString(_keyUserName, name);
    await _prefs!.setBool(_keyIsLoggedIn, true);
  }

  /// Get saved user ID
  int? getUserId() {
    return _prefs!.getInt(_keyUserId);
  }

  /// Get saved username
  String? getUsername() {
    return _prefs!.getString(_keyUsername);
  }

  /// Get saved user role
  String? getUserRole() {
    return _prefs!.getString(_keyUserRole);
  }

  /// Get saved user name
  String? getUserName() {
    return _prefs!.getString(_keyUserName);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _prefs!.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Clear session on logout
  Future<void> clearSession() async {
    await _prefs!.remove(_keyUserId);
    await _prefs!.remove(_keyUsername);
    await _prefs!.remove(_keyUserRole);
    await _prefs!.remove(_keyUserName);
    await _prefs!.setBool(_keyIsLoggedIn, false);
  }

  /// Get all session data as Map
  Map<String, dynamic> getSessionData() {
    return {
      'userId': getUserId(),
      'username': getUsername(),
      'role': getUserRole(),
      'name': getUserName(),
      'isLoggedIn': isLoggedIn(),
    };
  }
}
