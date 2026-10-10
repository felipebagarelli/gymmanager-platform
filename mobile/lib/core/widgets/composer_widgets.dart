import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Campo de texto arredondado dos compositores (chat e Personal IA).
class PillTextField extends StatelessWidget {
  const PillTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.enabled = true,
    this.maxLength = 1000,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: AppText.body(size: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(size: 15, color: AppColors.textMuted),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: border(AppColors.borderStrong),
        enabledBorder: border(AppColors.borderStrong),
        disabledBorder: border(AppColors.borderSubtle),
        focusedBorder: border(AppColors.volt),
      ),
    );
  }
}

/// Botão redondo de enviar (volt). Desabilitado fica translúcido e não responde ao toque.
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Enviar',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(gradient: AppColors.ctaGradient, shape: BoxShape.circle),
            child: const Icon(LucideIcons.send, size: 20, color: AppColors.onVolt),
          ),
        ),
      ),
    );
  }
}
