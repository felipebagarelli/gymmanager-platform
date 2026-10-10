import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Índices das abas principais (mesma ordem da tab bar).
class HomeTab {
  HomeTab._();

  static const workouts = 0;
  static const history = 1;
  static const messages = 2;
  static const assistant = 3;
  static const profile = 4;
}

/// Aba selecionada na home. Fica num provider para que telas de fora do menu
/// (ex.: "Treino concluído" -> "Ver evolução") consigam levar o aluno a uma aba.
class HomeTabController extends Notifier<int> {
  @override
  int build() => HomeTab.workouts;

  void select(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);

/// Sub-aba do Histórico: 0 = Sessões, 1 = Evolução.
class HistorySubTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final historySubTabProvider = NotifierProvider<HistorySubTabController, int>(HistorySubTabController.new);
