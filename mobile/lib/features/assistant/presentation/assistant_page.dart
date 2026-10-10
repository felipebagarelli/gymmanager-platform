import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/composer_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../../chat/application/chat_providers.dart';
import '../application/assistant_providers.dart';
import '../domain/assistant.dart';
import 'equipment_answer.dart';

const assistantDisclaimer = 'O Personal IA é uma IA e não substitui seu personal nem orientação médica.';

/// Texto da fala do aluno quando ele envia só a foto, sem pergunta.
const _photoOnlyLabel = 'Foto do aparelho';

const _suggestions = ['Como faço o agachamento?', 'Quanto descanso entre as séries?', 'Como aquecer antes do treino?'];

/// Personal IA: perguntas sobre treino e foto do aparelho. Somente leitura; conversa privada do aluno.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _asking = false;
  bool _menuOpen = false;
  bool _unavailable = false;
  String? _pendingQuestion;
  PickedPhoto? _pendingPhoto;
  PickedPhoto? _attachment;
  final _notified = <int>{};
  int _lastCount = -1;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageOf(error))));
  }

  Future<void> _submit([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    final photo = suggestion == null ? _attachment : null;
    if ((text.isEmpty && photo == null) || _asking) return;
    setState(() {
      _asking = true;
      _menuOpen = false;
      _unavailable = false;
      _pendingQuestion = text.isEmpty ? null : text;
      _pendingPhoto = photo;
    });
    _scrollToEnd();
    try {
      final controller = ref.read(assistantControllerProvider.notifier);
      if (photo != null) {
        await controller.askWithPhoto(photo, question: text);
      } else {
        await controller.ask(text);
      }
      if (suggestion == null) _controller.clear();
      // a sugestão envia só texto: a foto anexada (ainda não enviada) fica para o aluno
      if (photo != null) _attachment = null;
    } catch (error) {
      if (error is AppException && error.statusCode == 503) {
        if (mounted) setState(() => _unavailable = true);
      } else if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _pendingQuestion = null;
          _pendingPhoto = null;
        });
        _scrollToEnd();
      }
    }
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() => _menuOpen = false);
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo != null && mounted) setState(() => _attachment = photo);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _notifyTrainer(AiMessage answer, String trainerName) async {
    final conversation = ref.read(chatSummaryProvider).value;
    final equipment = answer.equipment;
    if (conversation == null || equipment == null) return;
    try {
      await ref.read(chatRepositoryProvider).send(
            conversation.id,
            'Oi! Tirei uma foto do aparelho "${equipment.name}" e ele não está no meu treino. '
            'Pode incluir ou me explicar como usar?',
          );
      ref.invalidate(chatSummaryProvider);
      if (!mounted) return;
      setState(() => _notified.add(answer.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aviso enviado para $trainerName')));
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(assistantControllerProvider);
    final usage = ref.watch(assistantUsageProvider).value;
    final trainerName = ref.watch(chatSummaryProvider).value?.trainerName;
    final outOfQuota = usage != null && usage.remainingToday <= 0;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _Header(),
          Expanded(
            child: history.when(
              loading: () => const SkeletonList(heights: [60, 120, 60]),
              error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(assistantControllerProvider)),
              data: (items) {
                final total = items.length + (_pendingQuestion != null || _pendingPhoto != null ? 1 : 0) + (_asking ? 1 : 0);
                if (total != _lastCount) {
                  _lastCount = total;
                  _scrollToEnd();
                }
                if (total == 0) return _EmptyState(enabled: !outOfQuota, onSuggestion: _submit, onPhoto: () => setState(() => _menuOpen = true));
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 12),
                  children: [
                    for (final message in items)
                      message.role == AiRole.user
                          ? _UserBubble(text: message.body, photo: message.isPhoto)
                          : _AssistantBubble(
                              message: message,
                              trainerName: trainerName,
                              notified: _notified.contains(message.id),
                              onNotify: trainerName == null ? null : () => _notifyTrainer(message, trainerName),
                            ),
                    if (_pendingQuestion != null || _pendingPhoto != null)
                      _UserBubble(text: _pendingQuestion ?? _photoOnlyLabel, photo: _pendingPhoto != null, thumbnail: _pendingPhoto),
                    if (_asking) _Typing(photo: _pendingPhoto != null),
                  ],
                );
              },
            ),
          ),
          if (_unavailable)
            const Padding(
              padding: EdgeInsets.fromLTRB(kScreenPadding, 0, kScreenPadding, 8),
              child: InfoAlert(
                key: Key('assistant-unavailable'),
                kind: AlertKind.warn,
                icon: LucideIcons.triangleAlert,
                text: 'Personal IA indisponível no momento. Tente novamente mais tarde.',
              ),
            ),
          if (usage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                outOfQuota
                    ? 'Você atingiu o limite de ${usage.dailyLimit} perguntas hoje.'
                    : '${usage.remainingToday} de ${usage.dailyLimit} perguntas restantes hoje',
                key: const Key('assistant-usage'),
                style: AppText.body(size: 12, color: AppColors.textMuted),
              ),
            ),
          if (_menuOpen)
            _PlusMenu(onCamera: () => _pick(PhotoSource.camera), onGallery: () => _pick(PhotoSource.gallery)),
          if (_attachment != null)
            _AttachmentPreview(photo: _attachment!, onRemove: () => setState(() => _attachment = null)),
          _Composer(
            controller: _controller,
            hasAttachment: _attachment != null,
            busy: _asking,
            outOfQuota: outOfQuota,
            onPlus: () => setState(() => _menuOpen = !_menuOpen),
            onSend: _submit,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PERSONAL IA', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
                    Text('Usa seus treinos e fotos dos aparelhos', style: AppText.body(size: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.zap, size: 13, color: AppColors.volt),
                    const SizedBox(width: 4),
                    Text('IA', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.volt)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('assistant-disclaimer'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(assistantDisclaimer, style: AppText.body(size: 12.5, color: AppColors.textSecondary))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.enabled, required this.onSuggestion, required this.onPhoto});

  final bool enabled;
  final void Function([String? suggestion]) onSuggestion;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding + 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(16)),
              child: const Icon(LucideIcons.camera, size: 28, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Tire uma foto do aparelho na academia e eu explico como usar.\nOu pergunte: “Como faço o agachamento?”',
              key: const Key('assistant-empty'),
              textAlign: TextAlign.center,
              style: AppText.body(size: 14.5, color: AppColors.textSecondary).copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(key: const Key('suggestion-photo'), label: 'Foto do aparelho', icon: LucideIcons.camera, onTap: enabled ? onPhoto : null),
                for (var i = 0; i < _suggestions.length; i++)
                  _SuggestionChip(key: Key('suggestion-$i'), label: _suggestions[i], onTap: enabled ? () => onSuggestion(_suggestions[i]) : null),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: AppColors.volt), const SizedBox(width: 6)],
              Flexible(child: Text(label, style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.photo, this.thumbnail});

  final String text;
  final bool photo;
  final PickedPhoto? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
        decoration: const BoxDecoration(
          color: AppColors.volt,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thumbnail != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    thumbnail!.bytes,
                    key: const Key('pending-photo'),
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _BrokenPreview(width: 160, height: 120),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photo) ...[const Icon(LucideIcons.camera, size: 16, color: AppColors.onVolt), const SizedBox(width: 6)],
                Flexible(child: SelectableText(text, style: AppText.body(size: 14.5, weight: FontWeight.w500, color: AppColors.onVolt))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message, required this.trainerName, required this.notified, required this.onNotify});

  final AiMessage message;
  final String? trainerName;
  final bool notified;
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    final equipment = message.equipment;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (equipment == null ? 0.84 : 0.94)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: equipment != null
            ? EquipmentAnswer(
                messageId: message.id,
                analysis: equipment,
                trainerName: trainerName,
                notified: notified,
                onNotifyTrainer: onNotify,
              )
            : SelectableText(message.body, style: AppText.body(size: 14.5).copyWith(height: 1.4)),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.photo});

  final bool photo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('assistant-typing'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.volt)),
            const SizedBox(width: 10),
            Text(photo ? 'Analisando a foto…' : 'Pensando…', style: AppText.body(size: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PlusMenu extends StatelessWidget {
  const _PlusMenu({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 0, kScreenPadding, 8),
      child: AppCard(
        key: const Key('plus-menu'),
        radius: 16,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _MenuItem(key: const Key('pick-camera'), icon: LucideIcons.camera, label: 'Tirar foto', onTap: onCamera),
            const Divider(height: 1, color: AppColors.borderSubtle),
            _MenuItem(key: const Key('pick-gallery'), icon: LucideIcons.image, label: 'Escolher da galeria', onTap: onGallery),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: AppText.body(size: 15.5, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.photo, required this.onRemove});

  final PickedPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 0, kScreenPadding, 8),
      child: Row(
        key: const Key('attachment-preview'),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              photo.bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _BrokenPreview(width: 56, height: 56),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Foto do aparelho pronta para enviar', style: AppText.body(size: 13.5, color: AppColors.textSecondary))),
          Semantics(
            button: true,
            label: 'Remover foto',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('attachment-remove'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hasAttachment,
    required this.busy,
    required this.outOfQuota,
    required this.onPlus,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasAttachment;
  final bool busy;
  final bool outOfQuota;
  final VoidCallback onPlus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 0, kScreenPadding, 14),
      child: Row(
        children: [
          Semantics(
            button: true,
            enabled: !busy && !outOfQuota,
            label: 'Anexar foto',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('assistant-plus'),
              onTap: busy || outOfQuota ? null : onPlus,
              child: Opacity(
                opacity: busy || outOfQuota ? 0.4 : 1,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: const Icon(LucideIcons.plus, size: 22, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillTextField(
              key: const Key('assistant-input'),
              controller: controller,
              enabled: !outOfQuota,
              hint: hasAttachment ? 'Pergunte sobre a foto (opcional)' : 'Pergunte ao Personal IA',
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SendButton(
              key: const Key('assistant-send'),
              enabled: !busy && !outOfQuota && (controller.text.trim().isNotEmpty || hasAttachment),
              onTap: onSend,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostrado se o aparelho não conseguir decodificar a prévia (a foto ainda é enviada normalmente).
class _BrokenPreview extends StatelessWidget {
  const _BrokenPreview({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.elevated,
      child: const Icon(LucideIcons.image, size: 22, color: AppColors.textMuted),
    );
  }
}
