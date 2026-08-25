// La page Élèves affichait « Internes : 42 » en gros, et aucun chemin ne menait
// aux quarante-deux noms. Elle proposait une recherche « nom, matricule » qui
// ignorait l'identifiant national — le seul numéro qu'on ait parfois d'un
// enfant qui arrive d'ailleurs.
//
// Ces deux manques se corrigent dans `services/filtre_eleves.dart`, donc ils se
// vérifient ici.

import 'package:epilote/features/students/providers/students_registry_provider.dart';
import 'package:epilote/features/students/services/filtre_eleves.dart';
import 'package:flutter_test/flutter_test.dart';

StudentRow _eleve({
  String id = 'e1',
  String prenom = 'Aïcha',
  String nom = 'NGOMA',
  String matricule = 'MAT-0042',
  String? ine,
  String? sexe = 'F',
  String? classe = '6e A',
  String? cycle = 'college',
  String? niveau = '6e',
  String? classeId = 'c1',
  bool interne = false,
  bool affecte = false,
  bool boursier = false,
  bool aide = false,
  bool contactPrincipal = true,
}) =>
    StudentRow(
      id: id,
      firstName: prenom,
      lastName: nom,
      matricule: matricule,
      ine: ine,
      gender: sexe,
      dateOfBirth: null,
      placeOfBirth: null,
      nationality: null,
      photoUrl: null,
      isBoarder: interne,
      hasScholarship: boursier,
      hasSocialAid: aide,
      isAffecte: affecte,
      enrollmentId: 'i-$id',
      enrollmentStatus: 'active',
      classId: classeId,
      className: classe,
      cycleCode: cycle,
      levelCode: niveau,
      levelOrder: 1,
      filiereLabel: null,
      hasPrimaryTutor: contactPrincipal,
    );

