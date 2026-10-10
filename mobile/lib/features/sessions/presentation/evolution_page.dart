import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/evolution_providers.dart';
import '../application/session_providers.dart';
import '../domain/evolution.dart';
import '../domain/history_stats.dart';

const _chartHeight = 190.0;
const _barsHeight = 110.0;

/// Aba "Evolução": carga máxima por semana de um exercício, volume semanal e recordes.
class EvolutionPage extends ConsumerStatefulWidget {
  const EvolutionPage({super.key});

  @override
  ConsumerState<EvolutionPage> createState() => _EvolutionPageState();
}

class _EvolutionPageState extends ConsumerState<EvolutionPage> {
  String? _exercise;
  int? _touched;
  int? _bar;

  @override
  Widget build(BuildContext context) {
    final evolution = ref.watch(evolutionProvider);
    return evolution.when(
      loading: () => const SkeletonList(heights: [44, 280, 200, 90]),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(evolutionProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: LucideIcons.trendingUp,
            message: 'Finalize alguns treinos para acompanhar sua evolução aqui.',
          );
        }
        final selected = items.firstWhere((e) => e.exerciseName == _exercise, orElse: () => items.first);
        final now = ref.watch(clockProvider)();
        final sessions = ref.watch(historyProvider).value ?? const [];
        final volumes = weeklyVolume(sessions, now);
        final barIndex = (_bar ?? volumes.length - 1).clamp(0, volumes.length - 1);

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(evolutionProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
            children: [
              _ExerciseChips(
                names: [for (final e in items) e.exerciseName],
                selected: selected.exerciseName,
                onSelected: (name) => setState(() {
                  _exercise = name;
                  _touched = null;
                }),
              ),
              const SizedBox(height: 14),
              _LoadCard(
                key: Key('progress-${selected.exerciseName}'),
                progress: selected,
                touched: _touched,
                onTouched: (index) => setState(() => _touched = index),
              ),
              const SizedBox(height: 14),
              _VolumeCard(
                weeks: volumes,
                selected: barIndex,
                onSelected: (index) => setState(() => _bar = index),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _RecordCard(best: selected.bestLoadKg)),
                  const SizedBox(width: 12),
                  Expanded(child: _MonthCard(count: sessionsInMonth(sessions, now))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseChips extends StatelessWidget {
  const _ExerciseChips({required this.names, required this.selected, required this.onSelected});

  final List<String> names;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final name = names[index];
          final on = name == selected;
          return Semantics(
            button: true,
            selected: on,
            label: name,
            excludeSemantics: true,
            child: GestureDetector(
              key: Key('exercise-chip-$name'),
              onTap: () => onSelected(name),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.volt.withValues(alpha: 0.14) : AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: on ? AppColors.volt : AppColors.borderSubtle),
                ),
                child: Text(name,
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: on ? AppColors.volt : AppColors.textSecondary)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({super.key, required this.progress, required this.touched, required this.onTouched});

  final ExerciseProgress progress;
  final int? touched;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final series = weeklyMaxLoad(progress);
    final gain = gainPercent(series);
    final span = weeksSpan(series);
    final index = (touched ?? series.length - 1).clamp(0, series.isEmpty ? 0 : series.length - 1);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: LabelText('Carga máxima por semana')),
              if (gain != null)
                TagChip(
                  key: const Key('progress-delta'),
                  '${gain >= 0 ? '+' : '−'}${gain.abs()}% em $span sem',
                  color: gain >= 0 ? AppColors.success : AppColors.ember,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (series.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${progress.points.length} ${progress.points.length == 1 ? 'sessão registrada' : 'sessões registradas'} (sem carga informada)',
                key: const Key('no-load-data'),
                style: AppText.body(size: 14, color: AppColors.textMuted),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(formatNumber(series[index].value), key: const Key('load-readout'), style: AppText.display(44)),
                const SizedBox(width: 4),
                Text('kg', style: AppText.display(18, color: AppColors.textSecondary, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('semana de ${formatDayMonth(series[index].weekStart)}',
                    key: const Key('load-readout-date'), style: AppText.body(size: 13, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Gráfico da carga máxima por semana de ${progress.exerciseName}: '
                  'de ${formatNumber(series.first.value)} kg na semana de ${formatDayMonth(series.first.weekStart)} '
                  'para ${formatNumber(series.last.value)} kg na semana de ${formatDayMonth(series.last.weekStart)}',
              child: ExcludeSemantics(
                child: SizedBox(
                  key: const Key('load-chart'),
                  height: _chartHeight,
                  child: _LineChartView(series: series, selected: index, onTouched: onTouched),
                ),
              ),
            ),
            if (series.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Registre mais um treino para ver sua evolução.',
                    key: const Key('evolution-one-point'), style: AppText.body(size: 13, color: AppColors.textMuted)),
              ),
          ],
        ],
      ),
    );
  }
}

class _LineChartView extends StatelessWidget {
  const _LineChartView({required this.series, required this.selected, required this.onTouched});

  final List<WeekPoint> series;
  final int selected;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final n = series.length;
    final values = [for (final p in series) p.value];
    final low = (((values.reduce((a, b) => a < b ? a : b) - 2.5) / 2.5).floor() * 2.5).clamp(0.0, double.infinity);
    final rawHigh = ((values.reduce((a, b) => a > b ? a : b) + 2.5) / 2.5).ceil() * 2.5;
    // 4 faixas; o passo é sempre múltiplo de 2,5 kg para os rótulos do eixo saírem limpos ("37,5")
    final step = (((rawHigh - low) / 4) / 2.5).ceil().clamp(1, 1000) * 2.5;
    final high = low + step * 4;

    return LineChart(
      LineChartData(
        minX: n == 1 ? -1 : 0,
        maxX: n == 1 ? 1 : (n - 1).toDouble(),
        minY: low,
        maxY: high,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: step,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(formatNumber(value), style: AppText.body(size: 11, color: AppColors.textMuted)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (value != i.toDouble() || i < 0 || i >= n) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(formatDayMonth(series[i].weekStart), style: AppText.body(size: 10.5, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          // a leitura do valor fica acima do gráfico; aqui só a linha-guia e o ponto
          touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => [for (final _ in spots) null]),
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: AppColors.volt.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: const [4, 4]),
                FlDotData(getDotPainter: _dotPainter),
              ),
          ],
          touchCallback: (event, response) {
            final spot = response?.lineBarSpots?.firstOrNull;
            if (spot != null && event.isInterestedForInteractions) onTouched(spot.spotIndex);
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), series[i].value)],
            isCurved: n > 2,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: AppColors.volt,
            barWidth: 3,
            dotData: FlDotData(
              checkToShowDot: (spot, bar) => spot.x == selected.toDouble(),
              getDotPainter: _dotPainter,
            ),
            belowBarData: BarAreaData(
              show: n > 1,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.volt.withValues(alpha: 0.28), AppColors.volt.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

FlDotPainter _dotPainter(FlSpot spot, double percent, LineChartBarData bar, int index) =>
    FlDotCirclePainter(radius: 6, color: AppColors.volt, strokeWidth: 3, strokeColor: AppColors.bg);

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.weeks, required this.selected, required this.onSelected});

  final List<WeekPoint> weeks;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final peak = weeks.map((w) => w.value).fold(0.0, (a, b) => a > b ? a : b);
    final current = weeks[selected];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const LabelText('Volume semanal'),
              Text('${formatDayMonth(current.weekStart)} · ${formatVolume(current.value)}',
                  key: const Key('volume-readout'), style: AppText.body(size: 14, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _barsHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      label: 'Semana de ${formatDayMonth(weeks[i].weekStart)}: ${formatVolume(weeks[i].value)}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: Key('volume-bar-$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(i),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 22,
                            height: peak <= 0 ? 4 : (weeks[i].value / peak * _barsHeight).clamp(4, _barsHeight),
                            decoration: BoxDecoration(
                              color: i == selected ? AppColors.volt : AppColors.volt.withValues(alpha: 0.28),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final week in weeks)
                Expanded(
                  child: Center(
                    child: Text(formatDayMonth(week.weekStart), style: AppText.body(size: 10, color: AppColors.textMuted)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.best});

  final double? best;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('record-card'),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Recorde'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.trophy, size: 20, color: AppColors.volt),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(best == null ? '—' : formatLoad(best), key: const Key('record-value'), style: AppText.display(30)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Treinos no mês'),
          const SizedBox(height: 6),
          Text('$count', key: const Key('month-count'), style: AppText.display(30)),
        ],
      ),
    );
  }
}
