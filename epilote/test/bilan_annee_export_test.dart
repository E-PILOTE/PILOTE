import 'dart:convert';

import 'package:epilote/features/admin_groupe/providers/admin_academic_year_provider.dart';
import 'package:epilote/features/admin_groupe/providers/admin_year_analytics_provider.dart';
import 'package:epilote/features/admin_groupe/services/admin_year_csv_service.dart';
import 'package:epilote/features/admin_groupe/services/admin_year_pdf_service.dart';
import 'package:epilote/features/admin_groupe/services/group_students_pdf_service.dart';
import 'package:epilote/features/admin_groupe/providers/admin_students_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// GÉNÉRATION RÉELLE du « Bilan de l'année » (espace groupe).
///
/// Ce que ce fichier verrouille tient en une phrase : **le document doit sortir
/// avec ses polices embarquées, sans jamais toucher au réseau.**
///
/// `PdfGoogleFonts.notoSans*()` télécharge le fichier depuis fonts.gstatic.com.
/// En cas d'échec — poste hors ligne, DNS captif, pare-feu ministériel — la
/// bibliothèque `printing` n'échoue PAS : elle attrape l'erreur et retombe sur
/// `Font.helvetica()`, en silence (printing 5.14.3, `fonts/font.dart`, le `catch`
/// dont le `print` est enfermé dans un `assert` — donc muet en production).
/// Le bilan sortait alors dans une police de secours, et l'agent ne voyait qu'un
/// document « bizarre » sans jamais savoir pourquoi.
///
/// Le binding de test coupe le réseau (toute requête HTTP rend 400) : c'est
/// exactement le poste d'une école congolaise sans connexion. Un service qui
/// dépend de gstatic.com échoue donc ICI, et c'est le but.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));

  AdminYear year(String label, int y) => AdminYear(
        id: 'y-$y',
        label: label,
        startDate: DateTime(y, 9, 1),
        endDate: DateTime(y + 1, 7, 31),
        isCurrent: y == 2025,
        isLocked: y < 2024,
        classes: 320,
        eleves: 9105,
        schoolsAdopted: 14,
        schoolsTotal: 14,
      );

  YearSchoolStat school(int i, {bool long = false}) => YearSchoolStat(
        id: 's-$i',
        name: long
            ? 'Complexe Scolaire Départemental Étoile du Nord de Ouesso $i'
            : 'Lycée de Madingou $i',
        department: long ? 'Cuvette-Ouest' : 'Bouenza',
        type: i.isEven ? 'public' : 'prive',
        classes: 12,
        eleves: 430,
      );

  AdminYearAnalytics analytics(List<YearSchoolStat> ecoles) {
    final deptMap = <String, List<YearSchoolStat>>{};
    for (final s in ecoles) {
      (deptMap[s.department] ??= []).add(s);
    }
    return AdminYearAnalytics(
      byDepartment: [
        for (final e in deptMap.entries)
          YearDeptStat(
            department: e.key,
            ecoles: e.value.length,
            ecolesPreparees: e.value.where((s) => s.adopted).length,
            classes: e.value.fold(0, (a, s) => a + s.classes),
            eleves: e.value.fold(0, (a, s) => a + s.eleves),
          ),
      ],
      byType: [
        for (final t in {for (final s in ecoles) s.type})
          YearTypeStat(
            type: t,
            ecoles: ecoles.where((s) => s.type == t).length,
            classes: ecoles
                .where((s) => s.type == t)
                .fold(0, (a, s) => a + s.classes),
            eleves: ecoles
                .where((s) => s.type == t)
                .fold(0, (a, s) => a + s.eleves),
          ),
      ],
      bySchool: ecoles,
      ecolesTotal: ecoles.length,
      ecolesPreparees: ecoles.where((s) => s.adopted).length,
      classes: ecoles.fold(0, (a, s) => a + s.classes),
      eleves: ecoles.fold(0, (a, s) => a + s.eleves),
    );
  }

  final annees = [
    year('2025-2026', 2025),
    year('2024-2025', 2024),
    year('2023-2024', 2023),
  ];

  Future<List<int>> bilan(List<YearSchoolStat> ecoles) =>
      AcademicYearPdfService.buildPdf(
        year: annees.first,
        analytics: analytics(ecoles),
        allYears: annees,
      );

  /// Les noms de police d'un PDF apparaissent en clair dans les objets
  /// `/BaseFont`. On lit donc le document produit plutôt que d'espionner
  /// l'appel : c'est le résultat livré à l'agent qui compte, pas le chemin pris.
  Set<String> policesDe(List<int> pdf) {
    final texte = latin1.decode(pdf, allowInvalid: true);
    return {
      for (final m in RegExp(r'/BaseFont\s*/([A-Za-z0-9+\-]+)').allMatches(texte))
        m.group(1)!,
    };
  }

  group('le document sort', () {
    test('avec une seule école', () async {
      expect((await bilan([school(0)])).length, greaterThan(0));
    });

    test('sans aucune école — le groupe vient d\'être créé', () async {
      expect((await bilan(const [])).length, greaterThan(0));
    });

    test('avec 1 000 écoles, la cible nationale', () async {
      // `OfficialPdfKit.frame()` enveloppe son contenu dans un `Padding`, qui ne
      // se scinde pas entre deux pages : un tableau non paginé fait boucler
      // `MultiPage` jusqu'à `TooManyPagesException` et le document ne sort pas
      // du tout. À 1 000 écoles, c'est le cas nominal, pas le cas extrême.
      expect((await bilan([for (var i = 0; i < 1000; i++) school(i)])).length,
          greaterThan(0));
    });

    test('avec 1 000 écoles aux libellés à rallonge', () async {
      expect(
        (await bilan([for (var i = 0; i < 1000; i++) school(i, long: true)]))
            .length,
        greaterThan(0),
      );
    });
  });

  group('les polices sont embarquées, pas téléchargées', () {
    test('le bilan de l\'année n\'embarque PAS Helvetica', () async {
      final polices = policesDe(await bilan([school(0), school(1)]));
      expect(
        polices.where((f) => f.contains('Helvetica')),
        isEmpty,
        reason:
            'Helvetica est le repli silencieux de PdfGoogleFonts quand le '
            'téléchargement échoue. Un poste hors ligne — le cas normal — '
            'produit alors un document dans une police de secours, sans le '
            'moindre message. Charger les polices depuis assets/fonts/ via '
            'OfficialPdfKit.loadFonts(). Polices trouvées : $polices',
      );
    });

    test('un service déjà migré embarque bien Noto Sans, lui', () async {
      // Témoin : même binding, même absence de réseau. Si celui-ci passe et que
      // le précédent échoue, la différence ne vient pas de l'environnement de
      // test mais bien du chargement des polices.
      final polices = policesDe(await GroupStudentsPdfService.buildPdf(
        groupName: 'Ministère de l\'Enseignement Primaire et Secondaire',
        rows: const <GroupStudent>[],
        query: const StudentQuery(),
        truncated: false,
      ));
      expect(polices.any((f) => f.contains('NotoSans')), isTrue,
          reason: 'polices trouvées : $polices');
    });
  });

  // ── CSV : le total ne se déduit pas de la liste ────────────────────────────
  //  `analytics.bySchool` compte une ligne par établissement. PostgREST plafonne
  //  une réponse à `max-rows` en la TRONQUANT SANS ERREUR : à 1 000 écoles, la
  //  liste peut arriver amputée sans que rien ne le signale. Sommer ces lignes
  //  produirait alors un total faux — sur le document que recroise la direction
  //  des statistiques du MEPSA. Les totaux viennent donc du GROUP BY serveur,
  //  porté par `year`, et l'écart éventuel est écrit dans le fichier.
  group('CSV : totaux serveur', () {
    // Le groupe compte 300 écoles ; la liste détaillée n'en ramène que 120.
    final tronque = AdminYear(
      id: 'y',
      label: '2025-2026',
      startDate: DateTime(2025, 9, 1),
      endDate: DateTime(2026, 7, 31),
      isCurrent: true,
      isLocked: false,
      classes: 3600,
      eleves: 129000,
      schoolsAdopted: 280,
      schoolsTotal: 300,
    );
    final partiel = analytics([for (var i = 0; i < 120; i++) school(i)]);

    String csv() => AcademicYearCsvService.buildYearReportCsv(
        year: tronque, analytics: partiel);

    test('le TOTAL est celui du serveur, pas la somme des lignes reçues', () {
      final ligne = csv()
          .split('\n')
          .firstWhere((l) => l.startsWith('"TOTAL"'));
      expect(ligne, contains('"3600"'));
      expect(ligne, contains('"129000"'));
      expect(ligne, isNot(contains('"1440"')),
          reason: '1440 = 120 écoles x 12 classes, la somme de la liste reçue');
      expect(ligne, isNot(contains('"51600"')),
          reason: '51600 = 120 écoles x 430 élèves, la somme de la liste reçue');
    });

    test('une liste incomplète est signalée dans le fichier', () {
      expect(csv(), contains('AVERTISSEMENT'));
      expect(csv(), contains('120'));
      expect(csv(), contains('300'));
    });

    test("rien ne s'affiche quand la liste est complète", () {
      final complet = analytics([for (var i = 0; i < 14; i++) school(i)]);
      final sain = AdminYear(
        id: 'y',
        label: '2025-2026',
        startDate: DateTime(2025, 9, 1),
        endDate: DateTime(2026, 7, 31),
        isCurrent: true,
        isLocked: false,
        classes: 168,
        eleves: 6020,
        schoolsAdopted: 14,
        schoolsTotal: 14,
      );
      expect(
        AcademicYearCsvService.buildYearReportCsv(
            year: sain, analytics: complet),
        isNot(contains('AVERTISSEMENT')),
      );
    });
  });
}
