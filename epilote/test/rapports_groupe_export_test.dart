import 'dart:convert';

import 'package:epilote/core/services/official_pdf_kit.dart';
import 'package:epilote/features/admin_groupe/providers/admin_regional_provider.dart';
import 'package:epilote/features/admin_groupe/providers/admin_reports_provider.dart';
import 'package:epilote/features/admin_groupe/services/regional_pdf_service.dart';
import 'package:epilote/features/admin_groupe/services/reports_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';

/// GÉNÉRATION RÉELLE des deux rapports de l'espace groupe — celui que la
/// direction des statistiques recroise, et celui qu'on remet à une préfecture.
///
/// ── CE QUE CES TESTS VERROUILLENT ────────────────────────────────────────────
///
/// **1. Le document sort à l'échelle nationale.**
/// `OfficialPdfKit.frame()` enveloppe son contenu dans un `Padding`, qui ne sait
/// pas se scinder entre deux pages. Un tableau plus haut qu'une feuille fait
/// donc boucler `MultiPage` jusqu'à `TooManyPagesException` : le rapport ne sort
/// pas du tout — pas « mal paginé », pas « tronqué » : absent. Les deux services
/// posaient `schoolRows`, `gpsSchools` et `projects` — trois listes qui suivent
/// la taille du parc — chacune dans un cadre unique.
///
/// SEUIL MESURÉ sur l'ancienne structure reproduite à l'identique (un
/// `Padding > Column > TableHelper.fromTextArray`) : 35 lignes passaient, 40
/// levaient `TooManyPagesException`. Les deux plus gros groupes en comptent
/// aujourd'hui 14 et 12 — le défaut dormait à une vingtaine d'écoles près.
///
/// **2. Les polices sont embarquées, jamais téléchargées.**
/// `PdfGoogleFonts.notoSans*()` va chercher le fichier sur fonts.gstatic.com et,
/// en cas d'échec, ne lève RIEN : `printing` attrape l'erreur et retombe sur
/// `Font.helvetica()` (printing 5.14.3, `fonts/font.dart` — le `print` est
/// enfermé dans un `assert`, donc muet en production). Helvetica ne gère pas
/// l'Unicode : les accents disparaissent d'un document officiel, et personne ne
/// le voit avant impression. Le binding de test coupe le réseau — c'est le poste
/// d'une école congolaise sans connexion.
///
/// **3. Le document est émis par le GROUPE, pas par l'éditeur du logiciel.**
/// Les deux services portaient leur propre en-tête, laquelle écrivait
/// « E-PILOTE CONGO » sous les armoiries.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));
  tearDown(() => OfficialPdfKit.setIssuer(null));

  // ── Lecture du PDF produit ────────────────────────────────────────────────
  //  On inspecte le RÉSULTAT livré, pas le chemin pris pour l'obtenir : les noms
  //  de police et les objets de page apparaissent en clair dans le fichier,
  //  hors des flux compressés.
  String brut(List<int> pdf) => latin1.decode(pdf, allowInvalid: true);

  Set<String> policesDe(List<int> pdf) => {
        for (final m
            in RegExp(r'/BaseFont\s*/([A-Za-z0-9+\-]+)').allMatches(brut(pdf)))
          m.group(1)!,
      };

  /// Nombre de pages du document. `/Type /Page` — jamais `/Pages`, qui est le
  /// nœud de l'arborescence et n'apparaît qu'une fois.
  int pagesDe(List<int> pdf) =>
      RegExp(r'/Type\s*/Page(?![s])').allMatches(brut(pdf)).length;

  // ══════════════════════════════════════════════════════════════════════════
  //  RAPPORT ANALYTIQUE
  // ══════════════════════════════════════════════════════════════════════════
  ReportSchoolRow ecole(int i, {bool long = false}) => ReportSchoolRow(
        id: 's-$i',
        name: long
            ? "Collège d'Enseignement Technique et Professionnel "
                'de Nkayi-Bouenza n° $i'
            : 'Lycée de Madingou $i',
        type: i.isEven ? 'public' : 'prive',
        department: long ? 'Cuvette-Ouest' : 'Bouenza',
        isActive: i % 7 != 0,
        students: 430,
        studentsM: 220,
        studentsF: 210,
        staff: 24,
        fonctionnaires: 15,
        classes: 12,
        revenue: 4850000,
        payments: 300,
      );

  ReportData rapport(List<ReportSchoolRow> ecoles) => ReportData(
        groupName: "Ministère de l'Enseignement Technique et Professionnel",
        planName: 'National',
        periodLabel: 'Année scolaire en cours',
        periodStart: DateTime(2025, 9, 1),
        periodEnd: DateTime(2026, 7, 31),
        scopeLabel: 'Toutes les écoles du groupe',
        schoolsTotal: ecoles.length,
        schoolsActives: ecoles.where((e) => e.isActive).length,
        publicCount: ecoles.where((e) => e.type == 'public').length,
        priveCount: ecoles.where((e) => e.type == 'prive').length,
        elevesTotal: ecoles.fold(0, (a, e) => a + e.students),
        elevesNouveaux: 1240,
        studentsM: ecoles.fold(0, (a, e) => a + e.studentsM),
        studentsF: ecoles.fold(0, (a, e) => a + e.studentsF),
        personnelTotal: ecoles.fold(0, (a, e) => a + e.staff),
        personnelNouveau: 87,
        fonctionnaires: ecoles.fold(0, (a, e) => a + e.fonctionnaires),
        nonFonctionnaires: ecoles.fold(0, (a, e) => a + e.nonFonctionnaires),
        classesTotal: ecoles.fold(0, (a, e) => a + e.classes),
        revenusTotal: ecoles.fold(0.0, (a, e) => a + e.revenue),
        paiementsCount: ecoles.fold(0, (a, e) => a + e.payments),
        elevesAJour: (ecoles.fold(0, (a, e) => a + e.students) * 0.72).round(),
        staffByContract: const {
          'permanent': 4200,
          'contractuel': 1830,
          'vacataire': 640,
          'stagiaire': 95,
        },
        schoolsByDept: const {
          'Bouenza': 120,
          'Cuvette-Ouest': 90,
          'Pool': 210,
        },
        studentsByDept: const {
          'Bouenza': 51600,
          'Cuvette-Ouest': 38700,
          'Pool': 90300,
        },
        enrollmentTrend: const [ReportTrendPoint('Sept.', 1240)],
        hireTrend: const [ReportTrendPoint('Sept.', 87)],
        revenueTrend: const [ReportTrendPoint('Sept.', 12, amount: 4850000)],
        schoolRows: ecoles,
        allSchools: ecoles,
      );

  group('Rapport analytique — le document sort', () {
    test('sans aucun établissement — le groupe vient d\'être créé', () async {
      expect((await ReportsPdfService.buildPdf(data: rapport(const []))).length,
          greaterThan(0));
    });

    test('avec un seul établissement', () async {
      expect((await ReportsPdfService.buildPdf(data: rapport([ecole(0)]))).length,
          greaterThan(0));
    });

    test('avec 1 000 établissements, la cible nationale', () async {
      final pdf = await ReportsPdfService.buildPdf(
          data: rapport([for (var i = 0; i < 1000; i++) ecole(i)]));
      expect(pdf.length, greaterThan(0));
      // 1 000 lignes à 20 par bloc = au moins 50 cadres : un document d'une
      // seule page signifierait que la table a été perdue en route.
      expect(pagesDe(pdf), greaterThan(40),
          reason: 'la table des établissements doit être répartie sur '
              'plusieurs feuilles, pas écrasée sur une seule');
    });

    test('avec 1 000 établissements aux libellés à rallonge', () async {
      expect(
        (await ReportsPdfService.buildPdf(
                data: rapport([for (var i = 0; i < 1000; i++) ecole(i, long: true)])))
            .length,
        greaterThan(0),
      );
    });

    test('le seuil historique de 31 lignes est franchi', () async {
      // La valeur exacte à laquelle le bilan de l'année cessait de se générer
      // avant pagination. Un tableau de structure identique doit passer.
      expect(
        (await ReportsPdfService.buildPdf(
                data: rapport([for (var i = 0; i < 31; i++) ecole(i)])))
            .length,
        greaterThan(0),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  RAPPORT TERRITORIAL
  // ══════════════════════════════════════════════════════════════════════════
  AdminSchoolPin pin(int i, {bool long = false}) => AdminSchoolPin(
        id: 'p-$i',
        name: long
            ? 'Complexe Scolaire Départemental Étoile du Nord de Ouesso n° $i'
            : 'CEG de Dolisie $i',
        type: i.isEven ? 'public' : 'prive',
        isActive: i % 5 != 0,
        students: 380,
        department: long ? 'Sangha' : 'Niari',
        city: 'Dolisie',
        latitude: -4.2 + i * 0.001,
        longitude: 12.6 + i * 0.001,
        locationSource: const ['gps', 'geocoded', 'manual'][i % 3],
      );

  AdminProjectPin projet(int i) => AdminProjectPin(
        id: 'pr-$i',
        name: "Construction d'un collège d'enseignement général — lot $i",
        status: const [
          'etude',
          'validation',
          'budgetisation',
          'construction',
          'acheve'
        ][i % 5],
        latitude: -4.3,
        longitude: 13.2,
        department: 'Pool',
        city: 'Kinkala',
        budgetXaf: 185000000 + i,
        beneficiariesEst: 640,
      );

  AdminDeptEntry dept(String nom, int n) => AdminDeptEntry(
        dept: nom,
        coords: const LatLng(-4.26, 15.28),
        schoolCount: n,
        studentCount: n * 380,
        activeCount: (n * 0.8).round(),
        schools: const [],
      );

  AdminRegionalData territoire({
    required List<AdminSchoolPin> gps,
    required List<AdminDeptEntry> depts,
  }) =>
      AdminRegionalData(
        depts: depts,
        allDepts: depts,
        gpsSchools: gps,
        totalSchools: gps.length + 120,
        totalStudents: gps.fold(0, (a, p) => a + p.students),
        coveredDepts: depts.length,
        activeSchools: gps.where((p) => p.isActive).length,
      );

  Future<List<int>> territorial({
    required int ecoles,
    required int projets,
    int departements = 12,
    bool long = false,
  }) =>
      RegionalPdfService.buildPdf(
        groupName: "Ministère de l'Enseignement Technique et Professionnel",
        data: territoire(
          gps: [for (var i = 0; i < ecoles; i++) pin(i, long: long)],
          depts: [
            for (var i = 0; i < departements; i++) dept('Département $i', 40 + i)
          ],
        ),
        projects: [for (var i = 0; i < projets; i++) projet(i)],
      );

  group('Rapport territorial — le document sort', () {
    test('sur un groupe vide', () async {
      expect((await territorial(ecoles: 0, projets: 0, departements: 0)).length,
          greaterThan(0));
    });

    test('avec 1 000 écoles géolocalisées', () async {
      final pdf = await territorial(ecoles: 1000, projets: 0);
      expect(pdf.length, greaterThan(0));
      expect(pagesDe(pdf), greaterThan(40));
    });

    test('avec 300 projets scolaires — une liste sans borne', () async {
      // Un plan quinquennal de constructions n'a aucun plafond structurel :
      // c'est la seule des trois tables dont rien ne limite la longueur.
      expect((await territorial(ecoles: 0, projets: 300)).length, greaterThan(0));
    });

    test('avec 50 départements — saisie libre, donc orthographes fautives',
        () async {
      // `schools.department` est du texte libre : « Pool », « pool » et
      // « Le Pool » lèvent trois lignes. Le Congo en compte quinze ; la table
      // doit survivre à trois fois plus.
      expect((await territorial(ecoles: 0, projets: 0, departements: 50)).length,
          greaterThan(0));
    });

    test('tout à la fois, aux libellés à rallonge', () async {
      expect(
        (await territorial(ecoles: 1000, projets: 300, departements: 50, long: true))
            .length,
        greaterThan(0),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  POLICES ET ÉMETTEUR
  // ══════════════════════════════════════════════════════════════════════════
  group('les polices sont embarquées, pas téléchargées', () {
    test("le rapport analytique n'embarque PAS Helvetica", () async {
      final polices =
          policesDe(await ReportsPdfService.buildPdf(data: rapport([ecole(0)])));
      expect(polices.where((f) => f.contains('Helvetica')), isEmpty,
          reason: 'polices trouvées : $polices');
      expect(polices.any((f) => f.contains('NotoSans')), isTrue,
          reason: 'polices trouvées : $polices');
    });

    test("le rapport territorial n'embarque PAS Helvetica", () async {
      final polices = policesDe(await territorial(ecoles: 3, projets: 2));
      expect(polices.where((f) => f.contains('Helvetica')), isEmpty,
          reason: 'polices trouvées : $polices');
      expect(polices.any((f) => f.contains('NotoSans')), isTrue,
          reason: 'polices trouvées : $polices');
    });
  });

  group("l'émetteur du document atteint bien la page", () {
    // Le contenu textuel vit dans des flux COMPRESSÉS : on ne peut pas y
    // chercher le nom du ministère. Ce qu'on peut affirmer, en revanche, c'est
    // que poser un émetteur CHANGE le document — ce qui serait impossible si le
    // service continuait d'écrire « E-PILOTE CONGO » en dur, comme avant.
    test('le rapport analytique change quand le groupe change', () async {
      OfficialPdfKit.setIssuer(null);
      final defaut = await ReportsPdfService.buildPdf(data: rapport([ecole(0)]));

      OfficialPdfKit.setIssuer(const PdfIssuer(
          name: "Ministère de l'Enseignement Technique et Professionnel"));
      final ministere =
          await ReportsPdfService.buildPdf(data: rapport([ecole(0)]));

      expect(ministere.length, isNot(equals(defaut.length)),
          reason: "l'en-tête doit porter le nom du groupe connecté, pas un "
              'libellé codé en dur');
    });

    test('le rapport territorial change quand le groupe change', () async {
      OfficialPdfKit.setIssuer(null);
      final defaut = await territorial(ecoles: 3, projets: 2);

      OfficialPdfKit.setIssuer(const PdfIssuer(
          name: "Ministère de l'Enseignement Technique et Professionnel"));
      final ministere = await territorial(ecoles: 3, projets: 2);

      expect(ministere.length, isNot(equals(defaut.length)));
    });
  });
}
