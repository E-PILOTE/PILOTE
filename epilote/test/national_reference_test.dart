import 'package:epilote/features/admin_groupe/providers/exam_archives_provider.dart';
import 'package:epilote/features/admin_groupe/providers/national_reference.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA RÉFÉRENCE NATIONALE — ce qu'on a le droit de comparer, et à quoi.
//
//  Le cockpit mesure la réussite de NOS écoles ; la DEC proclame celle du
//  pays. Poser les deux côte à côte n'est légitime que sous trois conditions,
//  et ce sont exactement ces trois conditions que ce fichier verrouille :
//
//  1. UN examen à la fois — il n'existe pas de taux national « tous examens ».
//  2. La session est toujours nommée — sinon on compare 2026 à 2025 en
//     silence, ce qui est pire que de ne rien comparer.
//  3. Le taux officiel porte sur les PRÉSENTS, jamais sur les inscrits.
// ════════════════════════════════════════════════════════════════════════════
OfficialFigure _fig({
  String id = 'f1',
  PubScope scope = PubScope.national,
  String? examCode = 'BAC_TP',
  String? yearLabel = '2025-2026',
  int? present,
  int? admitted,
  double? storedRate,
  String? department,
  String? sourceLabel,
}) =>
    OfficialFigure(
      id: id,
      sessionId: 'sess-$yearLabel',
      scope: scope,
      department: department,
      examCode: examCode,
      yearLabel: yearLabel,
      present: present,
      admitted: admitted,
      storedRate: storedRate,
      sourceLabel: sourceLabel,
    );

void main() {
  group('nationalReferenceFor', () {
    test('aucune référence hors d\'un examen précis', () {
      // « Tous les examens » : le BET et le bac T&P ne se moyennent pas.
      expect(
        nationalReferenceFor(
          [_fig(storedRate: 51.61)],
          examCode: null,
          currentYearLabel: '2025-2026',
        ),
        isNull,
      );
    });

    test('retient le chiffre de la session en cours', () {
      final r = nationalReferenceFor(
        [
          _fig(id: 'a', yearLabel: '2024-2025', present: 15843, admitted: 7681),
          _fig(id: 'b', yearLabel: '2025-2026', storedRate: 51.61),
        ],
        examCode: 'BAC_TP',
        currentYearLabel: '2025-2026',
      );

      expect(r, isNotNull);
      expect(r!.yearLabel, '2025-2026');
      expect(r.rate, closeTo(51.61, 0.001));
      expect(r.isCurrentSession, isTrue);
    });

    test('à défaut, la dernière session proclamée — et elle est datée', () {
      // Cas réel du BET : rien n'est encore proclamé pour 2025-2026.
      final r = nationalReferenceFor(
        [
          _fig(
              id: 'a',
              examCode: 'BET',
              yearLabel: '2023-2024',
              present: 5937,
              admitted: 3835),
          _fig(
              id: 'b',
              examCode: 'BET',
              yearLabel: '2024-2025',
              present: 6841,
              admitted: 5308),
        ],
        examCode: 'BET',
        currentYearLabel: '2025-2026',
      );

      expect(r!.yearLabel, '2024-2025');
      expect(r.isCurrentSession, isFalse,
          reason: 'la bande doit pouvoir dire que la session diffère');
      expect(r.rate, closeTo(77.59, 0.01));
    });

    test('le taux porte sur les PRÉSENTS, pas sur les inscrits', () {
      // BAC T&P juin 2025 : 7 681 admis sur 15 843 présents = 48,48 % —
      // et non 7 681 / 16 070 inscrits.
      final r = nationalReferenceFor(
        [_fig(yearLabel: '2024-2025', present: 15843, admitted: 7681)],
        examCode: 'BAC_TP',
        currentYearLabel: '2024-2025',
      );

      expect(r!.rate, closeTo(48.48, 0.01));
      expect(r.hasCounts, isTrue);
    });

    test('ignore les chiffres départementaux et les autres examens', () {
      final r = nationalReferenceFor(
        [
          _fig(
              id: 'd',
              scope: PubScope.departement,
              department: 'Bouenza',
              storedRate: 99.23),
          _fig(id: 'x', examCode: 'BET', storedRate: 77.59),
        ],
        examCode: 'BAC_TP',
        currentYearLabel: '2025-2026',
      );

      expect(r, isNull,
          reason: 'Bouenza à 99,23 % n\'est pas une référence nationale');
    });

    test('un taux publié sans effectifs reste exploitable', () {
      final r = nationalReferenceFor(
        [_fig(storedRate: 51.61, sourceLabel: 'Délibération DEC 2026')],
        examCode: 'BAC_TP',
        currentYearLabel: '2025-2026',
      );

      expect(r!.hasCounts, isFalse);
      expect(r.sourceLabel, 'Délibération DEC 2026');
    });

    test('rien de relevé : aucune référence, jamais un zéro', () {
      expect(
        nationalReferenceFor(const [],
            examCode: 'BAC_TP', currentYearLabel: '2025-2026'),
        isNull,
      );
      // Une ligne sans taux ni effectifs ne fabrique pas un 0 %.
      expect(
        nationalReferenceFor([_fig()],
            examCode: 'BAC_TP', currentYearLabel: '2025-2026'),
        isNull,
      );
    });
  });
}
