import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Estilos de texto do app. Títulos e números grandes usam Barlow Condensed em
/// caixa alta; o resto usa Barlow.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  /// Título/número grande. Sempre com algarismos tabulares, para cronômetros,
  /// cargas e contadores não "pularem" ao mudar de valor.
  static TextStyle display(double size, {Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: 'BarlowCondensed',
        fontSize: size,
        fontWeight: weight,
        height: 1,
        color: color,
        fontFeatures: _tabular,
      );

  /// Rótulo pequeno em caixa alta (aplicar `.toUpperCase()` no texto).
  static TextStyle label({Color color = AppColors.textMuted, double size = 11}) => TextStyle(
        fontFamily: 'Barlow',
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: color,
      );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) =>
      TextStyle(fontFamily: 'Barlow', fontSize: size, fontWeight: weight, color: color, fontFeatures: _tabular);

  static TextTheme textTheme() => TextTheme(
        displayLarge: display(64, weight: FontWeight.w800),
        displayMedium: display(44),
        displaySmall: display(36),
        headlineLarge: display(32),
        headlineMedium: display(28),
        headlineSmall: display(24),
        titleLarge: display(22, weight: FontWeight.w600),
        titleMedium: body(size: 17, weight: FontWeight.w600),
        titleSmall: body(size: 14, weight: FontWeight.w600),
        bodyLarge: body(size: 16),
        bodyMedium: body(),
        bodySmall: body(size: 13, color: AppColors.textSecondary),
        labelLarge: body(size: 15, weight: FontWeight.w700),
        labelMedium: label(),
        labelSmall: label(),
      );
}
