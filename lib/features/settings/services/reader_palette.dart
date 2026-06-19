import 'package:flutter/material.dart';

import '../models/reading_settings.dart';

class ReaderPalette {
  static Color background(ReaderBackgroundMode mode, Brightness brightness) {
    return switch (mode) {
      ReaderBackgroundMode.paper => const Color(0xFFF4F1E8),
      ReaderBackgroundMode.white => const Color(0xFFFFFEFA),
      ReaderBackgroundMode.sepia => const Color(0xFFEBDDC5),
      ReaderBackgroundMode.gray => const Color(0xFFE8E8E3),
      ReaderBackgroundMode.black => const Color(0xFF111111),
    };
  }

  static Color foreground(ReaderBackgroundMode mode, Brightness brightness) {
    return switch (mode) {
      ReaderBackgroundMode.black => const Color(0xFFECECEC),
      ReaderBackgroundMode.paper ||
      ReaderBackgroundMode.white ||
      ReaderBackgroundMode.sepia ||
      ReaderBackgroundMode.gray => const Color(0xFF202020),
    };
  }
}
