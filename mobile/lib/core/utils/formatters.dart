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

const _weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "Sexta · 9 de outubro" (sem depender de inicialização de locale).
String formatLongDate(DateTime value) {
  final d = value.toLocal();
  return '${_weekdays[d.weekday - 1]} · ${d.day} de ${_months[d.month - 1]}';
}

/// "mm:ss" para cronômetros (passa de 59 min sem virar hora: "75:03").
String formatClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Número com vírgula decimal e sem casas desnecessárias: 17.5 -> "17,5"; 20.0 -> "20".
String formatNumber(double value) {
  final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  return text.replaceAll('.', ',');
}
