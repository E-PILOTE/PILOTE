import 'package:epilote/core/utils/jours_non_ouvres.dart';
import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  JOURS NON OUVRÉS — comptage des jours de classe réellement travaillés.
//
//  Les tests du comput pascal et de la liste des fériés congolais ont disparu
//  AVEC le code qu'ils couvraient. Cette règle vit désormais uniquement en base
//  (`fn_easter_sunday`, `national_holidays_congo`) : une seule autorité pour un
//  parc de plus de 1000 écoles mises à jour de façon échelonnée.
//
//  Elle n'est pas pour autant sans filet — mais le filet a changé de place :
//    • `fn_easter_sunday` se vérifie À CHAQUE APPEL (dimanche, 22 mars →
//      25 avril) et lève si le comput a été altéré ;
//    • les 16 dates de référence 2020-2035 et un balayage 1900-2200 sont
//      rejoués au déploiement, dans la migration
//      `easter_sole_authority_self_check`.
//
//  ⚠️ Ne pas réintroduire de copie Dart ici. C'est précisément la duplication
//  qui a été démontée : le test qui prétendait la garder comparait le Dart à
//  une liste figée, sans jamais interroger la base — il ne voyait donc pas le
//  SQL dériver, c'est-à-dire le seul sens qui comptait.
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  group('holidayKindLabel', () {
    test('rend le libellé des natures connues', () {
      expect(holidayKindLabel('ferie'), 'Jour férié');
      expect(holidayKindLabel('vacances'), 'Vacances scolaires');
    });

    test('valeur inconnue ou nulle → « Jour férié », sans exception', () {
      expect(holidayKindLabel(null), 'Jour férié');
      expect(holidayKindLabel('n_importe_quoi'), 'Jour férié');
    });
  });

  group('countWorkingDays', () {
    test('une semaine pleine sans fermeture = 5 jours', () {
      // 2 novembre 2026 est un lundi.
      expect(DateTime(2026, 11, 2).weekday, DateTime.monday);
      expect(
          countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 8), const []),
          5);
    });

    test('un férié en semaine retire un jour', () {
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 8), [
          (start: DateTime(2026, 11, 4), end: DateTime(2026, 11, 4)),
        ]),
        4,
      );
    });

    test('un férié tombant un dimanche ne retire rien', () {
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 8), [
          (start: DateTime(2026, 11, 8), end: DateTime(2026, 11, 8)),
        ]),
        5,
      );
    });

    test('une période de vacances retire ses jours ouvrés', () {
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 13), [
          (start: DateTime(2026, 11, 9), end: DateTime(2026, 11, 13)),
        ]),
        5,
      );
    });

    test('deux fermetures qui se chevauchent ne comptent pas deux fois', () {
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 6), [
          (start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 5)),
          (start: DateTime(2026, 11, 4), end: DateTime(2026, 11, 6)),
        ]),
        1,
      );
    });

    test('une fermeture hors de la période ne change rien', () {
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 6), [
          (start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31)),
        ]),
        5,
      );
    });

    test('une fermeture débordant les bornes ne retire que ce qui est dedans',
        () {
      // Vacances du 30 octobre au 10 novembre, période observée = la semaine
      // du 2 au 6 : les 5 jours sont mangés, pas davantage.
      expect(
        countWorkingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 6), [
          (start: DateTime(2026, 10, 30), end: DateTime(2026, 11, 10)),
        ]),
        0,
      );
    });

    test('bornes du même jour', () {
      expect(
          countWorkingDays(
              DateTime(2026, 11, 2), DateTime(2026, 11, 2), const []),
          1);
      expect(
          countWorkingDays(
              DateTime(2026, 11, 7), DateTime(2026, 11, 7), const []),
          0); // samedi
    });

    test('un week-end seul = 0', () {
      expect(
          countWorkingDays(
              DateTime(2026, 11, 7), DateTime(2026, 11, 8), const []),
          0);
    });

    test('intervalle inversé → 0, sans exception ni boucle infinie', () {
      expect(
          countWorkingDays(
              DateTime(2027, 1, 1), DateTime(2026, 1, 1), const []),
          0);
    });

    test('une année scolaire entière reste un nombre plausible', () {
      // Octobre → juillet, sans aucune fermeture saisie : le chiffre doit
      // rester dans l'épure d'une année scolaire (env. 43 semaines × 5).
      final n = countWorkingDays(
          DateTime(2026, 10, 1), DateTime(2027, 7, 31), const []);
      expect(n, greaterThan(200));
      expect(n, lessThan(230));
    });

    test('les heures des bornes sont ignorées', () {
      // Un DateTime venant d'un picker peut porter une heure : le comptage
      // travaille en jours calendaires.
      expect(
        countWorkingDays(DateTime(2026, 11, 2, 17, 30),
            DateTime(2026, 11, 6, 8, 15), const []),
        5,
      );
    });
  });
}
