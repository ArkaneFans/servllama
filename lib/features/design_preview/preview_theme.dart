import 'package:flutter/material.dart';
import 'package:servllama/shared/theme/app_visual_theme.dart';

enum PreviewPalette { violet, tea }

/// Tea remains a gallery option; the application uses the approved violet.
abstract final class PreviewTheme {
  static const cardRadius = AppVisualTheme.cardRadius;
  static const fieldRadius = AppVisualTheme.fieldRadius;
  static const pageInset = AppVisualTheme.pageInset;
  static ThemeData build(
    Brightness brightness, {
    PreviewPalette palette = PreviewPalette.violet,
  }) => AppVisualTheme.build(brightness, tea: palette == PreviewPalette.tea);
}
