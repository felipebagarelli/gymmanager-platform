import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/progress_ring.dart';

/// O que a tela de descanso mostra (montado pela tela de execução ao salvar uma série).
class RestPlan {
  const RestPlan({
    required this.savedMessage,
    required this.totalSeconds,
    this.nextTitle,
    this.nextDetail,
    this.nextGroup,
  });

  /// "Série 2 de Supino salva · 10 × 22,5 kg".
  final String savedMessage;
  final int totalSeconds;

  /// Próxima série; null quando todas as séries do treino foram feitas.
  final String? nextTitle;
  final String? nextDetail;
  final String? nextGroup;

  bool get allDone => nextTitle == null;
}

/// Descanso entre séries: anel regressivo, ±15 s, pular e a próxima série.
/// Ao chegar a zero chama [onFinished] (volta sozinho para a execução).
class RestView extends ConsumerStatefulWidget {
  const RestView({super.key, required this.plan, required this.onFinished});

  final RestPlan plan;
  final VoidCallback onFinished;

  @override
  ConsumerState<RestView> createState() => _RestViewState();
}

class _RestViewState extends ConsumerState<RestView> {
  static const _adjustSeconds = 15;

  late DateTime _endsAt;
  late int _total;
  int _remaining = 0;
  bool _finished = false;
  StreamSubscription<void>? _subscription;

  DateTime get _now => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _total = widget.plan.totalSeconds;
    _endsAt = _now.add(Duration(seconds: _total));
    _remaining = _total;
    // o tempo restante vem do relógio (fim previsto - agora), então não "congela" com a tela apagada
    _subscription = ref.read(secondTickerProvider).listen((_) => _tick());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    final left = (_endsAt.difference(_now).inMilliseconds / 1000).ceil();
    setState(() => _remaining = left < 0 ? 0 : left);
    if (_remaining == 0) _finish(vibrate: true);
  }

  void _finish({bool vibrate = false}) {
    if (_finished) return;
    _finished = true;
    if (vibrate) HapticFeedback.mediumImpact();
    widget.onFinished();
  }

  void _adjust(int delta) {
    setState(() {
      _endsAt = _endsAt.add(Duration(seconds: delta));
      final left = (_endsAt.difference(_now).inMilliseconds / 1000).ceil();
      _remaining = left < 0 ? 0 : left;
      if (_remaining > _total) _total = _remaining;
    });
    if (_remaining == 0) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final group = plan.nextGroup;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar ao treino', onPressed: _finish),
                const LabelText('Descanso'),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 12),
              child: Column(
                children: [
                  InfoAlert(kind: AlertKind.good, icon: LucideIcons.check, text: plan.savedMessage),
                  const SizedBox(height: 24),
                  ProgressRing(
                    value: _total == 0 ? 0 : _remaining / _total,
                    size: 240,
                    stroke: 12,
                    semanticsLabel: 'Tempo de descanso restante',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // o anel tem largura fixa: reduz o relógio em vez de quebrar linha (fonte grande do sistema)
                        SizedBox(
                          width: 190,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(formatClock(_remaining), key: const Key('rest-time'), style: AppText.display(84)),
                          ),
                        ),
                        const LabelText('Descanso', size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PillButton(
                        key: const Key('rest-minus'),
                        label: '15 s',
                        icon: LucideIcons.rewind,
                        style: PillStyle.ghost,
                        height: 44,
                        expand: false,
                        onPressed: () => _adjust(-_adjustSeconds),
                      ),
                      const SizedBox(width: 12),
                      PillButton(
                        key: const Key('rest-plus'),
                        label: '+15 s',
                        style: PillStyle.ghost,
                        height: 44,
                        expand: false,
                        onPressed: () => _adjust(_adjustSeconds),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AppCard(
                    radius: 16,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LabelText(plan.allDone ? 'Treino completo' : 'Próxima série'),
                              const SizedBox(height: 6),
                              Text(plan.allDone ? 'Todas as séries feitas' : plan.nextTitle!,
                                  key: const Key('rest-next'), style: AppText.body(size: 17, weight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(plan.allDone ? 'Finalize para ver o resumo' : (plan.nextDetail ?? ''),
                                  style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        if (group != null && group.trim().isNotEmpty) TagChip(group, color: muscleGroupColor(group)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
            child: PillButton(
              key: const Key('rest-skip'),
              label: plan.allDone ? 'Voltar ao treino' : 'Pular descanso',
              icon: LucideIcons.skipForward,
              onPressed: _finish,
            ),
          ),
        ],
      ),
    );
  }
}
