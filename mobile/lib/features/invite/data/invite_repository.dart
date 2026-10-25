import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

/// O plano e o personal que quem recebeu o link vê (só dados públicos).
class InvitePreview {
  const InvitePreview({
    required this.code,
    required this.trainerName,
    required this.planName,
    required this.priceCents,
    this.headline,
    this.city,
    this.state,
    this.online = false,
    this.inPerson = false,
    this.planDescription,
    this.available = true,
  });

  final String code;
  final String trainerName;
  final String? headline;
  final String? city;
  final String? state;
  final bool online;
  final bool inPerson;
  final String planName;
  final String? planDescription;
  final int priceCents;

  /// O personal pode receber pagamentos agora.
  final bool available;

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
        code: json['code'] as String,
        trainerName: json['trainerName'] as String? ?? 'Personal',
        headline: json['headline'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        online: json['online'] as bool? ?? false,
        inPerson: json['inPerson'] as bool? ?? false,
        planName: json['planName'] as String? ?? 'Plano',
        planDescription: json['planDescription'] as String?,
        priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? false,
      );
}

/// Link para o personal compartilhar.
class InviteLink {
  const InviteLink({required this.code, required this.url});

  final String code;
  final String url;

  factory InviteLink.fromJson(Map<String, dynamic> json) =>
      InviteLink(code: json['code'] as String, url: json['url'] as String);
}

/// Link de convite do plano (F5).
class InviteRepository {
  InviteRepository(this._dio);

  final Dio _dio;

  /// Código como a pessoa digitou ou veio no link: sem espaços e em minúsculas.
  static String normalize(String code) => code.trim().toLowerCase();

  Future<InvitePreview> preview(String code) => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/invites/${Uri.encodeComponent(normalize(code))}');
        return InvitePreview.fromJson(response.data!);
      });

  /// Cria o vínculo pendente e devolve o endereço do checkout.
  Future<String> accept(String code) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/invites/${Uri.encodeComponent(normalize(code))}/accept');
        return response.data!['url'] as String;
      });

  // ---------- personal

  Future<InviteLink> link(int planId) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/plans/$planId/invite');
        return InviteLink.fromJson(response.data!);
      });

  /// Troca o código: o link antigo deixa de funcionar.
  Future<InviteLink> reset(int planId) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/plans/$planId/invite/reset');
        return InviteLink.fromJson(response.data!);
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
