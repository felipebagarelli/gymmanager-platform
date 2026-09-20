enum SubscriptionStatus { pending, active, pastDue, canceled }

SubscriptionStatus _statusFrom(String value) => switch (value) {
      'ACTIVE' => SubscriptionStatus.active,
      'PAST_DUE' => SubscriptionStatus.pastDue,
      'CANCELED' => SubscriptionStatus.canceled,
      _ => SubscriptionStatus.pending,
    };

class Plan {
  const Plan({required this.id, required this.name, required this.priceCents, this.description});

  final int id;
  final String name;
  final String? description;
  final int priceCents;

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String?,
        priceCents: (json['priceCents'] as num).toInt(),
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.status,
    required this.planName,
    required this.priceCents,
    this.currentPeriodEnd,
  });

  final int id;
  final SubscriptionStatus status;
  final String planName;
  final int priceCents;
  final DateTime? currentPeriodEnd;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: (json['id'] as num).toInt(),
        status: _statusFrom(json['status'] as String),
        planName: json['planName'] as String,
        priceCents: (json['priceCents'] as num).toInt(),
        currentPeriodEnd:
            json['currentPeriodEnd'] == null ? null : DateTime.parse(json['currentPeriodEnd'] as String),
      );
}

String formatPrice(int cents) {
  final reais = (cents ~/ 100).toString();
  final centavos = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $reais,$centavos';
}
