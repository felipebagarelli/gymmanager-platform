import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/theme/app_colors.dart';
import 'package:gymmanager_mobile/core/widgets/progress_ring.dart';
import 'package:gymmanager_mobile/features/home/presentation/app_tab_bar.dart';

void main() {
  group('muscleGroupColor', () {
    test('grupos do protótipo', () {
      expect(muscleGroupColor('Peito'), AppColors.volt);
      expect(muscleGroupColor('Pernas'), AppColors.sky);
      expect(muscleGroupColor('Costas'), AppColors.ember);
    });

    test('outros grupos seguem a regra documentada e ignoram maiúsculas', () {
      expect(muscleGroupColor('OMBROS'), AppColors.volt);
      expect(muscleGroupColor('Glúteos'), AppColors.sky);
      expect(muscleGroupColor('Bíceps'), AppColors.ember);
    });

    test('desconhecido ou vazio fica neutro', () {
      expect(muscleGroupColor('Abdômen'), AppColors.textSecondary);
      expect(muscleGroupColor(null), AppColors.textSecondary);
    });
  });

  group('AppTabBar', () {
    Widget app({int index = 0, int unread = 0, ValueChanged<int>? onSelected}) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppTabBar(index: index, unreadMessages: unread, onSelected: onSelected ?? (_) {}),
          ),
        );

    testWidgets('mostra as 5 abas, com Personal IA no lugar de Assistente', (tester) async {
      await tester.pumpWidget(app());
      for (final label in ['Treinos', 'Histórico', 'Mensagens', 'Personal IA', 'Perfil']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Assistente'), findsNothing);
    });

    testWidgets('toque troca de aba e contador aparece só com não lidas', (tester) async {
      int? selected;
      await tester.pumpWidget(app(unread: 3, onSelected: (i) => selected = i));
      expect(find.byKey(const Key('chat-unread')), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      expect(selected, 4);
    });

    testWidgets('sem não lidas, o contador some', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byKey(const Key('chat-unread')), findsNothing);
    });
  });

  testWidgets('ProgressRing limita o valor e expõe porcentagem para leitores de tela', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProgressRing(value: 1.7, semanticsLabel: 'Supino'))));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Supino'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Supino')).value, '100%');
    handle.dispose();
  });
}
