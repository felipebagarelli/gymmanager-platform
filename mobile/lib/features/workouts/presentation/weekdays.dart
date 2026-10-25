import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/pill_button.dart';
import '../domain/workout.dart';

/// Dias da semana como o servidor usa: 1 = segunda ... 7 = domingo (o mesmo de [DateTime.weekday]).
const weekdayShort = {1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom'};
const weekdayLong = {1: 'Segunda', 2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado', 7: 'Domingo'};

/// "Seg · Qua · Sex" (vazio se não há dia marcado).
String formatWeekdays(Iterable<int> days) => [for (final d in ({...days}.toList()..sort())) weekdayShort[d]!].join(' · ');

/// Quantos dias faltam, a partir de [today] (1–7), para o próximo dia do treino (0 = hoje).
/// Null se o treino não tem dia marcado.
int? daysUntilNext(List<int> weekdays, int today) {
  if (weekdays.isEmpty) return null;
  return [for (final d in weekdays) (d - today) % 7].reduce((a, b) => a < b ? a : b);
}

/// Linha com os 7 dias para marcar e desmarcar.
class WeekdayToggles extends StatelessWidget {
  const WeekdayToggles({super.key, required this.selected, required this.onChanged, this.keyPrefix = 'weekday'});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final day in weekdayShort.keys)
          FilterChip(
            key: Key('$keyPrefix-$day'),
            label: Text(weekdayShort[day]!),
            tooltip: weekdayLong[day],
            selected: selected.contains(day),
            showCheckmark: false,
            selectedColor: AppColors.volt,
            labelStyle: AppText.body(
              size: 13.5,
              weight: FontWeight.w600,
              color: selected.contains(day) ? AppColors.onVolt : AppColors.textPrimary,
            ),
            onSelected: (on) => onChanged(on ? {...selected, day} : ({...selected}..remove(day))),
          ),
      ],
    );
  }
}

/// Escolhe os dias de um treino. Retorna os dias (vazio = sem dia marcado) ou null se fechou.
Future<Set<int>?> showWeekdaysPicker(BuildContext context, {required String title, Set<int> initial = const {}}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _WeekdaysPicker(title: title, initial: initial),
  );
}

class _WeekdaysPicker extends StatefulWidget {
  const _WeekdaysPicker({required this.title, required this.initial});

  final String title;
  final Set<int> initial;

  @override
  State<_WeekdaysPicker> createState() => _WeekdaysPickerState();
}

class _WeekdaysPickerState extends State<_WeekdaysPicker> {
  late Set<int> _days = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('weekdays-picker'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title.toUpperCase(), style: AppText.display(26)),
          const SizedBox(height: 4),
          Text('Em que dias da semana este treino é feito? Sem dia marcado, ele fica livre.',
              style: AppText.body(size: 13.5, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          WeekdayToggles(selected: _days, onChanged: (days) => setState(() => _days = days)),
          const SizedBox(height: 18),
          PillButton(key: const Key('save-weekdays'), label: 'Salvar dias', onPressed: () => Navigator.of(context).pop(_days)),
        ],
      ),
    );
  }
}

/// A semana inteira de um aluno: para cada dia, quais dos treinos ativos dele são feitos.
/// Retorna os dias de cada treino (id → dias) ou null se fechou.
Future<Map<int, Set<int>>?> showWeekScheduleSheet(BuildContext context, {required List<Workout> workouts}) {
  return showModalBottomSheet<Map<int, Set<int>>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _WeekSchedule(workouts: workouts),
  );
}

class _WeekSchedule extends StatefulWidget {
  const _WeekSchedule({required this.workouts});

  final List<Workout> workouts;

  @override
  State<_WeekSchedule> createState() => _WeekScheduleState();
}

class _WeekScheduleState extends State<_WeekSchedule> {
  late final Map<int, Set<int>> _days = {for (final w in widget.workouts) w.id: {...w.weekdays}};

  void _toggle(int workoutId, int day, bool on) =>
      setState(() => on ? _days[workoutId]!.add(day) : _days[workoutId]!.remove(day));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        key: const Key('week-schedule'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEMANA DE TREINOS', style: AppText.display(26)),
                Text('Marque o treino de cada dia. Dia sem treino é descanso.',
                    style: AppText.body(size: 13.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              children: [
                for (final day in weekdayShort.keys) ...[
                  Text(weekdayLong[day]!, style: AppText.body(size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in widget.workouts)
                        FilterChip(
                          key: Key('day-$day-workout-${w.id}'),
                          label: Text(w.name),
                          selected: _days[w.id]!.contains(day),
                          showCheckmark: false,
                          selectedColor: AppColors.volt,
                          labelStyle: AppText.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: _days[w.id]!.contains(day) ? AppColors.onVolt : AppColors.textPrimary,
                          ),
                          onSelected: (on) => _toggle(w.id, day, on),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: PillButton(
                key: const Key('save-week'),
                label: 'Salvar semana',
                onPressed: () => Navigator.of(context).pop(_days),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
