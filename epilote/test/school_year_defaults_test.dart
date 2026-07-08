import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/providers/school_year_defaults.dart';

void main() {
  group('defaultSchoolYearStart', () {
    test('juin ou après → année civile courante', () {
      expect(defaultSchoolYearStart(DateTime(2026, 7, 8)), 2026);
      expect(defaultSchoolYearStart(DateTime(2026, 6, 1)), 2026);
      expect(defaultSchoolYearStart(DateTime(2026, 10, 15)), 2026);
    });
    test('avant juin → année précédente', () {
      expect(defaultSchoolYearStart(DateTime(2026, 2, 20)), 2025);
      expect(defaultSchoolYearStart(DateTime(2026, 5, 31)), 2025);
    });
  });

  test('schoolYearLabel → « AAAA-AAAA »', () {
    expect(schoolYearLabel(2026), '2026-2027');
    expect(schoolYearLabel(2030), '2030-2031');
  });

  group('schoolYearStartDate = 1er lundi d\'octobre', () {
    test('2026 : 1er oct = jeudi → 1er lundi = 5 oct', () {
      final d = schoolYearStartDate(2026);
      expect(d.weekday, DateTime.monday);
      expect(d.month, DateTime.october);
      expect(d, DateTime(2026, 10, 5));
    });
    test('2027 : 1er oct = vendredi → 1er lundi = 4 oct', () {
      final d = schoolYearStartDate(2027);
      expect(d, DateTime(2027, 10, 4));
    });
  });

  group('schoolYearEndDate = 2e vendredi de juillet (année +1)', () {
    test('2026 → juillet 2027', () {
      final d = schoolYearEndDate(2026);
      expect(d.weekday, DateTime.friday);
      expect(d.year, 2027);
      expect(d.month, DateTime.july);
      expect(d, DateTime(2027, 7, 9)); // 1er ven=2, 2e ven=9
    });
    test('fin postérieure au début', () {
      expect(schoolYearEndDate(2026).isAfter(schoolYearStartDate(2026)), true);
    });
  });

  group('nextSchoolYearLabel', () {
    test('format AAAA-AAAA', () {
      expect(nextSchoolYearLabel('2026-2027'), '2027-2028');
      expect(nextSchoolYearLabel('2026 / 2027'), '2027-2028');
    });
    test('un seul millésime', () {
      expect(nextSchoolYearLabel('2026'), '2027');
    });
    test('non reconnaissable → vide', () {
      expect(nextSchoolYearLabel('Année test'), '');
    });
  });
}
