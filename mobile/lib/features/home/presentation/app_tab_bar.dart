import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

class TabSpec {
  const TabSpec(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// As 5 abas principais, na ordem da tab bar.
const appTabs = [
  TabSpec('Treinos', LucideIcons.dumbbell),
  TabSpec('Histórico', LucideIcons.history),
  TabSpec('Mensagens', LucideIcons.messageSquare),
  TabSpec('Personal IA', LucideIcons.zap),
  TabSpec('Perfil', LucideIcons.user),
];

/// Tab bar do app: indicador volt no topo da aba ativa, ícone + rótulo.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onSelected, this.unreadMessages = 0});

  final int index;
  final ValueChanged<int> onSelected;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              for (var i = 0; i < appTabs.length; i++)
                Expanded(
                  child: _TabItem(
                    spec: appTabs[i],
                    selected: i == index,
                    badge: i == 2 ? unreadMessages : 0,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.spec, required this.selected, required this.badge, required this.onTap});

  final TabSpec spec;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.volt : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '${spec.label}, $badge não lidas' : spec.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // barra indicadora colada no topo da aba ativa
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AppColors.volt : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
            const SizedBox(height: 10),
            Badge(
              isLabelVisible: badge > 0,
              backgroundColor: AppColors.ember,
              textColor: AppColors.onVolt,
              label: Text('$badge', key: const Key('chat-unread')),
              child: Icon(spec.icon, size: 24, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 11, weight: selected ? FontWeight.w600 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
