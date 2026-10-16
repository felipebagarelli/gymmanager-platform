import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../sessions/presentation/evolution_page.dart';
import '../../../sessions/presentation/history_page.dart';
import '../../../sessions/presentation/history_sessions_tab.dart';
import '../../../workouts/domain/workout.dart';
import '../../workouts/application/trainer_workouts_providers.dart';
import '../application/students_providers.dart';

/// Histórico de um aluno visto pelo personal: o mesmo calendário e os mesmos gráficos que o aluno vê.
class StudentProgressPage extends ConsumerStatefulWidget {
  const StudentProgressPage({super.key, required this.studentId, this.initialTab = 0});

  final int studentId;

  /// 0 = Sessões, 1 = Evolução.
  final int initialTab;

  @override
  ConsumerState<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends ConsumerState<StudentProgressPage> {
  late int _tab = widget.initialTab.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(managedStudentProvider(widget.studentId)).value?.name;
    // os treinos do personal incluem os que o aluno já não tem (sessões antigas)
    final workoutNames = <int, String>{for (final w in ref.watch(trainerWorkoutsProvider).value ?? const <Workout>[]) w.id: w.name};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: LucideIcons.arrowLeft,
                    tooltip: 'Voltar',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HISTÓRICO', style: AppText.display(28)),
                        if (name != null)
                          Text(name, key: const Key('progress-student'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 0),
              child: HistorySegments(index: _tab, onChanged: (i) => setState(() => _tab = i)),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  SessionsTab(studentId: widget.studentId, workoutNames: workoutNames),
                  EvolutionPage(studentId: widget.studentId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
