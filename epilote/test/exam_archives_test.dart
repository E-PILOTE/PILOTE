import 'package:epilote/features/admin_groupe/providers/exam_archives_provider.dart';
import 'package:epilote/features/admin_groupe/services/exam_statistics_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// ARCHIVES DES PUBLICATIONS DE LA DEC.
///
/// Ce qui est gardé ici n'est pas de l'affichage : c'est la frontière entre
/// deux familles de chiffres qu'on ne doit jamais fondre.
///  • OFFICIEL   — relevé sur la publication de la DEC, fait autorité.
///  • PLATEFORME — dérivé des saisies des écoles, inséparable de sa couverture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));
  group('Taux officiel — il porte sur les PRÉSENTS', () {
    test('reproduit le taux réellement publié (BAC T&P 2025)', () {
      // 7 681 admis sur 15 843 présents, pour 16 070 inscrits → 48,48 %.
      // Calculer sur les inscrits donnerait 47,80 % : un autre chiffre, faux.
      final r = officialPassRate(present: 15843, admitted: 7681);
      expect(r!.toStringAsFixed(2), '48.48');
    });

    test('un pourcentage publié sans effectifs fait foi tel quel', () {
      // Le classement départemental du Bac général ne donne QUE des %.
      expect(officialPassRate(storedRate: 92.10), 92.10);
    });

    test('les effectifs l\'emportent sur un taux stocké contradictoire', () {
      expect(officialPassRate(present: 200, admitted: 100, storedRate: 75),
          50,
          reason: 'la publication chiffrée prime sur un pourcentage recopié');
    });

    test('aucun chiffre exploitable → aucun taux inventé', () {
      expect(officialPassRate(), isNull);
      expect(officialPassRate(present: 0, admitted: 0), isNull,
          reason: 'diviser par zéro présent ne donne pas 0 %');
    });

    test('les absents se déduisent des inscrits, jamais du taux', () {
      const f = OfficialFigure(
        id: 'x',
        sessionId: 's',
        scope: PubScope.national,
        registered: 16070,
        present: 15843,
        admitted: 7681,
      );
      expect(f.absent, 227);
      expect(f.hasCounts, isTrue);
      expect(f.hasSource, isFalse, reason: 'aucune pièce jointe ici');
    });
  });

  group('Chiffres de la plateforme — jamais sans couverture', () {
    test('une école n\'ayant saisi que ses admis n\'est PAS à 100 %', () {
      // 3 résultats saisis sur 40 candidats : le taux brut dirait 100 %.
      final t = tallyOf([
        ...List.filled(3, 'admis'),
        ...List.filled(37, null),
      ]);
      expect(t.passRate, 100);
      expect(t.coverage.toStringAsFixed(1), '7.5');
      expect(t.isReliable, isFalse,
          reason: 'c\'est la couverture qui interdit d\'afficher ce taux');
    });

    test('les absents sortent du dénominateur', () {
      final t = tallyOf(['admis', 'admis', 'ajourne', 'absent']);
      expect(t.present, 3);
      expect(t.passRate!.toStringAsFixed(2), '66.67');
      expect(t.absent, 1);
    });

    test('une fraude a composé : présente, jamais admise', () {
      final t = tallyOf(['admis', 'fraude']);
      expect(t.present, 2);
      expect(t.passRate, 50,
          reason: 'l\'exclure du dénominateur gonflerait le taux à 100 %');
    });

    test('« en attente » n\'est pas un échec', () {
      final t = tallyOf(['admis', 'en_attente', 'en_attente']);
      expect(t.known, 1);
      expect(t.present, 1);
      expect(t.passRate, 100);
      expect(t.coverage.toStringAsFixed(1), '33.3');
    });

    test('personne n\'ayant composé → aucun taux, pas 0 %', () {
      final t = tallyOf(['absent', 'absent']);
      expect(t.passRate, isNull,
          reason: '0 % dirait « tous recalés » là où nul n\'a composé');
    });

    test('une session complète et fournie est jugée fiable', () {
      final t = tallyOf([...List.filled(18, 'admis'), ...List.filled(6, 'ajourne')]);
      expect(t.coverage, 100);
      expect(t.isReliable, isTrue);
    });

    test('un effectif minuscule reste non fiable même à 100 % de couverture', () {
      final t = tallyOf(['admis', 'ajourne']);
      expect(t.coverage, 100);
      expect(t.isReliable, isFalse,
          reason: '2 candidats ne fondent pas un taux de réussite');
    });

    test('aucun candidat → couverture nulle, sans division par zéro', () {
      final t = tallyOf(const []);
      expect(t.coverage, 0);
      expect(t.passRate, isNull);
    });
  });

  group('Périmètre d\'une publication', () {
    test('le périmètre est toujours lisible sur la pièce archivée', () {
      ExamPublication p(PubScope s, {String? dep, String? school, String? code}) =>
          ExamPublication(
            id: 'p',
            sessionId: 's',
            scope: s,
            title: 'Liste des admis',
            fileName: 'f.pdf',
            filePath: 'x',
            receivedAt: DateTime(2026),
            department: dep,
            schoolName: school,
            decSchoolCode: code,
          );

      expect(p(PubScope.national).scopeLabel, 'National');
      expect(p(PubScope.departement, dep: 'Bouenza').scopeLabel, 'Bouenza');
      expect(p(PubScope.etablissement, school: 'CEG Kinkala').scopeLabel,
          'CEG Kinkala');
      // École pas encore rattachée : le code DEC porté par le document doit
      // suffire à identifier la pièce.
      expect(p(PubScope.etablissement, code: 'AAB').scopeLabel, 'AAB');
    });

    test('un code de périmètre inconnu retombe sur « national », sans planter',
        () {
      expect(PubScope.from('centre_examen'), PubScope.national);
      expect(PubScope.from(null), PubScope.national);
    });
  });

  _history();
  _statisticsPdf();
}

