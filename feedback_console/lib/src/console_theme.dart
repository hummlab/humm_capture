import 'package:flutter/material.dart';

abstract final class ConsoleColors {
  static const canvas = Color(0xFFFAFAF8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF232522);
  static const muted = Color(0xFF666963);
  static const line = Color(0xFFE4E6DF);
  static const wash = Color(0xFFF0F2EC);
  static const selected = Color(0xFFE5EBE1);
  static const accent = Color(0xFF324F42);
}

ThemeData consoleTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ConsoleColors.accent).copyWith(
    primary: ConsoleColors.accent,
    onPrimary: Colors.white,
    surface: ConsoleColors.surface,
    onSurface: ConsoleColors.ink,
    onSurfaceVariant: ConsoleColors.muted,
    outlineVariant: ConsoleColors.line,
    surfaceContainerLow: ConsoleColors.wash,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Geist');
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  return base.copyWith(
    scaffoldBackgroundColor: ConsoleColors.canvas,
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ConsoleColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ConsoleColors.ink,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ConsoleColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: ConsoleColors.line, thickness: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: ConsoleColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: ConsoleColors.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape, minimumSize: const Size(0, 44)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: shape,
      side: BorderSide.none,
      backgroundColor: Colors.transparent,
      selectedColor: ConsoleColors.wash,
      labelStyle: const TextStyle(fontFamily: 'Geist', fontSize: 13, color: ConsoleColors.ink),
      showCheckmark: false,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      childrenPadding: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ConsoleColors.surface,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: ConsoleColors.muted, fontSize: 13),
      hintStyle: const TextStyle(color: ConsoleColors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ConsoleColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ConsoleColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ConsoleColors.accent, width: 2),
      ),
    ),
  );
}
