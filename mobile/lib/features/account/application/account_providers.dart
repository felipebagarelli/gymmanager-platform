import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(dioProvider)));

/// Versão dos termos a aceitar no cadastro.
final legalInfoProvider = FutureProvider.autoDispose<LegalInfo>((ref) => ref.watch(accountRepositoryProvider).legal());

/// Idade completa em [today].
int ageOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
  return age;
}

/// O que o app passa entre as telas do cadastro (em memória, nunca na URL).
class AccountFlowArgs {
  const AccountFlowArgs({this.email, this.password, this.guardianEmail, this.resend = false});

  final String? email;

  /// Só no fluxo do cadastro: para entrar sozinho depois de confirmar o e-mail.
  final String? password;
  final String? guardianEmail;

  /// Veio do login com e-mail ainda não confirmado: pede um código novo ao abrir.
  final bool resend;
}
