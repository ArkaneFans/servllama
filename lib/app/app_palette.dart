import 'package:flutter/material.dart';
import 'package:servllama/core/models/inference_engine.dart';

/// Colors that carry meaning rather than decoration: engine identity and
/// runtime status. Both pairs were checked for normal-vision and CVD
/// separation, so they must be used as a set — swapping one member for a
/// nearby hue breaks the guarantee.
///
/// Engine identity is blue/orange. Blue + violet was tried first and rejected:
/// it failed CVD separation badly (deutan ΔE 4.6 light, 1.3 dark).
///
/// Status colors always appear with a dot or icon plus a label; the warning
/// fill (#FAB219) is 1.83:1 on white and is never used for text — that is what
/// [warningText] is for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.engineLlama,
    required this.engineMnn,
    required this.okMark,
    required this.okText,
    required this.warningMark,
    required this.warningText,
    required this.dangerMark,
    required this.dangerText,
    required this.idleMark,
  });

  static const AppPalette light = AppPalette(
    engineLlama: Color(0xFF3B6BF5),
    engineMnn: Color(0xFFE5601F),
    okMark: Color(0xFF0CA30C),
    okText: Color(0xFF0A7D0A),
    warningMark: Color(0xFFFAB219),
    warningText: Color(0xFF8A5D00),
    dangerMark: Color(0xFFD03B3B),
    dangerText: Color(0xFFB22B2B),
    idleMark: Color(0xFF9AA3B4),
  );

  static const AppPalette dark = AppPalette(
    engineLlama: Color(0xFF7DA2FF),
    engineMnn: Color(0xFFE0703A),
    okMark: Color(0xFF3ECF5E),
    okText: Color(0xFF6FE38A),
    warningMark: Color(0xFFFAB219),
    warningText: Color(0xFFF0C35C),
    dangerMark: Color(0xFFE86A6A),
    dangerText: Color(0xFFF08D8D),
    idleMark: Color(0xFF6E7788),
  );

  final Color engineLlama;
  final Color engineMnn;
  final Color okMark;
  final Color okText;
  final Color warningMark;
  final Color warningText;
  final Color dangerMark;
  final Color dangerText;
  final Color idleMark;

  Color engineColor(InferenceEngine engine) {
    switch (engine) {
      case InferenceEngine.llamaCpp:
        return engineLlama;
      case InferenceEngine.mnn:
        return engineMnn;
    }
  }

  @override
  AppPalette copyWith({
    Color? engineLlama,
    Color? engineMnn,
    Color? okMark,
    Color? okText,
    Color? warningMark,
    Color? warningText,
    Color? dangerMark,
    Color? dangerText,
    Color? idleMark,
  }) {
    return AppPalette(
      engineLlama: engineLlama ?? this.engineLlama,
      engineMnn: engineMnn ?? this.engineMnn,
      okMark: okMark ?? this.okMark,
      okText: okText ?? this.okText,
      warningMark: warningMark ?? this.warningMark,
      warningText: warningText ?? this.warningText,
      dangerMark: dangerMark ?? this.dangerMark,
      dangerText: dangerText ?? this.dangerText,
      idleMark: idleMark ?? this.idleMark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      engineLlama: Color.lerp(engineLlama, other.engineLlama, t)!,
      engineMnn: Color.lerp(engineMnn, other.engineMnn, t)!,
      okMark: Color.lerp(okMark, other.okMark, t)!,
      okText: Color.lerp(okText, other.okText, t)!,
      warningMark: Color.lerp(warningMark, other.warningMark, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerMark: Color.lerp(dangerMark, other.dangerMark, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      idleMark: Color.lerp(idleMark, other.idleMark, t)!,
    );
  }
}

extension AppPaletteX on ThemeData {
  AppPalette get palette =>
      extension<AppPalette>() ??
      (brightness == Brightness.light ? AppPalette.light : AppPalette.dark);
}
