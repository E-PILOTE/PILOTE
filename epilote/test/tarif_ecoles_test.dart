import 'dart:io';

import 'package:epilote/core/utils/tarif_ecoles.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PRIX AFFICHÉ DOIT ÊTRE LE PRIX FACTURÉ
//
//  `tarifPourEcoles` (Dart) et `plan_price_xaf` (SQL, migration 0159) calculent
//  la même chose à deux endroits. Une divergence ne lève AUCUNE erreur : l'écran
//  annonce un montant, la facture en porte un autre, et c'est le client qui
//  découvre l'écart un mois plus tard sur un document comptable.
//
//  D'où la sonde de fin de fichier : elle relit la migration et exige que les
//  points d'ancrage vérifiés en base soient exactement ceux vérifiés ici.
// ════════════════════════════════════════════════════════════════════════════

/// Le plan « Standard » — celui dont l'utilisateur a fixé les deux ancrages.
int standard(int ecoles) => tarifPourEcoles(
      base: 30000,
      tranche2a5: 10000,
      tranche6a10: 8000,
      tranche11a20: 6000,
      tranche21p: 4000,
      ecoles: ecoles,
    );

void main() {
  group('Les deux ancrages posés par l\'utilisateur', () {
    test('1 école = 30 000, 2 écoles = 40 000', () {
      expect(standard(1), 30000);
      expect(standard(2), 40000);
    });
  });

  group('Les tranches', () {
    test('progressent sans falaise', () {
      expect(standard(3), 50000);
      expect(standard(4), 60000);
      expect(standard(5), 70000);
      expect(standard(6), 78000); // la tranche 6-10 démarre à 8 000
      expect(standard(10), 110000);
      expect(standard(11), 116000); // la tranche 11-20 démarre à 6 000
      expect(standard(20), 170000);
      expect(standard(21), 174000); // la tranche 21+ démarre à 4 000
      expect(standard(50), 290000);
    });

    // ⚠️ LE DÉFAUT QU'ON A SUPPRIMÉ. Avant, passer de 10 à 11 écoles faisait
    // ×11,4 (220 000 → 2 500 000). Un saut pareil ne se négocie pas : il se
    // contourne, en déclarant dix écoles.
    test('aucun palier ne coûte plus cher que le précédent', () {
      var precedent = 0;
      for (var n = 1; n <= 60; n++) {
        final marche = standard(n) - precedent;
        expect(marche, lessThanOrEqualTo(n == 1 ? 30000 : 10000),
            reason: 'Falaise a $n ecoles : +$marche XAF d\'un coup.');
        expect(marche, greaterThan(0), reason: 'Une ecole de plus doit couter.');
        precedent = standard(n);
      }
    });

    test('le tarif marginal décroît, jamais l\'inverse', () {
      // Un client qui grandit ne doit jamais payer sa dixième école plus cher
      // que sa troisième : c'est ce qui le ferait scinder son groupe en deux.
      int marginal(int n) => standard(n + 1) - standard(n);
      expect(marginal(1), 10000);
      expect(marginal(5), 8000);
      expect(marginal(10), 6000);
      expect(marginal(20), 4000);
      for (var n = 1; n < 40; n++) {
        expect(marginal(n + 1), lessThanOrEqualTo(marginal(n)));
      }
    });
  });

  group('Les bords', () {
    test('zéro ou une école coûtent pareil : le plancher est à une école', () {
      // Un groupe qui vient d'être créé n'a pas encore d'école. Il n'est pas
      // gratuit pour autant — il est facturé comme un groupe d'une école.
      expect(standard(0), 30000);
      expect(standard(-5), 30000);
      expect(standard(1), 30000);
    });

    test('une ligne de plan incomplète rend la base, pas une exception', () {
      // Une réponse en cache d'avant 0159 n'a pas les colonnes de tranche.
      expect(tarifPlanRow({'price_xaf': 30000}, 4), 30000);
      expect(tarifPlanRow(null, 4), 0);
    });

    test('tarifPlanRow lit les mêmes colonnes que la base', () {
      final row = {
        'price_xaf': 30000,
        'extra_school_2_5_xaf': 10000,
        'extra_school_6_10_xaf': 8000,
        'extra_school_11_20_xaf': 6000,
        'extra_school_21p_xaf': 4000,
      };
      expect(tarifPlanRow(row, 10), 110000);
    });
  });

  group('Le coût de l\'école suivante', () {
    test('répond à la seule question que pose un directeur', () {
      int suivante(int n) => coutEcoleSuivante(
            base: 30000,
            tranche2a5: 10000,
            tranche6a10: 8000,
            tranche11a20: 6000,
            tranche21p: 4000,
            ecoles: n,
          );
      expect(suivante(1), 10000);
      expect(suivante(5), 8000);
      expect(suivante(10), 6000);
      expect(suivante(20), 4000);
      expect(suivante(0), 10000); // plancher : 0 se lit comme 1
    });
  });

  // ── Le garde qui compte vraiment ──────────────────────────────────────────
  group('Dart et SQL ne peuvent pas diverger en silence', () {
    test('la migration 0159 vérifie EXACTEMENT les mêmes ancrages', () {
      final f = File('../database/migrations/'
          '0159_AVANT_LE_BUILD_le_prix_suit_le_nombre_decoles.sql');
      expect(f.existsSync(), isTrue,
          reason: 'Sonde aveugle : la migration 0159 est introuvable.');
      final sql = f.readAsStringSync().replaceAll('\r\n', '\n');

      // Les valeurs du bloc de vérification en base, une par une. Changer la
      // grille en SQL sans la changer ici fait tomber ce test.
      for (final ancrage in [
        'v1 <> 30000 OR v2 <> 40000',
        'v5 <> 70000 OR v10 <> 110000 OR v21 <> 174000',
      ]) {
        expect(sql.contains(ancrage), isTrue,
            reason: 'La migration ne verifie plus « $ancrage ». Si la grille a '
                'change en base, ce fichier de test et `tarif_ecoles.dart` '
                'doivent changer AVANT.');
      }

      // …et ces ancrages sont bien ceux que le Dart produit.
      expect(standard(1), 30000);
      expect(standard(2), 40000);
      expect(standard(5), 70000);
      expect(standard(10), 110000);
      expect(standard(21), 174000);
    });

    test('les quatre tranches de chaque plan sont écrites dans la migration', () {
      final sql = File('../database/migrations/'
              '0159_AVANT_LE_BUILD_le_prix_suit_le_nombre_decoles.sql')
          .readAsStringSync().replaceAll('\r\n', '\n');
      // Standard : les valeurs que ce fichier de test tient pour vraies.
      expect(
          sql.contains('extra_school_2_5_xaf = 10000') ||
              sql.contains('extra_school_2_5_xaf=10000'),
          isTrue,
          reason: 'La tranche 2-5 du plan Standard a change en base.');
    });
  });
}
