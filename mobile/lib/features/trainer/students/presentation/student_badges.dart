import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../domain/managed_student.dart';

/// Etiquetas de situação do aluno: inativo e mensalidade. Texto sempre presente (a cor só reforça).
List<Widget> studentBadges(ManagedStudent student, TuitionStatus? tuition) => [
      if (!student.active) const TagChip('Inativo', key: Key('badge-inactive')),
      if (tuition == TuitionStatus.overdue) const TagChip('Em atraso', key: Key('badge-overdue'), color: AppColors.ember),
      if (tuition == TuitionStatus.pending) const TagChip('Aguardando pagamento', key: Key('badge-pending'), color: AppColors.sky),
    ];
