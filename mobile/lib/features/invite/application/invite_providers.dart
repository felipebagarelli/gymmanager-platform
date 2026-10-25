import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../data/invite_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) => InviteRepository(ref.watch(dioProvider)));

final invitePreviewProvider = FutureProvider.autoDispose.family<InvitePreview, String>(
  (ref, code) => ref.watch(inviteRepositoryProvider).preview(code),
);

/// Abre o compartilhamento do celular (WhatsApp, Instagram...). Sobrescrevível em testes.
final shareTextProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  },
);

/// Convite aberto por quem ainda não tinha entrado: o app mostra depois do login ou do cadastro.
class PendingInvite extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final pendingInviteProvider = NotifierProvider<PendingInvite, String?>(PendingInvite.new);
