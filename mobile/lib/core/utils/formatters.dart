import 'package:intl/intl.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

String formatDuration(DateTime start, DateTime end) {
  final minutes = end.difference(start).inMinutes;
  return minutes < 1 ? 'menos de 1 min' : '$minutes min';
}

String formatLoad(double? kg) {
  if (kg == null) return '—';
  final text = kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  return '$text kg';
}

/// Aceita virgula ou ponto como separador decimal.
double? parseDecimal(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
