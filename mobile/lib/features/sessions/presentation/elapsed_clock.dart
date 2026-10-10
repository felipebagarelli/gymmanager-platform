import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';

/// Cronômetro ao vivo do treino ("mm:ss" desde o início da sessão).
///
/// O valor é recalculado do relógio a cada pulso (e não somando 1 s por vez), então
/// continua certo mesmo se o app ficar em segundo plano.
class ElapsedClock extends ConsumerStatefulWidget {
  const ElapsedClock({super.key, required this.startedAt});

  final DateTime startedAt;

  @override
  ConsumerState<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends ConsumerState<ElapsedClock> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(secondTickerProvider).listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = ref.read(clockProvider)().difference(widget.startedAt).inSeconds;
    // o ponto pisca só se o usuário não pediu para reduzir animações
    final blink = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Tempo de treino ${formatClock(elapsed)}',
      excludeSemantics: true,
      child: Container(
        key: const Key('elapsed-clock'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(blink: blink),
            const SizedBox(width: 8),
            Text(formatClock(elapsed), style: AppText.display(20, weight: FontWeight.w600).copyWith(letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.blink});

  final bool blink;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.blink) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (widget.blink && !_controller.isAnimating) _controller.repeat(reverse: true);
    if (!widget.blink && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_controller),
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.ember, shape: BoxShape.circle)),
    );
  }
}
