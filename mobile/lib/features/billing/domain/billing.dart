enum SubscriptionStatus { pending, active, pastDue, canceled }

SubscriptionStatus _statusFrom(String value) => switch (value) {
      'ACTIVE' => SubscriptionStatus.active,
      'PAST_DUE' => SubscriptionStatus.pastDue,
      'CANCELED' => SubscriptionStatus.canceled,
      _ => SubscriptionStatus.pending,
    };

class Plan {
  const Plan({required this.id, required this.name, required this.priceCents, this.description, this.active = true});

  final int id;
  final String name;
  final String? description;
  final int priceCents;

  /// Plano desativado não aparece para novos alunos (as assinaturas existentes continuam).
  final bool active;

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String?,
        priceCents: (json['priceCents'] as num).toInt(),
        active: json['active'] as bool? ?? true,
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.status,
    required this.planName,
    required this.priceCents,
    this.currentPeriodEnd,
    this.planId,
    this.studentId,
    this.studentName,
  });

  final int id;
  final SubscriptionStatus status;
  final String planName;
  final int priceCents;
  final DateTime? currentPeriodEnd;

  /// Preenchidos na visão do personal (lista de assinaturas dos alunos).
  final int? planId;
  final int? studentId;
  final String? studentName;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: (json['id'] as num).toInt(),
        status: _statusFrom(json['status'] as String),
        planName: json['planName'] as String,
        priceCents: (json['priceCents'] as num).toInt(),
        currentPeriodEnd:
            json['currentPeriodEnd'] == null ? null : DateTime.parse(json['currentPeriodEnd'] as String),
        planId: (json['planId'] as num?)?.toInt(),
        studentId: (json['studentId'] as num?)?.toInt(),
        studentName: json['studentName'] as String?,
      );
}

/// "R\$ 1.250,00" (centavos de real).
String formatPrice(int cents) {
  final digits = (cents ~/ 100).toString();
  final reais = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final centavos = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $reais,$centavos';
}

/// Lê um valor em reais digitado ("120", "120,50", "1.250,00", "R\$ 99,9") em centavos; null se inválido.
int? parsePriceCents(String text) {
  var t = text.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // "1.250" = mil duzentos e cinquenta
  }
  final value = double.tryParse(t);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}
