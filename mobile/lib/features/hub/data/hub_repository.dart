import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../billing/domain/billing.dart';

/// Especialidades que o personal mostra no hub.
enum TrainerSpecialty {
  hypertrophy('HYPERTROPHY', 'Hipertrofia'),
  weightLoss('WEIGHT_LOSS', 'Emagrecimento'),
  strength('STRENGTH', 'Força'),
  conditioning('CONDITIONING', 'Condicionamento'),
  health('HEALTH', 'Saúde e bem-estar'),
  beginners('BEGINNERS', 'Iniciantes'),
  seniors('SENIORS', 'Terceira idade'),
  functional('FUNCTIONAL', 'Funcional');

  const TrainerSpecialty(this.api, this.label);

  final String api;
  final String label;

  static List<TrainerSpecialty> parse(List<dynamic>? values) => [
        for (final v in values ?? const [])
          for (final s in TrainerSpecialty.values)
            if (s.api == v) s,
      ];
}

/// "São Paulo/SP · Online e presencial".
String trainerPlace({String? city, String? state, required bool online, required bool inPerson}) {
  final place = [if ((city ?? '').isNotEmpty) city, if ((state ?? '').isNotEmpty) state].join('/');
  final mode = online && inPerson ? 'Online e presencial' : (online ? 'Online' : 'Presencial');
  return place.isEmpty ? mode : '$place · $mode';
}

class TrainerCard {
  const TrainerCard({
    required this.id,
    required this.displayName,
    this.headline,
    this.city,
    this.state,
    required this.online,
    required this.inPerson,
    this.specialties = const [],
    required this.fromPriceCents,
  });

  final int id;
  final String displayName;
  final String? headline;
  final String? city;
  final String? state;
  final bool online;
  final bool inPerson;
  final List<TrainerSpecialty> specialties;
  final int fromPriceCents;

  String get place => trainerPlace(city: city, state: state, online: online, inPerson: inPerson);

  factory TrainerCard.fromJson(Map<String, dynamic> json) => TrainerCard(
        id: (json['id'] as num).toInt(),
        displayName: json['displayName'] as String? ?? 'Personal',
        headline: json['headline'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        online: json['online'] as bool? ?? false,
        inPerson: json['inPerson'] as bool? ?? false,
        specialties: TrainerSpecialty.parse(json['specialties'] as List<dynamic>?),
        fromPriceCents: (json['fromPriceCents'] as num?)?.toInt() ?? 0,
      );
}

class TrainerDetail {
  const TrainerDetail({required this.card, this.bio, this.plans = const []});

  final TrainerCard card;
  final String? bio;
  final List<Plan> plans;

  factory TrainerDetail.fromJson(Map<String, dynamic> json) => TrainerDetail(
        card: TrainerCard.fromJson({...json, 'fromPriceCents': 0}),
        bio: json['bio'] as String?,
        plans: [for (final p in json['plans'] as List<dynamic>? ?? const []) Plan.fromJson(p as Map<String, dynamic>)],
      );
}

/// O perfil público do personal (o que ele edita) e o que falta para aparecer no hub.
class PublicProfile {
  const PublicProfile({
    required this.listed,
    this.headline,
    this.bio,
    this.city,
    this.state,
    this.online = true,
    this.inPerson = false,
    this.specialties = const [],
    this.visible = false,
    this.missing = const [],
  });

  final bool listed;
  final String? headline;
  final String? bio;
  final String? city;
  final String? state;
  final bool online;
  final bool inPerson;
  final List<TrainerSpecialty> specialties;
  final bool visible;
  final List<String> missing;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        listed: json['listed'] as bool? ?? false,
        headline: json['headline'] as String?,
        bio: json['bio'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        online: json['online'] as bool? ?? true,
        inPerson: json['inPerson'] as bool? ?? false,
        specialties: TrainerSpecialty.parse(json['specialties'] as List<dynamic>?),
        visible: json['visible'] as bool? ?? false,
        missing: [for (final m in json['missing'] as List<dynamic>? ?? const []) m as String],
      );

  Map<String, dynamic> toJson() => {
        'listed': listed,
        'headline': headline,
        'bio': bio,
        'city': city,
        'state': state,
        'online': online,
        'inPerson': inPerson,
        'specialties': [for (final s in specialties) s.api],
      };
}

/// Hub de personais: o aluno busca e contrata; o personal edita o próprio perfil público.
class HubRepository {
  HubRepository(this._dio);

  final Dio _dio;

  Future<List<TrainerCard>> search({String? query, TrainerSpecialty? specialty, bool onlineOnly = false}) => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/hub/trainers', queryParameters: {
          if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
          if (specialty != null) 'specialty': specialty.api,
          if (onlineOnly) 'online': true,
        });
        return [for (final t in response.data ?? const []) TrainerCard.fromJson(t as Map<String, dynamic>)];
      });

  Future<TrainerDetail> detail(int trainerId) => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/hub/trainers/$trainerId');
        return TrainerDetail.fromJson(response.data!);
      });

  /// Devolve o link do checkout do plano do personal. O vínculo só vale depois do pagamento.
  Future<String> hire(int trainerId, int planId) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/hub/trainers/$trainerId/hire', data: {'planId': planId});
        return response.data!['url'] as String;
      });

  Future<PublicProfile> myPublicProfile() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/trainers/me/public-profile');
        return PublicProfile.fromJson(response.data!);
      });

  Future<PublicProfile> savePublicProfile(PublicProfile profile) => _guard(() async {
        final response = await _dio.put<Map<String, dynamic>>('/api/v1/trainers/me/public-profile', data: profile.toJson());
        return PublicProfile.fromJson(response.data!);
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
