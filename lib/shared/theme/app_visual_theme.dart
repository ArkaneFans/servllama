import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared visual tokens approved in the design gallery.
abstract final class AppVisualTheme {
  static const cardRadius = 18.0;
  static const fieldRadius = 14.0;
  static const pageInset = 20.0;

  static ThemeData build(Brightness brightness, {bool tea = false}) {
    final dark = brightness == Brightness.dark;
    var colors =
        ColorScheme.fromSeed(
          seedColor: Color(tea ? 0xFF796A70 : 0xFF606397),
          brightness: brightness,
        ).copyWith(
          primary: Color(dark ? 0xFFC3C5F0 : 0xFF595D91),
          onPrimary: Color(dark ? 0xFF292C54 : 0xFFFFFFFF),
          primaryContainer: Color(dark ? 0xFF333650 : 0xFFE9EAF7),
          onPrimaryContainer: Color(dark ? 0xFFE3E4FF : 0xFF444876),
          surface: Color(dark ? 0xFF17181D : 0xFFF6F7F9),
          surfaceContainerLowest: Color(dark ? 0xFF1F2027 : 0xFFFFFFFF),
          surfaceContainerLow: Color(dark ? 0xFF25262E : 0xFFF0F1F5),
          surfaceContainer: Color(dark ? 0xFF2A2C36 : 0xFFEBECF2),
          onSurface: Color(dark ? 0xFFE9EAF0 : 0xFF272933),
          onSurfaceVariant: Color(dark ? 0xFFB0B2C0 : 0xFF686C7C),
          outline: Color(dark ? 0xFF808392 : 0xFF858997),
          outlineVariant: Color(dark ? 0xFF383A46 : 0xFFE1E3EB),
          surfaceTint: Colors.transparent,
        );
    if (tea) {
      colors = colors.copyWith(
        primary: Color(dark ? 0xFFD5BFC7 : 0xFF796A70),
        onPrimary: Color(dark ? 0xFF402E36 : 0xFFFFFFFF),
        primaryContainer: Color(dark ? 0xFF493B42 : 0xFFEEE3E7),
        onPrimaryContainer: Color(dark ? 0xFFF5DFE6 : 0xFF59474F),
        surface: Color(dark ? 0xFF1C191B : 0xFFF8F6F5),
        surfaceContainerLowest: Color(dark ? 0xFF252123 : 0xFFFFFDFC),
        surfaceContainerLow: Color(dark ? 0xFF2C2729 : 0xFFF2EDEC),
        surfaceContainer: Color(dark ? 0xFF322C2F : 0xFFECE5E6),
        onSurface: Color(dark ? 0xFFEFE7E9 : 0xFF302B2D),
        onSurfaceVariant: Color(dark ? 0xFFBFB2B8 : 0xFF756B70),
        outline: Color(dark ? 0xFF94878D : 0xFF94878C),
        outlineVariant: Color(dark ? 0xFF443B3F : 0xFFE6DFE1),
      );
    }
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final text = base.textTheme.copyWith(
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: colors.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: colors.onSurface),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: colors.onSurface),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.onSurface,
      ),
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return base.copyWith(
      // Keep pressed/hover/focus state layers, without a long-lived ripple
      // that can be captured by a page transition and reappear on return.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colors.onSurface.withValues(alpha: .06),
      textTheme: text,
      canvasColor: colors.surface,
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colors.onPrimaryContainer,
          backgroundColor: colors.primaryContainer,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 0.7,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 22),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        iconColor: colors.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        selectedTileColor: colors.primaryContainer,
        selectedColor: colors.onPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        alignLabelWithHint: true,
        helperMaxLines: 5,
        errorMaxLines: 3,
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          foregroundColor: colors.onSurface,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerLowest,
        selectedColor: colors.primaryContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.bodySmall,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colors.onPrimaryContainer,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        splashBorderRadius: BorderRadius.circular(24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),
    );
  }
}
