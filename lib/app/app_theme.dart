import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/shared/theme/app_visual_theme.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) =>
      AppVisualTheme.build(brightness).copyWith(
        extensions: <ThemeExtension<dynamic>>[
          brightness == Brightness.light ? AppPalette.light : AppPalette.dark,
        ],
      );
}
