import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/finance/providers/obligation_provider.dart';
import 'package:epilote/features/finance/services/bareme_applicable.dart';
import 'package:epilote/features/finance/services/obligation.dart';

LigneBareme _b(
  String id, {
  required String feeType,
  required int montant,
  String? schoolId,
  String? levelId,
  String nom = '',
  int? jourEcheance,
}) =>
    (
      id: id,
      feeType: feeType,
      jourEcheance: jourEcheance,
      nom: nom,
      montant: montant,
      schoolId: schoolId,
      levelId: levelId,
    );

void main() {
  group('duScolarite — le dû de SCOLARITÉ', () {
    test('additionne les frais uniques', () {
      final du = duScolarite([
        _b('a', feeType: 'inscription', montant: 15000),
        _b('b', feeType: 'cotisation_ape', montant: 2000),
      ], levelId: null, mois: 3);

      expect(du, 17000);
    });

    test('la mensualité s\'accumule sur les mois écoulés', () {
      final du = duScolarite([
        _b('a', feeType: 'inscription', montant: 15000),
        _b('b', feeType: 'mensualite', montant: 12000),
      ], levelId: null, mois: 3);

      expect(du, 15000 + 12000 * 3);
    });

    test('les FRAIS D\'EXAMEN sont exclus — ils ne sont dus que par les candidats',
        () {
      // Le cas réel du 13/08/2026 : un « frais d'examens » de portée réseau,
      // sans niveau visé, entrait dans le dû de CHAQUE élève du METP —
      // 1 775 élèves × 30 000 F, dont des 6e pour un baccalauréat.
      final du = duScolarite([
        _b('a', feeType: 'inscription', montant: 15000),
        _b('bac', feeType: 'frais_examens', montant: 30000),
      ], levelId: null, mois: 1);

      expect(du, 15000, reason: 'le BAC ne doit rien ajouter ici');
    });

    test('un frais d\'examen SEUL laisse un dû nul — « barème non défini »', () {
      // C'est l'état honnête : le groupe n'a publié aucun barème de scolarité.
      // Avant la correction, ces élèves affichaient 30 000 F dus.
      final du = duScolarite([
        _b('bac', feeType: 'frais_examens', montant: 30000),
      ], levelId: null, mois: 5);

      expect(du, 0);
    });

    test('un frais d\'examen ciblant un niveau reste exclu lui aussi', () {
      final du = duScolarite([
        _b('a', feeType: 'inscription', montant: 15000),
        _b('bac', feeType: 'frais_examens', montant: 30000, levelId: 'tle'),
      ], levelId: 'tle', mois: 1);

      expect(du, 15000);
    });

    test('un barème visant un AUTRE niveau ne concerne pas cet élève', () {
      final du = duScolarite([
        _b('a', feeType: 'inscription', montant: 15000),
        _b('b', feeType: 'inscription', montant: 25000, levelId: '6e'),
      ], levelId: 'tle', mois: 1);

      expect(du, 15000);
    });

    test('les frais annexes s\'additionnent — ils ne se remplacent pas', () {
      // Une école privée facture la cantine ET le bus ET la tenue. Avant la
      // migration 0108, la base n'en acceptait qu'un et le client n'en comptait
      // qu'un : deux tiers du dû annexe disparaissaient.
      final du = duScolarite([
        _b('i', feeType: 'inscription', montant: 15000),
        _b('c', feeType: 'autre', montant: 10000, nom: 'Cantine'),
        _b('t', feeType: 'autre', montant: 15000, nom: 'Transport'),
        _b('u', feeType: 'autre', montant: 8000, nom: 'Tenue'),
      ], levelId: null, mois: 1);

      expect(du, 15000 + 10000 + 15000 + 8000);
    });

    test('à portées multiples, la plus proche l\'emporte — sans cumuler', () {
      // Réseau + école pour le MÊME frais : les additionner ferait payer deux
      // fois. L'école (plus spécifique) l'emporte.
      final du = duScolarite([
        _b('reseau', feeType: 'inscription', montant: 15000),
        _b('ecole', feeType: 'inscription', montant: 20000, schoolId: 'e1'),
      ], levelId: null, mois: 1);

      expect(du, 20000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  L'EXONÉRATION (migration 0109)
  //
  //  `has_scholarship` était saisi, stocké, synchronisé, affiché en pastille —
  //  et n'entrait dans aucun calcul. Un boursier à 100 % apparaissait « Impayé »
  //  au même titre qu'une famille qui ne règle pas, et la caisse le relançait.
  // ══════════════════════════════════════════════════════════════════════════
  group('exonération', () {
    List<LigneBareme> lignes() => [
          _b('i', feeType: 'inscription', montant: 15000),
          _b('m', feeType: 'mensualite', montant: 10000),
          _b('a', feeType: 'cotisation_ape', montant: 2000),
        ];

    test('sans taux, rien ne change', () {
      expect(duScolarite(lignes(), levelId: null, mois: 2), 15000 + 20000 + 2000);
    });

    test('un boursier à 100 % ne doit rien', () {
      expect(
        duScolarite(lignes(), levelId: null, mois: 2, exoneration: 100),
        0,
      );
    });

    test('la moitié, c\'est la moitié de chaque frais de scolarité', () {
      expect(
        duScolarite(lignes(), levelId: null, mois: 2, exoneration: 50),
        7500 + 10000 + 1000,
      );
    });

    test('les FRAIS D\'EXAMEN échappent à l\'exonération — ce sont ceux de l\'État',
        () {
      // Ils sont déjà hors du dû de scolarité ; ce test verrouille le fait
      // qu'aucune exonération d'école ne les ramène ni ne les efface.
      final du = duScolarite([
        _b('i', feeType: 'inscription', montant: 15000),
        _b('bac', feeType: 'frais_examens', montant: 30000),
      ], levelId: null, mois: 1, exoneration: 100);

      expect(du, 0, reason: 'seule l\'inscription était en jeu, et elle est remise');
    });

    test('les FRAIS ANNEXES échappent à l\'exonération — l\'école les décaisse',
        () {
      // Exonérer la cantine ferait supporter à l'école des repas qu'elle a
      // réellement payés. La bourse couvre la scolarité, pas les services.
      final du = duScolarite([
        _b('i', feeType: 'inscription', montant: 15000),
        _b('c', feeType: 'autre', montant: 10000, nom: 'Cantine'),
      ], levelId: null, mois: 1, exoneration: 100);

      expect(du, 10000, reason: 'la cantine reste due');
    });

    test('un taux nul ou négatif ne retire rien', () {
      // La base refuse 0 (contrainte 0109), mais une donnée venue d'ailleurs ne
      // doit jamais produire un dû fantaisiste.
      expect(apresExoneration(15000, 0), 15000);
      expect(apresExoneration(15000, -20), 15000);
      expect(apresExoneration(15000, null), 15000);
    });

    test('100 % rend EXACTEMENT zéro, quel que soit le montant', () {
      // L'arrondi porte sur la part exonérée : sinon un montant impair
      // laisserait un franc orphelin, et l'élève resterait « Impayé » à vie.
      for (final m in [1, 7, 999, 15001, 33333]) {
        expect(apresExoneration(m, 100), 0, reason: '$m F');
      }
    });

    test('un taux au tiers ne perd pas de francs', () {
      // 33 % de 10 000 = 3 300 exonérés, 6 700 dus. Les deux doivent se
      // recomposer, sinon la caisse et le bulletin d'exonération divergent.
      const du = 10000;
      final reste = apresExoneration(du, 33);
      expect(reste + (du - reste), du);
      expect(reste, 6700);
    });
  });
}
