import 'package:flutter/material.dart';

enum ReaderBackgroundMode { paper, white, sepia, gray, black }

class ReadingSettings {
  const ReadingSettings({
    this.themeMode = ThemeMode.system,
    this.fontSize = 18,
    this.lineHeight = 1.65,
    this.fontFamily = 'Roboto',
    this.backgroundMode = ReaderBackgroundMode.paper,
  });

  final ThemeMode themeMode;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final ReaderBackgroundMode backgroundMode;

  ThemeMode get materialThemeMode => themeMode;

  ReadingSettings copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    ReaderBackgroundMode? backgroundMode,
  }) {
    return ReadingSettings(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      backgroundMode: backgroundMode ?? this.backgroundMode,
    );
  }

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    return ReadingSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.65,
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      backgroundMode: ReaderBackgroundMode.values.firstWhere(
        (mode) => mode.name == json['backgroundMode'],
        orElse: () => ReaderBackgroundMode.paper,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'fontFamily': fontFamily,
    'backgroundMode': backgroundMode.name,
  };

  static const defaults = ReadingSettings();
}
