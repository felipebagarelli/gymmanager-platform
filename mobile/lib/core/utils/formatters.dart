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

/// Cronômetro: "mm:ss" e, a partir de 1 hora, "h:mm:ss" (ex.: "1:15:03").
String formatClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  if (s >= 3600) return '${s ~/ 3600}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

/// Número com vírgula decimal e sem casas desnecessárias: 17.5 -> "17,5"; 20.0 -> "20".
String formatNumber(double value) {
  final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  return text.replaceAll('.', ',');
}

/// "240 kg" ou, a partir de 1000 kg, "1,2 t".
String formatVolume(double kg) {
  if (kg >= 1000) return '${formatNumber((kg / 100).round() / 10)} t';
  return '${formatNumber((kg * 10).round() / 10)} kg';
}

/// "Outubro 2026".
String formatMonthYear(DateTime value) {
  final d = value.toLocal();
  final name = _months[d.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} ${d.year}';
}

/// "OUT" (3 letras, caixa alta).
String formatShortMonth(DateTime value) => _months[value.toLocal().month - 1].substring(0, 3).toUpperCase();

/// "10/10"
String formatDayMonth(DateTime value) {
  final d = value.toLocal();
  return '${d.day}/${d.month}';
}

/// "05/10" (dia e mês com dois dígitos).
String formatDayMonthPadded(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// "10 out" (dia com dois dígitos e mês abreviado em minúsculas).
String formatShortDate(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${formatShortMonth(d).toLowerCase()}';
}
