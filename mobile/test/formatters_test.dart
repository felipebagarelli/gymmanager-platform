import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/utils/formatters.dart';

void main() {
  test('formatDayMonthPadded: dia e mês com dois dígitos', () {
    expect(formatDayMonthPadded(DateTime(2026, 10, 5)), '05/10');
    expect(formatDayMonthPadded(DateTime(2026, 11, 15)), '15/11');
    expect(formatDayMonthPadded(DateTime(2026, 3, 1)), '01/03');
  });

  test('formatDayMonth (sem zero à esquerda) segue disponível para os gráficos', () {
    expect(formatDayMonth(DateTime(2026, 10, 5)), '5/10');
  });

  test('formatShortDate: dia com dois dígitos e mês abreviado em minúsculas', () {
    expect(formatShortDate(DateTime(2026, 10, 9)), '09 out');
    expect(formatShortDate(DateTime(2026, 3, 21)), '21 mar');
    expect(formatShortDate(DateTime(2026, 5, 2)), '02 mai');
  });

  test('formatShortMonth e formatMonthYear', () {
    expect(formatShortMonth(DateTime(2026, 10, 9)), 'OUT');
    expect(formatMonthYear(DateTime(2026, 10, 9)), 'Outubro 2026');
  });

  test('formatVolume: kg até 1000, depois toneladas com uma casa', () {
    expect(formatVolume(240), '240 kg');
    expect(formatVolume(1400), '1,4 t');
    expect(formatVolume(999.96), '1000 kg');
  });
}
