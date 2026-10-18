import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/features/billing/domain/billing.dart';
import 'package:gymmanager_mobile/features/hub/data/hub_repository.dart';

/// Hub em memória: dois personais disponíveis e o perfil público do personal logado.
class FakeHubRepository extends HubRepository {
  FakeHubRepository({List<TrainerCard>? trainers, PublicProfile? myProfile})
      : trainers = trainers ??
            const [
              TrainerCard(
                id: 5,
                displayName: 'João Personal',
                headline: 'Hipertrofia para iniciantes',
                city: 'São Paulo',
                state: 'SP',
                online: true,
                inPerson: false,
                specialties: [TrainerSpecialty.hypertrophy, TrainerSpecialty.beginners],
                fromPriceCents: 15000,
              ),
              TrainerCard(
                id: 6,
                displayName: 'Bia Treinos',
                headline: 'Emagrecimento com saúde',
                city: 'Campinas',
                state: 'SP',
                online: false,
                inPerson: true,
                specialties: [TrainerSpecialty.weightLoss],
                fromPriceCents: 9900,
              ),
            ],
        profile = myProfile ?? const PublicProfile(listed: false, missing: ['Ative "Aparecer no hub".', 'Escreva uma chamada curta.']),
        super(Dio());

  final List<TrainerCard> trainers;
  PublicProfile profile;
  final calls = <String>[];

  @override
  Future<List<TrainerCard>> search({String? query, TrainerSpecialty? specialty, bool onlineOnly = false}) async {
    calls.add('search:${query ?? ''}:${specialty?.api ?? ''}:$onlineOnly');
    final q = (query ?? '').toLowerCase();
    return [
      for (final t in trainers)
        if ((q.isEmpty || '${t.displayName} ${t.headline} ${t.city}'.toLowerCase().contains(q)) &&
            (specialty == null || t.specialties.contains(specialty)) &&
            (!onlineOnly || t.online))
          t,
    ];
  }

  @override
  Future<TrainerDetail> detail(int trainerId) async {
    final card = trainers.firstWhere((t) => t.id == trainerId);
    return TrainerDetail(
      card: card,
      bio: 'Formado em Educação Física, 8 anos de experiência.',
      plans: [Plan(id: trainerId * 10, name: 'Mensal', priceCents: card.fromPriceCents, description: '3 treinos por semana')],
    );
  }

  @override
  Future<String> hire(int trainerId, int planId) async {
    calls.add('hire:$trainerId:$planId');
    return 'https://checkout.stripe.test/hire';
  }

  @override
  Future<PublicProfile> myPublicProfile() async => profile;

  @override
  Future<PublicProfile> savePublicProfile(PublicProfile p) async {
    calls.add('save:${p.listed}:${p.headline}:${p.state}:${p.specialties.map((s) => s.api).join(',')}');
    final ready = p.listed && (p.headline ?? '').isNotEmpty;
    return profile = PublicProfile(
      listed: p.listed,
      headline: p.headline,
      bio: p.bio,
      city: p.city,
      state: p.state,
      online: p.online,
      inPerson: p.inPerson,
      specialties: p.specialties,
      visible: ready,
      missing: ready ? const [] : const ['Escreva uma chamada curta.'],
    );
  }
}
