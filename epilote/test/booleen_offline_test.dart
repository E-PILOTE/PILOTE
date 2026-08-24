import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/booleen_offline.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « PAS RENSEIGNÉ » N'EST PAS « NON »
//
//  Une colonne booléenne arrive du SQLite de PowerSync en `1`, `0` ou `null` —
//  cette dernière quand l'application a écrit la ligne sans renseigner la
//  colonne, la valeur par défaut vivant côté serveur.
//
//  Le dépôt s'était doté partout du même helper, `v == 1 || v == true`. Il est
//  juste pour les booléens par défaut FAUX et faux pour ceux par défaut VRAI :
//  il transforme l'absence d'information en refus. Dans l'annuaire du
//  personnel, un agent dont `is_active` n'était pas renseigné ressortait
//  « inactif », pendant que le tableau de bord de la MÊME école le comptait
//  parmi les agents en fonction.
//
//  Ces tests figent les deux sémantiques séparément, car c'est leur confusion
//  qui produit le défaut — pas l'une ou l'autre prise isolément.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('actifOffline — valeur par défaut VRAIE', () {
    test('1 et true sont actifs', () {
      expect(actifOffline(1), isTrue);
      expect(actifOffline(true), isTrue);
    });

    test('0 et false sont inactifs', () {
      expect(actifOffline(0), isFalse);
      expect(actifOffline(false), isFalse);
    });

    test('null est ACTIF — c\'est tout l\'objet de cette fonction', () {
      // La ligne vient d'être écrite par l'application ; le serveur posera la
      // valeur par défaut. La désactiver en attendant ferait disparaître un
      // agent, une classe ou un élève de son propre écran.
      expect(actifOffline(null), isTrue);
    });

    test('une valeur inattendue ne désactive pas', () {
      // ⚠️ Choix explicite : devant une donnée qu'on ne sait pas lire, un état
      // officiel doit montrer la ligne plutôt que la faire disparaître. Un
      // surplus visible se corrige ; une absence silencieuse, non.
      expect(actifOffline('1'), isTrue);
      expect(actifOffline(2), isTrue);
    });
  });

  group('vraiOffline — valeur par défaut FAUSSE', () {
    test('1 et true sont vrais', () {
      expect(vraiOffline(1), isTrue);
      expect(vraiOffline(true), isTrue);
    });

    test('0, false et null sont faux', () {
      expect(vraiOffline(0), isFalse);
      expect(vraiOffline(false), isFalse);
      expect(vraiOffline(null), isFalse);
    });
  });

  test('les deux fonctions ne diffèrent QUE sur l\'absence de valeur', () {
    // C'est la formulation exacte du piège : sur toute valeur renseignée elles
    // s'accordent, donc aucun test de cas nominal n'aurait révélé l'erreur.
    for (final v in <Object?>[0, 1, true, false]) {
      expect(actifOffline(v), vraiOffline(v), reason: 'divergence sur $v');
    }
    expect(actifOffline(null), isNot(vraiOffline(null)));
  });
}
