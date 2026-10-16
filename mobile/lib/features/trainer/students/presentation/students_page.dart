import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton.dart';
import '../application/students_providers.dart';
import '../domain/managed_student.dart';
import 'student_badges.dart';

enum _Filter {
  all('Todos'),
  active('Ativos'),
  overdue('Em atraso'),
  paused('Em pausa'),
  inactive('Inativos');

  const _Filter(this.label);

  final String label;
}

/// Aba "Alunos" do personal: busca, filtros por situação e acesso ao perfil de cada aluno.
class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ManagedStudent s, Map<int, TuitionStatus> tuition) {
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty && !s.name.toLowerCase().contains(query) && !s.email.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      _Filter.all => true,
      _Filter.active => s.active && !s.paused,
      _Filter.paused => s.active && s.paused,
      _Filter.inactive => !s.active,
      _Filter.overdue => tuition[s.id] == TuitionStatus.overdue,
    };
  }

  Future<void> _refresh() async {
    ref.invalidate(trainerStudentsProvider);
    ref.invalidate(tuitionByStudentProvider);
    await ref.read(trainerStudentsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(trainerStudentsProvider);
    final tuition = ref.watch(tuitionByStudentProvider).value ?? const <int, TuitionStatus>{};
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: students.when(
        loading: () => const SkeletonList(heights: [56, 44, 72, 72, 72]),
        error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerStudentsProvider)),
        data: (items) {
          final visible = [for (final s in items) if (_matches(s, tuition)) s];
          final activeCount = items.where((s) => s.active).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALUNOS', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
                          Text(activeCount == 1 ? '1 aluno ativo' : '$activeCount alunos ativos',
                              key: const Key('students-count'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Cadastrar aluno',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const Key('new-student'),
                        onTap: () => context.push('/trainer/students/new'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(gradient: AppColors.ctaGradient, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.userPlus, size: 22, color: AppColors.onVolt),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (items.isNotEmpty) ...[
                  TextField(
                    key: const Key('students-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: AppText.body(size: 15),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou e-mail',
                      hintStyle: AppText.body(size: 15, color: AppColors.textMuted),
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.volt)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final filter in _Filter.values) ...[
                          _FilterChip(
                            key: Key('filter-${filter.name}'),
                            label: filter.label,
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyState(
                      icon: LucideIcons.users,
                      message: 'Você ainda não tem alunos.\nToque em + para cadastrar o primeiro.',
                    ),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Nenhum aluno encontrado.', key: const Key('students-none'), style: AppText.body(color: AppColors.textMuted)),
                    ),
                  )
                else
                  for (final student in visible) _StudentTile(student: student, tuition: tuition[student.id], now: now),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.volt.withValues(alpha: 0.14) : AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? AppColors.volt : AppColors.borderSubtle),
          ),
          child: Text(label,
              style: AppText.body(size: 14, weight: FontWeight.w600, color: selected ? AppColors.volt : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.tuition, required this.now});

  final ManagedStudent student;
  final TuitionStatus? tuition;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final last = student.lastWorkoutAt;
    final badges = studentBadges(student, tuition);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('student-${student.id}'),
        radius: 18,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/trainer/students/${student.id}'),
        child: Row(
          children: [
            Opacity(opacity: student.active ? 1 : 0.5, child: InitialsAvatar(name: student.name, size: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(last == null ? 'Ainda não treinou' : 'Último treino: ${formatSince(last, now)}',
                      style: AppText.body(size: 13, color: AppColors.textMuted)),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
