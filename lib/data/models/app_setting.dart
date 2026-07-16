import 'package:equatable/equatable.dart';

class AppSetting extends Equatable {
  final String key;
  final String value;

  const AppSetting({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }

  AppSetting copyWith({
    String? key,
    String? value,
  }) {
    return AppSetting(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  List<Object?> get props => [key, value];
}
