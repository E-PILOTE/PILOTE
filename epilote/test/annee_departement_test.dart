import 'dart:convert';

import 'package:epilote/features/admin_groupe/providers/admin_academic_year_provider.dart';
import 'package:epilote/features/admin_groupe/providers/admin_year_analytics_provider.dart';
import 'package:epilote/features/admin_groupe/services/admin_year_department_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// LA FICHE DÉPARTEMENTALE — ce qu'on ouvre en cliquant une ligne de
/// « Préparation par école », et ce qu'on envoie à une direction départementale.
///
/// Deux choses à verrouiller :
///   • le CALCUL — rang, part dans le groupe, périmètre du département : c'est
///     lui qui décide si l'on relance un établissement ou si l'on appelle une
///     direction. Un rang faux oriente mal une décision ;
///   • la GÉNÉRATION à l'échelle — un département congolais peut compter plus
///     de cent établissements, et un cadre plus haut qu'une feuille fait boucler
///     `MultiPage` jusqu'à `TooManyPagesException` : le document ne sort alors
///     pas du tout (seuil mesuré sur l'ancienne structure : 35 lignes).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  YearSchoolStat ecole(
    String id, {
    required String dept,
    required int eleves,
    int classes = 10,
    String type = 'public',
    String? nom,
  }) =>
      YearSchoolStat(
        id: id,
        name: nom ?? 'Lycée $id',
        department: dept,
        type: type,
        classes: classes,
        eleves: eleves,
      );

  AdminYearAnalytics analytics(List<YearSchoolStat> ecoles) =>
      AdminYearAnalytics(
        byDepartment: const [],
        byType: const [],
        bySchool: ecoles,
        ecolesTotal: ecoles.length,
        ecolesPreparees: ecoles.where((s) => s.adopted).length,
        classes: ecoles.fold(0, (a, s) => a + s.classes),
        eleves: ecoles.fold(0, (a, s) => a + s.eleves),
      );

  final groupe = analytics([
    ecole('a', dept: 'Niari', eleves: 900),
    ecole('b', dept: 'Niari', eleves: 500),
    ecole('c', dept: 'Niari', eleves: 500),
    ecole('d', dept: 'Niari', eleves: 100, classes: 0), // pas encore préparée
    ecole('e', dept: 'Bouenza', eleves: 2000),
    ecole('f', dept: 'Bouenza', eleves: 1000),
  ]);

  group('périmètre du département', () {
    test('ne retient QUE les établissements du département demandé', () {
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      expect(d.ecolesTotal, 4);
      expect(d.ecoles.map((e) => e.id), containsAll(['a', 'b', 'c', 'd']));
      expect(d.ecoles.map((e) => e.id), isNot(contains('e')));
    });

    test('les établissements sortent par effectif décroissant', () {
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      expect(d.ecoles.first.id, 'a');
      expect(d.ecoles.last.id, 'd');
    });

    test('les totaux sont ceux du département, pas ceux du groupe', () {
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      expect(d.eleves, 2000); // 900 + 500 + 500 + 100
      expect(d.classes, 30); // 3 x 10, la quatrième n'a rien ouvert
      expect(d.ecolesPreparees, 3);
      expect(d.ecolesEnAttente, 1);
    });

    test('un département inconnu rend une fiche vide, pas une erreur', () {
      // `schools.department` est du texte libre : une orthographe fautive ne
      // doit pas faire tomber l'écran.
      final d = YearDepartmentDetail.of(groupe, 'Kouilou');
      expect(d.ecolesTotal, 0);
      expect(d.eleves, 0);
      expect(d.tauxPreparation, 0);
      expect(d.moyenneElevesParClasse, 0);
      expect(d.rangDe('a'), isNull);
    });
  });

  group('rang dans le département', () {
    test('1 = le plus grand effectif', () {
      expect(YearDepartmentDetail.of(groupe, 'Niari').rangDe('a'), 1);
    });

    test('deux effectifs égaux PARTAGENT le rang', () {
      // Rang de compétition. Les départager par leur position dans la liste
      // inventerait un classement que les données ne portent pas : « b » et
      // « c » ont exactement 500 élèves l'un comme l'autre.
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      expect(d.rangDe('b'), 2);
      expect(d.rangDe('c'), 2);
    });

    test('le rang qui suit une égalité tient compte des ex æquo', () {
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      expect(d.rangDe('d'), 4, reason: 'deux écoles occupent le rang 2');
    });

    test("une école d'un autre département n'a pas de rang ici", () {
      expect(YearDepartmentDetail.of(groupe, 'Niari').rangDe('e'), isNull);
    });
  });

  group('part dans le groupe', () {
    test('rapporte le département aux totaux du groupe', () {
      final d = YearDepartmentDetail.of(groupe, 'Niari');
      // 2000 élèves sur 5000 dans le groupe.
      expect(d.groupeEleves, 5000);
      expect(d.partEleves, closeTo(0.4, 1e-9));
      expect(d.partEcoles, closeTo(4 / 6, 1e-9));
    });

    test('un groupe vide ne divise pas par zéro', () {
      final d = YearDepartmentDetail.of(analytics(const []), 'Niari');
      expect(d.partEleves, 0);
      expect(d.partClasses, 0);
      expect(d.partEcoles, 0);
    });
  });

  // ── La fiche PDF ───────────────────────────────────────────────────────────
  group('la fiche départementale sort', () {
    final annee = AdminYear(
      id: 'y',
      label: '2025-2026',
      startDate: DateTime(2025, 9, 1),
      endDate: DateTime(2026, 7, 31),
      isCurrent: true,
      isLocked: false,
      classes: 30,
      eleves: 2000,
      schoolsAdopted: 3,
      schoolsTotal: 4,
    );

    Future<List<int>> fiche(YearDepartmentDetail d) =>
        YearDepartmentPdfService.buildPdf(year: annee, detail: d);

    test('sur un département ordinaire', () async {
      expect((await fiche(YearDepartmentDetail.of(groupe, 'Niari'))).length,
          greaterThan(0));
    });

    test('sur un département vide', () async {
      expect((await fiche(YearDepartmentDetail.of(groupe, 'Kouilou'))).length,
          greaterThan(0));
    });

    test('avec 400 établissements aux libellés à rallonge', () async {
      final gros = analytics([
        for (var i = 0; i < 400; i++)
          ecole('s$i',
              dept: 'Pool',
              eleves: 300 + i,
              nom: "Collège d'Enseignement Technique et Professionnel "
                  'de Kinkala-Pool n° $i'),
      ]);
      final pdf = await fiche(YearDepartmentDetail.of(gros, 'Pool'));
      expect(pdf.length, greaterThan(0));
      // 400 lignes à 20 par bloc : le tableau doit s'étaler sur des dizaines de
      // feuilles, pas s'écraser sur une seule.
      final pages = RegExp(r'/Type\s*/Page(?![s])')
          .allMatches(latin1.decode(pdf, allowInvalid: true))
          .length;
      expect(pages, greaterThan(15));
    });
  });
}
