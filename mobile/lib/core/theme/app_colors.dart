import 'package:flutter/material.dart';

/// Tokens de cor do tema escuro único (ver INSTRUCOES_REDESIGN_APP_ALUNO.md, seção 2).
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0C0F);
  static const surface = Color(0xFF13161B);
  static const elevated = Color(0xFF1B1F26);
  static const overlay = Color(0xFF252A33);
  static const borderSubtle = Color(0xFF232831);
  static const borderStrong = Color(0xFF343B48);

  static const textPrimary = Color(0xFFF4F6F8);
  static const textSecondary = Color(0xFFA3ABB8);
  static const textMuted = Color(0xFF6B7482);

  /// Único destaque forte: CTA, progresso e item ativo.
  static const volt = Color(0xFFC8F03C);
  static const onVolt = Color(0xFF0A0C0F);
  static const ember = Color(0xFFFF6A3D);
  static const sky = Color(0xFF5CC8FF);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFFF5470);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDDFF52), Color(0xFF9BD10C)],
  );
  static const ctaGradient = LinearGradient(colors: [Color(0xFFDDFF52), Color(0xFFB4E21A)]);
  static const avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC8F03C), Color(0xFF7FB800)],
  );

  /// Mistura [color] sobre [base] com a opacidade dada (equivale ao color-mix do protótipo).
  static Color mix(Color color, double amount, [Color base = surface]) =>
      Color.alphaBlend(color.withValues(alpha: amount), base);
}

/// Cor de cada grupo muscular (tag e barra de foco).
///
/// Regra para grupos além dos três do protótipo: movimentos de empurrar e
/// parte superior frontal = volt; membros inferiores = sky; puxar e posterior
/// = ember; o restante (abdômen, cardio, etc.) usa cinza neutro.
/// A cor nunca vai sozinha: toda tag mostra também o nome do grupo.
Color muscleGroupColor(String? group) {
  final g = (group ?? '').toLowerCase();
  bool has(List<String> keys) => keys.any(g.contains);
  if (has(['peito', 'ombro', 'tríceps', 'triceps'])) return AppColors.volt;
  if (has(['perna', 'glúteo', 'gluteo', 'panturrilha', 'quadríceps', 'quadriceps', 'posterior de coxa'])) {
    return AppColors.sky;
  }
  if (has(['costas', 'bíceps', 'biceps', 'trapézio', 'trapezio', 'antebraço', 'antebraco'])) {
    return AppColors.ember;
  }
  return AppColors.textSecondary;
}
