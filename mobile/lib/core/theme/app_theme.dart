import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Margem lateral padrão das telas.
const double kScreenPadding = 20;

class AppTheme {
  AppTheme._();

  /// Tema escuro único do app.
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.volt,
      onPrimary: AppColors.onVolt,
      secondary: AppColors.sky,
      onSecondary: AppColors.onVolt,
      tertiary: AppColors.ember,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.bg,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.elevated,
      surfaceContainerHighest: AppColors.overlay,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderSubtle,
      error: AppColors.danger,
      onError: AppColors.onVolt,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.borderStrong),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      fontFamily: 'Barlow',
      textTheme: AppText.textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.display(28),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.body(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.volt, width: 1.5)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.volt,
          foregroundColor: AppColors.onVolt,
          minimumSize: const Size(44, 54),
          shape: const StadiumBorder(),
          textStyle: AppText.body(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 50),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
          textStyle: AppText.body(size: 15, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.volt,
          minimumSize: const Size(44, 44),
          textStyle: AppText.body(size: 14, weight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.overlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.elevated,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppText.body(color: AppColors.bg, weight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderSubtle, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.volt),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