void main() {
  group('Les particularités deviennent une liste, pas seulement un chiffre', () {
    final effectif = [
      _eleve(id: 'a', nom: 'ABIA', interne: true),
      _eleve(id: 'b', nom: 'BOKO', boursier: true),
      _eleve(id: 'c', nom: 'COSSA', aide: true),
      _eleve(id: 'd', nom: 'DIABA', affecte: true),
      _eleve(id: 'e', nom: 'ELION'),
    ];

    test('« Internes » ne rend que les internes', () {
      final r = filtrerEleves(effectif, particularite: 'interne');
      expect(r.map((e) => e.lastName), ['ABIA']);
    });

    test('« Boursiers / aidés » réunit bourse ET aide sociale', () {
      // C'est la carte KPI de la page : elle additionne les deux, le filtre
      // qu'elle ouvre doit rendre exactement ce qu'elle compte.
      final compte = effectif
          .where((e) => e.hasScholarship || e.hasSocialAid)
          .length;
      final r = filtrerEleves(effectif, particularite: 'boursier_ou_aide');
      expect(r, hasLength(compte));
      expect(r.map((e) => e.lastName), ['BOKO', 'COSSA']);
    });

    test('« Boursiers » seul n\'attrape pas l\'aide sociale', () {
      expect(filtrerEleves(effectif, particularite: 'boursier')
          .map((e) => e.lastName), ['BOKO']);
    });

    test('« Affectés » ne rend que les affectés MEPSA/METP', () {
      expect(filtrerEleves(effectif, particularite: 'affecte')
          .map((e) => e.lastName), ['DIABA']);
    });

    test('aucune particularité choisie ne retire personne', () {
      expect(filtrerEleves(effectif, particularite: null), hasLength(5));
      expect(filtrerEleves(effectif, particularite: ''), hasLength(5));
    });

    test('un code inconnu ne vide PAS la liste', () {
      // Une liste vide se lirait « aucun élève concerné », ce qui serait faux.
      expect(filtrerEleves(effectif, particularite: 'lubie'), hasLength(5));
    });

    test('chaque entrée du menu est un filtre qui répond', () {
      // Verrou : ajouter une option au menu sans l'implémenter la rendrait
      // silencieusement inopérante — elle afficherait tout l'effectif.
      for (final code in kParticularitesEleve.keys) {
        expect(filtrerEleves(effectif, particularite: code).length,
            lessThan(effectif.length),
            reason: '« $code » ne restreint rien');
      }
    });
  });

  group('La recherche atteint l\'identifiant national', () {
    // INE valide au sens de la clé de Luhn — la forme affichée est
    // « 26-00000123-4 ».
    final avecIne = _eleve(id: 'x', nom: 'MABIALA', ine: '26000001234');
    final sansIne = _eleve(id: 'y', nom: 'OKEMBA', ine: null);
    final effectif = [avecIne, sansIne];

    test('la forme dictée (chiffres nus) trouve l\'élève', () {
      expect(filtrerEleves(effectif, recherche: '26000001234')
          .map((e) => e.lastName), ['MABIALA']);
    });

    test('la forme AFFICHÉE, tirets compris, trouve le même élève', () {
      // L'agent recopie ce qu'il a sous les yeux : refuser la forme qu'on lui a
      // soi-même apprise à lire serait absurde.
      expect(filtrerEleves(effectif, recherche: '26-00000123-4')
          .map((e) => e.lastName), ['MABIALA']);
    });

    test('un fragment de numéro suffit', () {
      expect(filtrerEleves(effectif, recherche: '0000123'), hasLength(1));
    });

    test('un élève sans INE n\'est pas rendu par une recherche de chiffres', () {
      expect(filtrerEleves([sansIne], recherche: '26000001234'), isEmpty);
    });

    test('une recherche sans chiffre ne fait pas correspondre tous les INE', () {
      // Le piège : `normalizeIne('zorro')` vaut null, et un `contains(null)`
      // mal gardé aurait rendu l'école entière.
      expect(filtrerEleves(effectif, recherche: 'zorro'), isEmpty);
    });

    test('nom, matricule et classe restent cherchables', () {
      expect(filtrerEleves(effectif, recherche: 'mabiala'), hasLength(1));
      expect(filtrerEleves(effectif, recherche: 'MAT-0042'), hasLength(2));
      expect(filtrerEleves(effectif, recherche: '6e a'), hasLength(2));
    });
  });

  group('Les filtres se combinent, et le tri est celui du registre', () {
    final effectif = [
      _eleve(id: 'a', nom: 'ZOULOU', prenom: 'Alain', sexe: 'M', interne: true),
      _eleve(id: 'b', nom: 'ABIA', prenom: 'Zoé', sexe: 'F', interne: true),
      _eleve(id: 'c', nom: 'MBEMBA', prenom: 'Luc', sexe: 'M'),
    ];

    test('sexe ET particularité s\'appliquent ensemble', () {
      final r =
          filtrerEleves(effectif, sexe: 'M', particularite: 'interne');
      expect(r.map((e) => e.lastName), ['ZOULOU']);
    });

    test('le tri suit « NOM Prénom », pas « Prénom Nom »', () {
      // C'est l'ordre d'un registre d'école : trier sur le nom complet aurait
      // classé « Zoé ABIA » après « Alain ZOULOU ».
      expect(filtrerEleves(effectif).map((e) => e.lastName),
          ['ABIA', 'MBEMBA', 'ZOULOU']);
    });

    test('le tri s\'inverse', () {
      expect(filtrerEleves(effectif, triAscendant: false).map((e) => e.lastName),
          ['ZOULOU', 'MBEMBA', 'ABIA']);
    });

    test('le périmètre cycle / niveau / classe filtre aussi', () {
      expect(filtrerEleves(effectif, cycle: 'lycee'), isEmpty);
      expect(filtrerEleves(effectif, niveau: '6e'), hasLength(3));
      expect(filtrerEleves(effectif, classeId: 'inconnue'), isEmpty);
    });

    test('filtrer ne modifie pas la liste reçue', () {
      final source = [...effectif];
      filtrerEleves(source, triAscendant: false);
      expect(source.map((e) => e.id), ['a', 'b', 'c']);
    });
  });
}
