import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/booleen_en_ligne.dart';
import 'package:epilote/core/utils/booleen_offline.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE COLONNE ABSENTE DU `select()` N'EST PAS UNE COLONNE À FAUX
//
//  `school_groups.is_active` se lisait sous trois formes dans les deux espaces
//  qui interrogent Supabase en direct — `== true`, `?? true`, `?? false` — dont
//  deux dans le même fichier, et ces valeurs alimentent les compteurs de
//  l'opérateur de plateforme.
//
//  La colonne est `NOT NULL DEFAULT TRUE` : aucune ligne NULL n'existe, donc les
//  trois formes rendaient le même chiffre sur la donnée réelle. La divergence ne
//  se voyait nulle part. Elle se réveille par la projection : `map['is_active']`
//  rend `null` aussi quand la colonne n'est pas demandée au `select()`.
//
//  Ces tests figent la sémantique retenue — l'absence rend le DÉFAUT DE LA
//  COLONNE — et la distinguent de son homologue offline, dont la confusion avec
//  celle-ci est la cause du défaut.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('actifEnLigne — colonne NOT NULL DEFAULT TRUE', () {
    test('true est actif, false est inactif', () {
      expect(actifEnLigne(true), isTrue);
      expect(actifEnLigne(false), isFalse);
    });

    test('null est ACTIF — c\'est tout l\'objet de cette fonction', () {
      // En base la colonne ne peut pas valoir NULL. Un `null` ici signifie donc
      // que la colonne n'était pas dans le `select()` — répondre « inactif »
      // ferait annoncer « 0 groupe actif » à l'opérateur, sans erreur.
      expect(actifEnLigne(null), isTrue);
    });

    test('une valeur inattendue ne désactive pas', () {
      // Même choix que côté offline : devant une donnée qu'on ne sait pas lire,
      // un état officiel montre la ligne plutôt que de la faire disparaître.
      expect(actifEnLigne('true'), isTrue);
      expect(actifEnLigne(1), isTrue);
    });

    test('0 reste inactif si un entier remonte par accident', () {
      // PostgREST rend un `bool`, jamais un `int` — mais le paramètre est
      // `Object?` et un jour de RPC mal typé ne doit pas inverser la réponse.
      expect(actifEnLigne(0), isFalse);
    });
  });

  test('les formes qu\'elle remplace divergent exactement sur l\'absence', () {
    // La formulation exacte du piège : sur toute valeur renseignée les trois
    // lectures s'accordent, donc aucun test de cas nominal n'aurait révélé
    // l'incohérence. C'est le `null` — donc la projection — qui les sépare.
    // Les deux formes remplacées, telles qu'elles s'écrivaient sur le terrain.
    bool ancienEgalTrue(Object? v) => v == true;
    bool ancienDefautFaux(Object? v) => (v as bool?) ?? false;

    for (final v in <Object?>[true, false]) {
      expect(ancienEgalTrue(v), actifEnLigne(v), reason: 'divergence sur $v');
      expect(ancienDefautFaux(v), actifEnLigne(v), reason: 'divergence sur $v');
    }

    expect(actifEnLigne(null), isTrue);
    expect(ancienEgalTrue(null), isFalse);
    expect(ancienDefautFaux(null), isFalse);
  });

  test('même sémantique que actifOffline, deux chemins de données distincts',
      () {
    // Les deux fonctions répondent la même chose : c'est voulu, la doctrine est
    // une — l'absence rend le défaut de la colonne. Ce qui diffère est la CAUSE
    // de l'absence (écriture locale PowerSync vs projection PostgREST), le type
    // reçu (`int?` vs `bool?`) et le garde-fou qui les surveille. Les fondre
    // sous un seul nom rendrait invisible le chemin sur lequel on se trouve, et
    // c'est cette confusion qui a produit les trois sémantiques.
    for (final v in <Object?>[null, true, false, 0, 1]) {
      expect(actifEnLigne(v), actifOffline(v), reason: 'divergence sur $v');
    }
  });
}
