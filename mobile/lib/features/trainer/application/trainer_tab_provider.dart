import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../home/presentation/app_tab_bar.dart';

/// Índices das abas do personal (mesma ordem de [trainerTabs]).
class TrainerTab {
  TrainerTab._();

  static const students = 0;
  static const workouts = 1;
  static const messages = 2;
  static const plans = 3;
  static const profile = 4;
}

/// As 5 abas do modo personal, na ordem da tab bar.
const trainerTabs = [
  TabSpec('Alunos', LucideIcons.users),
  TabSpec('Treinos', LucideIcons.dumbbell),
  TabSpec('Mensagens', LucideIcons.messageSquare),
  TabSpec('Planos', LucideIcons.wallet),
  TabSpec('Perfil', LucideIcons.user),
];

/// Aba selecionada no modo personal.
class TrainerTabController extends Notifier<int> {
  @override
  int build() => TrainerTab.students;

  void select(int index) => state = index;
}

final trainerTabProvider = NotifierProvider<TrainerTabController, int>(TrainerTabController.new);
