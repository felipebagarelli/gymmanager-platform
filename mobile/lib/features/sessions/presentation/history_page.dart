import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/application/home_tab_provider.dart';
import 'evolution_page.dart';
import 'history_sessions_tab.dart';

/// Histórico: abas "Sessões" (calendário e lista) e "Evolução" (cargas e volume).
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(historySubTabProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('HISTÓRICO', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 0),
            child: _Segments(index: tab, onChanged: ref.read(historySubTabProvider.notifier).select),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [SessionsTab(), EvolutionPage()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [('Sessões', LucideIcons.history), ('Evolução', LucideIcons.trendingUp)];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: _items[i].$1,
                excludeSemantics: true,
                child: GestureDetector(
                  key: Key('history-tab-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.elevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_items[i].$2, size: 17, color: i == index ? AppColors.volt : AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(_items[i].$1,
                            style: AppText.body(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: i == index ? AppColors.textPrimary : AppColors.textMuted,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
