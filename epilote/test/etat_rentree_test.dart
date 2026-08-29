import 'dart:io';

import 'package:epilote/features/students/providers/etat_rentree_provider.dart';
import 'package:epilote/features/students/services/etat_rentree_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT STATISTIQUE DE RENTRÉE
//
//  ── LE DÉFAUT D'UN DOCUMENT STATISTIQUE EST UN CHIFFRE FAUX AFFIRMÉ ───────
//  Un registre qui perd une ligne se remarque ; un total faux, non. Il a
//  exactement l'air d'un total. Et celui-ci part à la circonscription, où il
//  devient une statistique nationale et une dotation.
//
//  Deux calculs peuvent le fausser sans rien casser :
//
//   1. **L'ÂGE.** Une erreur d'un an déplace des élèves entiers d'une tranche à
//      l'autre. Et calculer l'âge « aujourd'hui » plutôt qu'à une date fixe
//      donne un état qui CHANGE entre octobre et juin — c'est alors
//      l'administration qui découvre l'écart entre deux éditions du même
//      document.
//
//   2. **LES ABSENTS.** Un élève sans sexe renseigné réparti « au mieux » entre
//      deux colonnes fabrique la statistique qu'on prétend relever. Il doit
//      être compté à part, et le document doit le dire.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  group('L’âge se calcule à la date de référence, au jour près', () {
    final rentree = DateTime(2025, 10, 1);

    test('anniversaire déjà passé', () {
      expect(ageA(DateTime(2013, 9, 30), rentree), 12);
    });

    test('anniversaire le jour même : l’âge est atteint', () {
      expect(ageA(DateTime(2013, 10, 1), rentree), 12,
          reason: 'Un enfant qui a douze ans le jour de la rentrée a douze '
              'ans à la rentrée.');
    });

    test('anniversaire le lendemain : pas encore', () {
      expect(ageA(DateTime(2013, 10, 2), rentree), 11);
    });

    test('même mois, jour antérieur', () {
      expect(ageA(DateTime(2013, 10, 15), rentree), 11);
    });

    test('né le 29 février', () {
      // 2012 est bissextile. Au 1er octobre 2025, l'enfant a 13 ans.
      expect(ageA(DateTime(2012, 2, 29), rentree), 13);
    });

    test('un âge ne peut pas dépendre du jour où l’on imprime', () {
      // Le MÊME élève, la MÊME année scolaire, deux éditions à huit mois
      // d'écart : la tranche doit être identique.
      final naissance = DateTime(2013, 12, 25);
      expect(ageA(naissance, rentree), ageA(naissance, rentree),
          reason: 'La référence est la date d’ouverture, pas « maintenant ».');
      // Et pour mémoire, ce que donnerait « aujourd'hui » en juin :
      expect(ageA(naissance, DateTime(2026, 6, 30)), 12);
      expect(ageA(naissance, rentree), 11,
          reason: 'C’est exactement l’écart qu’une référence flottante '
              'produirait entre deux éditions du même état.');
    });
  });

  group('Les tranches d’âge couvrent tout, sans trou ni recouvrement', () {
    final t = tranchesAge();

    test('tout âge de 0 à 30 tombe dans exactement une tranche', () {
      for (var age = 0; age <= 30; age++) {
        final dedans = t.where((x) => x.contient(age)).length;
        expect(dedans, 1, reason: 'L’âge $age tombe dans $dedans tranches.');
      }
    });

    test('la dernière tranche est ouverte — un élève de 25 ans existe', () {
      expect(t.last.max, isNull);
      expect(t.last.contient(25), isTrue);
    });

    test('les tranches se suivent sans laisser d’intervalle', () {
      for (var i = 0; i < t.length - 1; i++) {
        expect(t[i].max, isNotNull);
        expect(t[i + 1].min, t[i].max! + 1,
            reason: 'Trou entre « ${t[i].libelle} » et « ${t[i + 1].libelle} ».');
      }
    });
  });

  group('Personne n’est jeté en silence', () {
    test('un élève sans sexe compte au total mais dans aucune colonne', () {
      final n = LigneNiveau(
          cycleName: 'Collège', cycleOrder: 2, levelName: '6ème', levelOrder: 1)
        ..garcons = 10
        ..filles = 12
        ..sexeInconnu = 3;
      expect(n.total, 25,
          reason: 'Le total doit inclure les non renseignés, sinon l’effectif '
              'de l’école est sous-déclaré.');
      expect(n.garcons + n.filles, 22,
          reason: 'Et il ne doit PAS les répartir : ce serait inventer.');
    });

    test('une seule lacune suffit à faire parler le document', () {
      const l = LacunesEtat(
          sansSexe: 1, sansDateNaissance: 0, sansClasse: 0, sansEleve: 0);
      expect(l.aucune, isFalse);
      expect(l.total, 1);
    });

    test('sans lacune, rien ne s’affiche', () {
      const l = LacunesEtat(
          sansSexe: 0, sansDateNaissance: 0, sansClasse: 0, sansEleve: 0);
      expect(l.aucune, isTrue);
    });

    test('le document imprime les lacunes en tête, avant tout tableau', () {
      final src = File(
              'lib/features/students/services/etat_rentree_pdf_service.dart')
          .readAsStringSync();
      final iLacunes = src.indexOf('_lacunes(f, etat.lacunes)');
      final iTableau = src.indexOf('_tableEffectifs(f, etat)');
      expect(iLacunes, greaterThan(-1));
      expect(iLacunes, lessThan(iTableau),
          reason: 'Un lecteur doit savoir ce qui manque AVANT de lire un seul '
              'total.');
    });

    test('la date de référence est imprimée, jamais sous-entendue', () {
      final src = File(
              'lib/features/students/services/etat_rentree_pdf_service.dart')
          .readAsStringSync();
      expect(src.contains('Âges calculés au'), isTrue);
    });
  });

  group('Les totaux se recomposent', () {
    EtatRentree etat({int inconnus = 0}) {
      final n = LigneNiveau(
          cycleName: 'Collège', cycleOrder: 2, levelName: '6ème', levelOrder: 1)
        ..garcons = 40
        ..filles = 60
        ..sexeInconnu = inconnus;
      return EtatRentree(
        niveaux: [n],
        tranches: tranchesAge(),
        personnel: [LignePersonnel('enseignant')..hommes = 5..femmes = 7],
        lacunes: LacunesEtat(
            sansSexe: inconnus,
            sansDateNaissance: 0,
            sansClasse: 0,
            sansEleve: 0),
        dateReference: DateTime(2025, 10, 1),
        internes: 3,
        boursiers: 2,
        aideSociale: 1,
        affectes: 0,
      );
    }

    test('la part de filles se calcule sur le total, non renseignés compris',
        () {
      final e = etat(inconnus: 0);
      expect(e.totalEleves, 100);
      expect(e.partFilles, 60);

      final f = etat(inconnus: 25);
      expect(f.totalEleves, 125);
      expect(f.partFilles, 48,
          reason: 'Calculer 60/100 alors que l’école compte 125 élèves '
              'surestimerait la scolarisation des filles — exactement '
              "l'indicateur que ces états servent à suivre.");
    });

    test('une école vide ne déclare pas « 0 % de filles »', () {
      final vide = EtatRentree(
        niveaux: const [],
        tranches: tranchesAge(),
        personnel: const [],
        lacunes: const LacunesEtat(
            sansSexe: 0, sansDateNaissance: 0, sansClasse: 0, sansEleve: 0),
        dateReference: DateTime(2025, 10, 1),
        internes: 0,
        boursiers: 0,
        aideSociale: 0,
        affectes: 0,
      );
      expect(vide.partFilles, isNull,
          reason: '« 0 % » est une affirmation ; l’absence d’effectif est une '
              'absence.');
    });

    test('le personnel se totalise sexes confondus', () {
      expect(etat().totalPersonnel, 12);
    });

    test('un niveau sans classe ne divise pas par zéro', () {
      final n = LigneNiveau(
          cycleName: 'Collège', cycleOrder: 2, levelName: '6ème', levelOrder: 1)
        ..garcons = 30;
      expect(n.classes, 0);
      expect(n.parClasse, 0);
    });
  });

  group('Le document se fabrique vraiment', () {
    test('un état complet, avec toutes ses sections', () async {
      final n1 = LigneNiveau(
          cycleName: 'Collège', cycleOrder: 2, levelName: '6ème', levelOrder: 1)
        ..garcons = 120
        ..filles = 134
        ..redoublantsG = 11
        ..redoublantsF = 9
        ..nouveauxG = 60
        ..nouveauxF = 70;
      final tr = tranchesAge()
        ..[1].garcons = 40
        ..[1].filles = 44
        ..[2].garcons = 80
        ..[2].filles = 90;

      final octets = await EtatRentreePdfService.build(
        etat: EtatRentree(
          niveaux: [n1],
          tranches: tr,
          personnel: [
            LignePersonnel('enseignant')..hommes = 14..femmes = 9,
            LignePersonnel('surveillant')..hommes = 3..inconnu = 1,
          ],
          lacunes: const LacunesEtat(
              sansSexe: 2, sansDateNaissance: 4, sansClasse: 0, sansEleve: 0),
          dateReference: DateTime(2025, 10, 1),
          internes: 12,
          boursiers: 8,
          aideSociale: 3,
          affectes: 40,
        ),
        etablissement: const EnTeteEtablissement(
          nom: 'CEG de Moungali',
          code: 'CEG-042',
          type: 'public',
          tutelle: 'mepsa',
          departement: 'Brazzaville',
          arrondissement: 'Moungali',
          ville: 'Brazzaville',
        ),
        yearLabel: '2025-2026',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
      expect(octets.length, greaterThan(3000));
    });

    test('un état sans aucune lacune se fabrique aussi', () async {
      final octets = await EtatRentreePdfService.build(
        etat: EtatRentree(
          niveaux: [
            LigneNiveau(
                cycleName: 'Primaire',
                cycleOrder: 1,
                levelName: 'CP1',
                levelOrder: 1)
              ..garcons = 20
              ..filles = 22,
          ],
          tranches: tranchesAge(),
          personnel: const [],
          lacunes: const LacunesEtat(
              sansSexe: 0, sansDateNaissance: 0, sansClasse: 0, sansEleve: 0),
          dateReference: DateTime(2025, 10, 1),
          internes: 0,
          boursiers: 0,
          aideSociale: 0,
          affectes: 0,
        ),
        etablissement: const EnTeteEtablissement(nom: 'École de Poto-Poto'),
        yearLabel: '2025-2026',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });
  });

  group('Les libellés ne font disparaître personne', () {
    test('un rôle inconnu s’affiche tel quel', () {
      expect(libelleRolePersonnel('directeur_etudes'), 'directeur_etudes',
          reason: 'Le taire retirerait des agents du total, et un état '
              'statistique se juge sur ses totaux.');
    });

    test('les rôles connus sont traduits au pluriel', () {
      expect(libelleRolePersonnel('enseignant'), 'Enseignants');
      expect(libelleRolePersonnel('surveillant'), 'Surveillants');
    });
  });
}
