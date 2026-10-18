import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/hub_providers.dart';
import '../data/hub_repository.dart';

/// Personal: o perfil que os alunos veem no hub, e o que falta para aparecer.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myPublicProfileProvider);
    return Scaffold(
      body: SafeArea(
        child: profile.when(
          loading: () => const SkeletonList(heights: [56, 90, 60, 60]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(myPublicProfileProvider)),
          data: (p) => _Form(initial: p),
        ),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.initial});

  final PublicProfile initial;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late PublicProfile _saved = widget.initial;
  late bool _listed = widget.initial.listed;
  late bool _online = widget.initial.online;
  late bool _inPerson = widget.initial.inPerson;
  late final Set<TrainerSpecialty> _specialties = {...widget.initial.specialties};
  late final _headline = TextEditingController(text: widget.initial.headline ?? '');
  late final _bio = TextEditingController(text: widget.initial.bio ?? '');
  late final _city = TextEditingController(text: widget.initial.city ?? '');
  late final _state = TextEditingController(text: widget.initial.state ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_headline, _bio, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await runAction(context, () async {
      final saved = await ref.read(hubRepositoryProvider).savePublicProfile(PublicProfile(
            listed: _listed,
            headline: _headline.text.trim(),
            bio: _bio.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            online: _online,
            inPerson: _inPerson,
            specialties: [for (final s in TrainerSpecialty.values) if (_specialties.contains(s)) s],
          ));
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved.visible ? 'Perfil salvo. Você já aparece no hub.' : 'Perfil salvo.'),
      ));
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CircleIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Voltar',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        const SizedBox(height: 12),
        Text('PERFIL NO HUB', style: AppText.display(32)),
        Text('Como os alunos que procuram um personal veem você. E-mail e telefone nunca aparecem.',
            style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        if (_saved.visible)
          const InfoAlert(kind: AlertKind.good, icon: LucideIcons.circleCheck, text: 'Você aparece na busca de personais.')
        else
          AppCard(
            key: const Key('public-missing'),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Para aparecer na busca:', style: AppText.body(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final m in _saved.missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.circle, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m, style: AppText.body(size: 13.5, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SwitchListTile(
          key: const Key('public-listed'),
          contentPadding: EdgeInsets.zero,
          value: _listed,
          activeThumbColor: AppColors.volt,
          onChanged: (v) => setState(() => _listed = v),
          title: Text('Aparecer no hub', style: AppText.body(size: 15, weight: FontWeight.w600)),
          subtitle: Text('Alunos sem personal podem encontrar e contratar você pelo app.',
              style: AppText.body(size: 12.5, color: AppColors.textMuted)),
        ),
        TextField(
          key: const Key('public-headline'),
          controller: _headline,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Chamada', hintText: 'Ex.: Hipertrofia para iniciantes, online', counterText: ''),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('public-bio'),
          controller: _bio,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Sobre você', hintText: 'Formação, experiência, como você trabalha'),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                key: const Key('public-city'),
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('public-state'),
                controller: _state,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z]'))],
                decoration: const InputDecoration(labelText: 'UF', counterText: ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const LabelText('Atendimento'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(key: const Key('public-online'), label: const Text('Online'), selected: _online, onSelected: (v) => setState(() => _online = v)),
            FilterChip(
                key: const Key('public-in-person'), label: const Text('Presencial'), selected: _inPerson, onSelected: (v) => setState(() => _inPerson = v)),
          ],
        ),
        const SizedBox(height: 14),
        const LabelText('Especialidades'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in TrainerSpecialty.values)
              FilterChip(
                key: Key('public-specialty-${s.name}'),
                label: Text(s.label),
                selected: _specialties.contains(s),
                onSelected: (v) => setState(() => v ? _specialties.add(s) : _specialties.remove(s)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        PillButton(key: const Key('public-save'), label: _saving ? 'Salvando...' : 'Salvar perfil', onPressed: _saving ? null : _save),
      ],
    );
  }
}
