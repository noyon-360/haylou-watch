import 'package:flutter_test/flutter_test.dart';
import 'package:watch/theme/season.dart';

void main() {
  Season s(int y, int m, int d) => BengaliCalendar.seasonOf(DateTime(y, m, d));

  group('Bengali calendar (Bangladesh, revised 2019)', () {
    test('season boundaries', () {
      expect(s(2026, 4, 13), Season.basanta); // 30 Choitro
      expect(s(2026, 4, 14), Season.grishma); // 1 Boishakh (Pohela Boishakh)
      expect(s(2026, 6, 14), Season.grishma);
      expect(s(2026, 6, 15), Season.barsha); // 1 Asharh
      expect(s(2026, 8, 15), Season.barsha);
      expect(s(2026, 8, 16), Season.sharat); // 1 Bhadro
      expect(s(2026, 10, 16), Season.sharat);
      expect(s(2026, 10, 17), Season.hemanta); // 1 Kartik
      expect(s(2026, 12, 15), Season.hemanta);
      expect(s(2026, 12, 16), Season.sheet); // 1 Poush
      expect(s(2027, 2, 13), Season.sheet);
      expect(s(2027, 2, 14), Season.basanta); // 1 Falgun (Pohela Falgun)
    });

    test('known month starts', () {
      final ogrohayon = BengaliCalendar.monthOf(DateTime(2026, 11, 16));
      expect((ogrohayon.month, ogrohayon.day), (7, 0)); // 1 Ogrohayon
      final choitro = BengaliCalendar.monthOf(DateTime(2027, 3, 15));
      expect((choitro.month, choitro.day), (11, 0)); // 1 Choitro (Falgun 29 days)
      // Leap year: Feb has 29 days and Falgun 30, so 1 Choitro is still 15 March.
      final falgun30 = BengaliCalendar.monthOf(DateTime(2028, 3, 14));
      expect((falgun30.month, falgun30.day), (10, 29));
      final choitroLeap = BengaliCalendar.monthOf(DateTime(2028, 3, 15));
      expect((choitroLeap.month, choitroLeap.day), (11, 0));
    });

    test('today (2026-11-20) is Hemanta, next change 16 Dec', () {
      expect(s(2026, 11, 20), Season.hemanta);
      expect(BengaliCalendar.nextSeasonStart(DateTime(2026, 11, 20)), DateTime(2026, 12, 16));
    });

    test('next season wraps to the new year', () {
      expect(BengaliCalendar.nextSeasonStart(DateTime(2027, 3, 1)), DateTime(2027, 4, 14));
      expect(Season.basanta.next, Season.grishma);
    });

    test('every day of a year maps to a season in order', () {
      var prev = s(2026, 4, 14);
      var changes = 0;
      for (var d = DateTime(2026, 4, 15); d.isBefore(DateTime(2027, 4, 14)); d = DateTime(d.year, d.month, d.day + 1)) {
        final cur = BengaliCalendar.seasonOf(d);
        if (cur != prev) {
          expect(cur, prev.next);
          changes++;
          prev = cur;
        }
      }
      expect(changes, 5);
    });
  });
}
