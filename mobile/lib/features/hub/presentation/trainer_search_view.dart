import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../billing/domain/billing.dart';
import '../../invite/presentation/invite_page.dart';
import '../application/hub_providers.dart';
import '../data/hub_repository.dart';

typedef HubQuery = ({String text, TrainerSpecialty? specialty, bool onlineOnly});

final hubSearchProvider = FutureProvider.autoDispose.family<List<TrainerCard>, HubQuery>(
  (ref, q) => ref.watch(hubRepositoryProvider).search(query: q.text, specialty: q.specialty, onlineOnly: q.onlineOnly),
);

/// Aluno sem personal: encontrar um personal (aba Mensagens). Busca por texto, especialidade e online.
class TrainerSearchView extends ConsumerStatefulWidget {
  const TrainerSearchView({super.key});

  @override
  ConsumerState<TrainerSearchView> createState() => _TrainerSearchViewState();
}

class _TrainerSearchViewState extends ConsumerState<TrainerSearchView> {
  final _search = TextEditingController();
  HubQuery _query = (text: '', specialty: null, onlineOnly: false);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set({String? text, TrainerSpecialty? specialty, bool clearSpecialty = false, bool? onlineOnly}) {
    setState(() => _query = (
          text: text ?? _query.text,
          specialty: clearSpecialty ? null : (specialty ?? _query.specialty),
          onlineOnly: onlineOnly ?? _query.onlineOnly,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(hubSearchProvider(_query));
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(hubSearchProvider(_query).future),
        child: ListView(
          key: const Key('find-trainer'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
          children: [
            Text('ENCONTRE UM PERSONAL', style: AppText.display(32).copyWith(letterSpacing: 0.5)),
            Text('Treine com acompanhamento: treinos montados por um profissional e conversa direta pelo app.',
                style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('enter-invite-code'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(LucideIcons.ticket, size: 18),
                label: const Text('Tenho um código de convite'),
                onPressed: () => enterInviteCode(context),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('hub-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _set(text: v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, cidade ou objetivo',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  onPressed: () => _set(text: _search.text),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    key: const Key('hub-online'),
                    label: const Text('Online'),
                    selected: _query.onlineOnly,
                    onSelected: (v) => _set(onlineOnly: v),
                  ),
                  const SizedBox(width: 6),
                  for (final s in TrainerSpecialty.values) ...[
                    ChoiceChip(
                      key: Key('hub-specialty-${s.name}'),
                      label: Text(s.label),
                      selected: _query.specialty == s,
                      onSelected: (v) => v ? _set(specialty: s) : _set(clearSpecialty: true),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            results.when(
              // dentro do ListView da página: blocos simples (outra lista aqui não teria altura)
              loading: () => const Column(children: [
                SkeletonBox(height: 96),
                SizedBox(height: 10),
                SkeletonBox(height: 96),
              ]),
              error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(hubSearchProvider(_query))),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: LucideIcons.users,
                        message: _query.text.isEmpty && _query.specialty == null && !_query.onlineOnly
                            ? 'Ainda não há personais disponíveis no app.\nVolte em breve!'
                            : 'Nenhum personal encontrado com esses filtros.',
                      ),
                    )
                  : Column(children: [for (final t in items) _TrainerTile(trainer: t)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerTile extends StatelessWidget {
  const _TrainerTile({required this.trainer});

  final TrainerCard trainer;

  @override
  Widget build(BuildContext context) {
    final t = trainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('hub-trainer-${t.id}'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/hub/trainers/${t.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(name: t.displayName, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.displayName, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  if ((t.headline ?? '').isNotEmpty) Text(t.headline!, style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                  Text(t.place, style: AppText.body(size: 12.5, color: AppColors.textMuted)),
                  if (t.fromPriceCents > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('A partir de ${formatPrice(t.fromPriceCents)}/mês',
                          style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.volt)),
                    ),
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
