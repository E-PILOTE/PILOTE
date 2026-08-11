import 'package:epilote/features/admin_groupe/providers/admin_academic_year_provider.dart';
import 'package:epilote/features/admin_groupe/providers/admin_calendar_service.dart';
import 'package:epilote/features/admin_groupe/screens/admin_year_calendar_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ANNÉES SCOLAIRES (admin_groupe) — les règles qu'on ne veut plus voir casser.
//
//  Deux défauts réels sont verrouillés ici :
//    • le tri qui mutait la liste du provider, faussant le graphe d'évolution
//      et la variation « vs N-1 » ;
//    • l'absence totale de contrôle des dates de trimestre / séquence.
// ══════════════════════════════════════════════════════════════════════════════

AdminYear _annee(
  String label,
  DateTime debut,
  DateTime fin, {
  bool courante = false,
  bool archivee = false,
  int classes = 0,
  int eleves = 0,
  int adoptees = 0,
  int total = 0,
}) =>
    AdminYear(
      id: label,
      label: label,
      startDate: debut,
      endDate: fin,
      isCurrent: courante,
      isLocked: archivee,
      classes: classes,
      eleves: eleves,
      schoolsAdopted: adoptees,
      schoolsTotal: total,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('filterAndSortYears', () {
    List<AdminYear> jeu() => [
          _annee('2026-2027', DateTime(2026, 10), DateTime(2027, 7, 31)),
          _annee('2025-2026', DateTime(2025, 10), DateTime(2026, 7, 31),
              courante: true),
          _annee('2024-2025', DateTime(2024, 10), DateTime(2025, 7, 31),
              archivee: true),
        ];

    test("n'altère PAS la liste reçue (régression : tri en place)", () {
      final source = jeu();
      final avant = source.map((y) => y.label).toList();

      filterAndSortYears(source, 'all');

      expect(source.map((y) => y.label).toList(), avant,
          reason: 'la liste du provider doit rester dans son ordre initial ; '
              'la trier en place cassait le graphe et le calcul « vs N-1 »');
    });

    test('renvoie bien une instance distincte', () {
      final source = jeu();
      expect(identical(filterAndSortYears(source, 'all'), source), isFalse);
    });

    test('courante en tête, puis par date décroissante', () {
      final r = filterAndSortYears(jeu(), 'all');
      expect(r.map((y) => y.label).toList(),
          ['2025-2026', '2026-2027', '2024-2025']);
    });

    test('filtre « active » exclut les archivées', () {
      final r = filterAndSortYears(jeu(), 'active');
      expect(r.map((y) => y.label).toList(), ['2025-2026', '2026-2027']);
    });

    test('filtre « archived » ne garde que les archivées', () {
      final r = filterAndSortYears(jeu(), 'archived');
      expect(r.map((y) => y.label).toList(), ['2024-2025']);
    });

    test('liste vide → liste vide, sans exception', () {
      expect(filterAndSortYears(const [], 'all'), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('validateCalendarEntry', () {
    final anneeDebut = DateTime(2026, 10, 1);
    final anneeFin = DateTime(2027, 7, 31);

    String? valider({
      String label = 'Premier trimestre',
      DateTime? debut,
      DateTime? fin,
      List<OccupiedSpan> occupees = const [],
    }) =>
        validateCalendarEntry(
          label: label,
          start: debut ?? DateTime(2026, 10, 1),
          end: fin ?? DateTime(2026, 12, 20),
          parentStart: anneeDebut,
          parentEnd: anneeFin,
          parentLabel: "l'année 2026-2027",
          occupied: occupees,
        );

    test('une saisie correcte ne déclenche rien', () {
      expect(valider(), isNull);
    });

    test('libellé vide (ou blanc) refusé', () {
      expect(valider(label: ''), contains('libellé'));
      expect(valider(label: '   '), contains('libellé'));
    });

    test('dates absentes refusées', () {
      expect(
        validateCalendarEntry(
          label: 'T1',
          start: null,
          end: null,
          parentStart: anneeDebut,
          parentEnd: anneeFin,
          parentLabel: "l'année",
        ),
        contains('requises'),
      );
    });

    test('fin antérieure au début refusée', () {
      expect(
          valider(debut: DateTime(2026, 12, 1), fin: DateTime(2026, 11, 1)),
          contains('doit suivre'));
    });

    test('fin égale au début refusée (période vide)', () {
      final j = DateTime(2026, 11, 1);
      expect(valider(debut: j, fin: j), contains('doit suivre'));
    });

    test('période débordant AVANT le parent refusée', () {
      final m = valider(debut: DateTime(2026, 9, 1), fin: DateTime(2026, 12, 1));
      expect(m, contains("l'année 2026-2027"));
    });

    test('période débordant APRÈS le parent refusée', () {
      final m = valider(debut: DateTime(2027, 6, 1), fin: DateTime(2027, 9, 1));
      expect(m, contains("l'année 2026-2027"));
    });

    test('les bornes exactes du parent sont acceptées', () {
      expect(valider(debut: anneeDebut, fin: anneeFin), isNull);
    });

    test('chevauchement franc refusé, en nommant le voisin', () {
      final m = valider(
        debut: DateTime(2026, 11, 1),
        fin: DateTime(2027, 1, 15),
        occupees: [
          (
            start: DateTime(2027, 1, 5),
            end: DateTime(2027, 3, 20),
            label: '2e trimestre'
          ),
        ],
      );
      expect(m, contains('2e trimestre'));
    });

    test('un seul jour en commun suffit à refuser', () {
      final m = valider(
        debut: DateTime(2026, 10, 1),
        fin: DateTime(2026, 12, 20),
        occupees: [
          (
            start: DateTime(2026, 12, 20),
            end: DateTime(2027, 3, 20),
            label: '2e trimestre'
          ),
        ],
      );
      expect(m, contains('chevauche'));
    });

    test('périodes strictement consécutives acceptées', () {
      expect(
        valider(
          debut: DateTime(2026, 10, 1),
          fin: DateTime(2026, 12, 20),
          occupees: [
            (
              start: DateTime(2026, 12, 21),
              end: DateTime(2027, 3, 20),
              label: '2e trimestre'
            ),
          ],
        ),
        isNull,
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('validateHolidayEntry — jours non ouvrés', () {
    final debut = DateTime(2026, 10, 1);
    final fin = DateTime(2027, 7, 31);

    String? valider({
      String label = 'Toussaint',
      DateTime? d,
      DateTime? f,
    }) =>
        validateHolidayEntry(
          label: label,
          start: d ?? DateTime(2026, 11, 1),
          end: f ?? DateTime(2026, 11, 1),
          yearStart: debut,
          yearEnd: fin,
          yearLabel: '2026-2027',
        );

    test('un férié d\'un seul jour est valide (début == fin)', () {
      // Contrairement à un trimestre, une période non ouvrée d'un jour est le
      // cas NORMAL : la règle « la fin doit suivre le début » ne s'applique pas.
      expect(valider(), isNull);
    });

    test('une période de vacances est valide', () {
      expect(
          valider(
              label: 'Vacances de Noël',
              d: DateTime(2026, 12, 19),
              f: DateTime(2027, 1, 4)),
          isNull);
    });

    test('libellé vide refusé', () {
      expect(valider(label: '  '), contains('libellé'));
    });

    test('fin antérieure au début refusée', () {
      expect(valider(d: DateTime(2026, 12, 10), f: DateTime(2026, 12, 1)),
          contains('précéder'));
    });

    test('période hors de l\'année refusée, en nommant les bornes', () {
      final m = valider(d: DateTime(2026, 8, 15), f: DateTime(2026, 8, 15));
      expect(m, contains('2026-2027'));
    });

    test('les bornes exactes de l\'année sont acceptées', () {
      expect(valider(d: debut, f: debut), isNull);
      expect(valider(d: fin, f: fin), isNull);
    });

    test('dates absentes refusées', () {
      expect(
        validateHolidayEntry(
          label: 'X',
          start: null,
          end: null,
          yearStart: debut,
          yearEnd: fin,
          yearLabel: '2026-2027',
        ),
        contains('requises'),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('AdminYear — indicateurs dérivés', () {
    test('taux d\'adoption et reste à faire', () {
      final y = _annee('2025-2026', DateTime(2025, 10), DateTime(2026, 7, 31),
          adoptees: 30, total: 40);
      expect(y.adoptionRate, closeTo(0.75, 1e-9));
      expect(y.schoolsPending, 10);
    });

    test('aucune école : pas de division par zéro', () {
      final y = _annee('vide', DateTime(2025, 10), DateTime(2026, 7, 31));
      expect(y.adoptionRate, 0);
      expect(y.schoolsPending, 0);
    });

    test('une année à venir est signalée comme telle', () {
      final futur = DateTime.now().add(const Duration(days: 120));
      final y = _annee('futur', futur, futur.add(const Duration(days: 300)));
      expect(y.isFuture, isTrue);
      expect(y.daysToStart, greaterThan(0));
    });

    test('avancement borné à [0, 1] hors de la période', () {
      final passe = _annee('passé', DateTime(2020, 10), DateTime(2021, 7, 31));
      expect(passe.timeProgress, 1.0);

      final futur = DateTime.now().add(const Duration(days: 60));
      final aVenir =
          _annee('à venir', futur, futur.add(const Duration(days: 300)));
      expect(aVenir.timeProgress, 0.0);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('RolloverOutcome — le compte rendu du passage d\'année', () {
    RolloverOutcome o(int t, int s) =>
        RolloverOutcome(yearId: 'x', label: '2027-2028', trimesters: t, sequences: s);

    test('sans calendrier reporté', () {
      expect(o(0, 0).resume, 'Année « 2027-2028 » créée.');
    });

    test('trimestres seuls, accord au pluriel', () {
      expect(o(3, 0).resume, contains('3 trimestres reportés'));
      expect(o(1, 0).resume, contains('1 trimestre reporté'));
    });

    test('trimestres et séquences', () {
      final r = o(3, 6).resume;
      expect(r, contains('3 trimestres'));
      expect(r, contains('6 séquences'));
    });
  });
}
