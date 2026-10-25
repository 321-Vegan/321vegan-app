import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/helpers/osm_opening_hours.dart';

/// Slots as "day open-close" strings, sorted, for readable expectations.
List<String>? parse(String value) {
  final slots = parseOsmOpeningHours(value);
  if (slots == null) return null;
  return (slots.map((s) => '${s.day} ${s.open}-${s.close}').toList()..sort());
}

void main() {
  group('parseOsmOpeningHours', () {
    test('day range with lunch and dinner', () {
      expect(
          parse('Mo-Fr 12:00-14:30,19:00-22:30'),
          [
            for (var d = 0; d < 5; d++) ...['$d 12:00-14:30', '$d 19:00-22:30'],
          ]..sort());
    });

    test('several rules, day lists', () {
      expect(parse('Tu,Th 09:00-18:00; Sa 10:00-12:00'),
          ['1 09:00-18:00', '3 09:00-18:00', '5 10:00-12:00']);
    });

    test('a later rule replaces the earlier one for its days', () {
      expect(parse('Mo-Sa 10:00-19:00; We off'), [
        '0 10:00-19:00',
        '1 10:00-19:00',
        '3 10:00-19:00',
        '4 10:00-19:00',
        '5 10:00-19:00',
      ]);
    });

    test('no day spec means every day', () {
      expect(parse('08:00-20:00')!.length, 7);
    });

    test('range wrapping around the week', () {
      expect(parse('Fr-Mo 18:00-23:00'),
          ['0 18:00-23:00', '4 18:00-23:00', '5 18:00-23:00', '6 18:00-23:00']);
    });

    test('past midnight and 24:00', () {
      expect(parse('Fr,Sa 19:00-02:00'), ['4 19:00-02:00', '5 19:00-02:00']);
      expect(parse('Su 18:00-24:00'), ['6 18:00-00:00']);
    });

    test('real value from OSM (Le Kitchen, Lyon)', () {
      expect(parse('Sa,Su 08:30-18:30; Mo,Fr 08:00-18:30; Tu-Th off'), [
        '0 08:00-18:30',
        '4 08:00-18:30',
        '5 08:30-18:30',
        '6 08:30-18:30',
      ]);
    });

    test('single digit hours', () {
      expect(parse('Mo 9:30-12:00'), ['0 09:30-12:00']);
    });

    test('unsupported forms give nothing rather than a wrong schedule', () {
      for (final value in [
        '24/7',
        'Mo-Fr 12:00-14:00; PH off',
        'Jan-Mar Mo-Fr 10:00-18:00',
        'Mo-Fr 18:00+',
        'Mo-Fr 10:00-18:00 "sur rendez-vous"',
        'sunrise-sunset',
        'Mo 10:00-10:00',
        '',
      ]) {
        expect(parseOsmOpeningHours(value), isNull, reason: value);
      }
    });

    test('overlapping slots give nothing', () {
      expect(parse('Mo 10:00-15:00,14:00-18:00'), isNull);
    });
  });
}