/// Historique — empiler des chiffres publiés, sans jamais en fabriquer.
void _history() {
  OfficialFigure nat(String year, int present, int admitted) => OfficialFigure(
        id: year, sessionId: year, scope: PubScope.national,
        examShortName: 'Bac T', yearLabel: year,
        present: present, admitted: admitted,
      );
  OfficialFigure dep(String year, String d, int present, int admitted) =>
      OfficialFigure(
        id: '$year$d', sessionId: year, scope: PubScope.departement,
        examShortName: 'Bac T', yearLabel: year, department: d,
        present: present, admitted: admitted,
      );

  group('Trajectoire nationale', () {
    test('la série se lit du plus ancien au plus récent', () {
      final h = buildNationalHistory([
        nat('2024-2025', 12898, 6254),
        nat('2021-2022', 11800, 4010),
        nat('2023-2024', 12532, 5469),
      ]);
      expect(h.single.points.map((p) => p.yearLabel),
          ['2021-2022', '2023-2024', '2024-2025']);
    });

    test('l\'évolution s\'exprime en POINTS, pas en pourcentage de hausse', () {
      // 43,64 % → 48,49 % = +4,85 POINTS. Dire « +11 % » serait exact
      // arithmétiquement et trompeur pour tout lecteur.
      final h = buildNationalHistory(
          [nat('2023-2024', 12532, 5469), nat('2024-2025', 12898, 6254)]);
      expect(h.single.points.last.deltaPoints!.toStringAsFixed(2), '4.85');
    });

    test('la première session n\'a pas d\'évolution — jamais « +0,00 »', () {
      final h = buildNationalHistory([nat('2021-2022', 100, 40)]);
      expect(h.single.points.single.deltaPoints, isNull);
      expect(h.single.totalGain, isNull, reason: 'un point ne fait pas une pente');
    });

    test('les départements ne polluent pas la série nationale', () {
      final h = buildNationalHistory([
        nat('2024-2025', 1000, 500),
        dep('2024-2025', 'Bouenza', 100, 99),
      ]);
      expect(h.single.points.single.rate, 50);
    });
  });

  group('Classement départemental', () {
    final figures = [
      dep('2023-2024', 'Bouenza', 900, 560), // 62,22 %
      dep('2023-2024', 'Brazzaville', 3500, 1290), // 36,86 %
      dep('2024-2025', 'Bouenza', 903, 610), // 67,55 %
      dep('2024-2025', 'Brazzaville', 3611, 1420), // 39,32 %
    ];

    test('classe par taux décroissant et situe vs la session précédente', () {
      final s = departmentStandings(figures,
          examShortName: 'Bac T',
          yearLabel: '2024-2025',
          previousYearLabel: '2023-2024');
      expect(s.first.department, 'Bouenza');
      expect(s.first.rank, 1);
      expect(s.first.deltaPoints!.toStringAsFixed(2), '5.33');
      expect(s.last.department, 'Brazzaville');
    });

    test('sans session précédente, aucune évolution n\'est inventée', () {
      final s = departmentStandings(figures,
          examShortName: 'Bac T', yearLabel: '2023-2024');
      expect(s.every((r) => r.deltaPoints == null), isTrue);
    });

    test('un autre examen ne contamine pas le classement', () {
      final s = departmentStandings(figures,
          examShortName: 'BET', yearLabel: '2024-2025');
      expect(s, isEmpty);
    });
  });
}

/// Le document officiel doit sortir quelles que soient les données — un
/// classement vide ou 15 départements ne doivent jamais bloquer l'impression.
void _statisticsPdf() {
  group('Statistiques officielles — document', () {
    ExamHistory hist(int n) => ExamHistory(
          examShortName: 'Bac T',
          points: [
            for (var i = 0; i < n; i++)
              HistoryPoint(
                yearLabel: '${2021 + i}-${2022 + i}',
                rate: 34 + i * 4.83,
                present: 11800 + i * 366,
                admitted: 4010 + i * 700,
                deltaPoints: i == 0 ? null : 4.83,
              ),
          ],
        );

    test('une seule session, sans classement, produit un document', () async {
      final b = await ExamStatisticsPdfService.buildPdf(
          groupName: 'METP', history: hist(1), standings: const []);
      expect(b.length, greaterThan(0));
    });

    test('15 départements et 4 sessions se génèrent sans exception', () async {
      const deps = [
        'Brazzaville', 'Pointe-Noire', 'Bouenza', 'Niari', 'Pool',
        'Kouilou', 'Cuvette', 'Plateaux', 'Lékoumou', 'Sangha',
        'Likouala', 'Cuvette-Ouest', 'Congo-Oubangui', 'Djoué-Léfini',
        'Nkéni-Alima',
      ];
      final b = await ExamStatisticsPdfService.buildPdf(
        groupName: 'Ministère de l\'Enseignement Technique et Professionnel',
        history: hist(4),
        standings: [
          for (var i = 0; i < deps.length; i++)
            DepartmentStanding(
              rank: i + 1,
              department: deps[i],
              rate: 99.5 - i * 4.1,
              present: 3611 - i * 120,
              admitted: 1420 - i * 60,
              deltaPoints: i.isEven ? 2.4 : -1.7,
            ),
        ],
      );
      expect(b.length, greaterThan(0),
          reason: 'un cadre trop haut bloquerait tout le document');
    });
  });
}
