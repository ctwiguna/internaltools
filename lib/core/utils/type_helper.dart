/// Helper functions for safe type casting from database/API responses
class TypeHelper {
  /// Safely cast a value to String? handling both int and String types
  /// Used for fields like outlet_id that may be stored as INTEGER in SQLite
  /// but expected as String? in Dart models
  static String? asNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  /// Safely cast a value to int? handling both int and String types
  static int? asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Safely cast a value to int with default value
  static int asInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  /// Safely cast a value to double? handling both double and int types
  static double? asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely cast a value to double with default value
  static double asDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Safely cast a value to bool
  static bool asBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return defaultValue;
  }

    /// Safely cast a value to String with default value
  static String asString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }
}
