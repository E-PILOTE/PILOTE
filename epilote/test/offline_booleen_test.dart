import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  `is_active = 1` NE DOIT PLUS JAMAIS ÊTRE ÉCRIT.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  Dans une vue PowerSync locale, `WHERE is_active = 1` retrouve les lignes
//  venues du serveur mais PAS celles que l'application vient d'insérer
//  elle-même. Diagnostiqué en août 2026 sur `ps_data__classes` : la reconduction
//  des classes créait bien les classes de l'année suivante, et l'écran Passage
//  annonçait juste après « les classes de 2026-2027 n'existent pas encore ».
//  « Réinscrire » restait grisé pour toujours.
//
//  Le même filtre courait encore sur `students`. Là, il ne grise pas un bouton :
//  il fait disparaître un enfant. L'inscription se saisit hors ligne, elle
//  s'affiche dans le pipeline — qui joint `students` sans filtre — le chef la
//  valide, et l'élève n'apparaît jamais dans la liste des Élèves. Pendant ce
//  temps les compteurs, qui lisent `class_enrollments`, en annoncent un de
//  plus : 61 dans la liste, 62 dans le tableau de bord.
//
//  ── POURQUOI UN TEST SUR LE TEXTE SOURCE ───────────────────────────────────
//  Parce que le bug ne se reproduit PAS en dehors du moteur SQLite de PowerSync.
//  Requêter le fichier `epilote_v3.db` en sqlite3 rend la bonne valeur ; c'est
//  la vue qui diverge. Aucun test unitaire ordinaire ne peut donc l'attraper, et
//  la seule défense qui tienne à l'échelle du dépôt est d'interdire la FORME.
//
//  La forme sûre est `COALESCE(is_active, 1) <> 0`. Sur une ligne venue du
//  serveur elle ne change rien — la colonne est NOT NULL DEFAULT true en base,
//  le COALESCE ne se déclenche jamais. Elle ne rattrape que l'écriture locale.
//
//  ── CE QUE CE TEST NE GARDE PAS, ET POURQUOI ───────────────────────────────
//  Les booléens dont la valeur par défaut est FAUSSE (`is_repeating`,
//  `is_primary_contact`, `is_published`, `is_current`, `is_read`) ne peuvent pas
//  être rattrapés de cette façon : `COALESCE(x, 0) <> 0` rend faux pour une
//  valeur absente, exactement comme l'égalité stricte. Les couvrir ici donnerait
//  l'illusion d'une protection qui n'existe pas. Ils restent à vérifier sur un
//  poste réel — voir le rapport d'audit, note F1.
// ════════════════════════════════════════════════════════════════════════════

/// `is_active` comparé par égalité stricte, hors chaîne de commentaire.
final _formeInterdite = RegExp(r'is_active\s*=\s*1\b');

/// Une LECTURE Dart de la colonne : `map['is_active']`, `r["is_active"]`.
///
/// ⚠️ On vise la lecture, pas la comparaison. Une première version de ce garde
/// ne cherchait que `== 1` / `== true` — et laissait passer `_b(map[
/// 'is_active'])`, qui a la même sémantique fautive avec l'indirection en plus.
/// Six modèles de `data/models/` s'y trouvaient. Interdire la comparaison ne
/// suffit pas : il faut EXIGER la forme sûre.
///
/// Une écriture (`{'is_active': 1}`) n'est pas concernée : elle s'écrit avec
/// deux points, pas avec des crochets.
final _lectureDart = RegExp(r"""\[\s*['"]is_active['"]\s*\]""");

/// Les idiomes qui rendent « inactif » ce qui n'est que « non renseigné ».
///
/// La forme sûre est `actifOffline(...)` (`core/utils/booleen_offline.dart`) ;
/// `?? true`, `!= false` et `?? 1` disent la même chose et restent tolérés,
/// parce que les interdire imposerait une réécriture sans corriger un défaut.
final _idiomesFautifs = [
  RegExp(r'\b_b\s*\('),
  RegExp(r'\bvraiOffline\s*\('),
  RegExp(r'==\s*1\b'),
  RegExp(r'==\s*true\b'),
  RegExp(r'\?\?\s*0\b'),
  RegExp(r'\?\?\s*false\b'),
];

/// Une ligne de commentaire Dart (`//`) ou SQL (`--`), éventuellement indentée.
/// Les commentaires ont le droit de CITER la forme fautive : c'est même ainsi
/// qu'ils expliquent pourquoi elle est proscrite.
bool _estCommentaire(String ligne) {
  final t = ligne.trimLeft();
  return t.startsWith('//') || t.startsWith('--') || t.startsWith('*');
}

/// Les deux espaces qui lisent Supabase EN DIRECT, où `is_active` arrive en
/// `bool` depuis une colonne `NOT NULL` — la nullité offline n'y existe pas.
/// C'est la règle centrale d'architecture du projet, pas une exception de
/// confort : `super_admin` et `admin_groupe` n'utilisent pas PowerSync.
bool _estEspaceEnLigne(String chemin) {
  final p = chemin.replaceAll(r'\', '/');
  return p.contains('/features/super_admin/') ||
      p.contains('/features/admin_groupe/');
}

void main() {
  test('aucune requête offline ne compare is_active par égalité stricte', () {
    final racine = Directory('lib');
    expect(racine.existsSync(), isTrue,
        reason: 'Ce test doit tourner depuis le dossier `epilote/`.');

    final fautes = <String>[];

    for (final f in racine
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (_estCommentaire(l)) continue;
        if (_formeInterdite.hasMatch(l)) {
          fautes.add('${f.path}:${i + 1} → ${l.trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Ces requêtes rateront les lignes écrites hors ligne par '
          'l\'application. Remplacer par `COALESCE(is_active, 1) <> 0` :\n'
          '${fautes.join('\n')}',
    );
  });

  test('aucun mappeur Dart ne lit is_active comme un booléen par défaut faux',
      () {
    // ⚠️ Le trou par lequel le défaut est passé DEUX fois : la garde SQL ne
    // regarde pas `r['is_active'] == 1`, et la première version de CE test ne
    // regardait pas `_b(map['is_active'])`. Même sémantique fautive, trois
    // écritures. On vise donc la LECTURE de la colonne, pas ses comparaisons.
    //
    // ⚠️ Ce test ne couvre QUE les lectures OFFLINE, où la valeur arrive du
    // SQLite de PowerSync en `int?` et peut donc être nulle. Les deux espaces
    // en ligne — `super_admin` et `admin_groupe` — lisent Supabase en direct
    // (cf. la règle centrale d'architecture) et reçoivent un vrai `bool` d'une
    // colonne `NOT NULL` : le COALESCE n'y a rien à rattraper.
    //
    // ⚠️ Ils ne sont pas exempts de tout reproche pour autant : `school_groups
    // .is_active` s'y lisait sous TROIS formes différentes (`== true`,
    // `as bool? ?? true`, `as bool? ?? false`), dont deux dans le même fichier.
    // Unifié sur `actifEnLigne()` — la colonne est `NOT NULL DEFAULT TRUE`,
    // l'absence vaut donc « actif ». Le garde-fou correspondant est le test
    // « aucun compteur en ligne ne rend inactif un is_active absent » ci-dessous
    // ; il ne peut pas être fondu dans celui-ci, dont la forme sûre (`COALESCE`,
    // `actifOffline`) ne s'applique pas au chemin en ligne.
    final fautes = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_estEspaceEnLigne(f.path))) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (_estCommentaire(l)) continue;
        if (!_lectureDart.hasMatch(l)) continue;
        if (_idiomesFautifs.any((r) => r.hasMatch(l))) {
          fautes.add('${f.path}:${i + 1} → ${l.trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Ces lectures rendront « inactif » ce qui n\'est que « non '
          'renseigné ». Remplacer par `actifOffline(...)` '
          '(`core/utils/booleen_offline.dart`) :\n${fautes.join('\n')}',
    );
  });

  test('aucun compteur en ligne ne rend inactif un is_active absent', () {
    // ── CE QUE CE TEST GARDE ────────────────────────────────────────────────
    // Les deux espaces en ligne lisaient `school_groups.is_active` sous trois
    // formes, dont `g['is_active'] == true` pour le compteur « groupes actifs »
    // du tableau de bord de l'opérateur. La colonne étant `NOT NULL DEFAULT
    // TRUE`, aucune ligne NULL n'existe et les trois formes s'accordaient sur
    // la donnée réelle : rien ne se voyait sur aucun écran.
    //
    // Le null arrive par l'autre porte. `map['is_active']` rend `null` aussi
    // quand la colonne n'est pas dans le `select()` — ce qui est déjà arrivé au
    // dépôt (le bucket `directory` ne projetait aucune colonne de carrière). Ce
    // jour-là, `== true` annonce « 0 groupe actif » sans erreur ni ligne
    // manquante. La forme sûre est `actifEnLigne(...)`
    // (`core/utils/booleen_en_ligne.dart`), qui rend le défaut de la colonne.
    //
    // ── POURQUOI CE GARDE-FOU NE VISE QUE `== true` ─────────────────────────
    // Parce que `?? false` est JUSTE pour les colonnes dont le défaut est faux —
    // `payment_configs.is_active` est `NOT NULL DEFAULT FALSE` (« activé
    // seulement après configuration complète »), et deux lectures de ces
    // espaces la lisent légitimement ainsi. Interdire `?? false` en bloc ici
    // rendrait le test faux plutôt que le dépôt sûr. `== true`, en revanche,
    // n'est la bonne forme pour aucun défaut : vrai, il perd l'absence ; faux,
    // il s'écrit `?? false`.
    final fautes = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => _estEspaceEnLigne(f.path))) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (_estCommentaire(l)) continue;
        if (!_lectureDart.hasMatch(l)) continue;
        if (RegExp(r'==\s*true\b').hasMatch(l)) {
          fautes.add('${f.path}:${i + 1} → ${l.trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Ces compteurs annonceront « 0 actif » le jour où un `select()` '
          'cessera de projeter la colonne. Remplacer par `actifEnLigne(...)` '
          '(`core/utils/booleen_en_ligne.dart`) :\n${fautes.join('\n')}',
    );
  });

  test('la forme sûre en ligne est réellement employée', () {
    // Symétrique des deux garde-fous offline : une règle qui n'interdit qu'une
    // forme se satisfait d'un dépôt qui a cessé de lire la colonne.
    var occurrences = 0;
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => _estEspaceEnLigne(f.path))) {
      occurrences +=
          RegExp(r'actifEnLigne\s*\(').allMatches(f.readAsStringSync()).length;
    }
    expect(occurrences, greaterThanOrEqualTo(5),
        reason: 'La forme sûre a disparu des espaces en ligne : les lectures '
            'ont été réécrites à la main plutôt qu\'unifiées.');
  });

  test('la forme sûre est employée là où is_active se lit en Dart', () {
    // Symétrique du garde-fou SQL : une règle qui n'interdit que des formes se
    // satisfait d'un dépôt qui a cessé de lire la colonne. On vérifie donc que
    // `actifOffline` est réellement à l'œuvre.
    var occurrences = 0;
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      occurrences +=
          RegExp(r'actifOffline\s*\(').allMatches(f.readAsStringSync()).length;
    }
    expect(occurrences, greaterThanOrEqualTo(9),
        reason: 'La forme sûre a disparu : le mappeur a été retiré plutôt que '
            'corrigé, ou le sweep a été défait.');
  });

  test('la forme sûre est bien celle qui est employée', () {
    // Un garde-fou qui n\'interdit qu\'une forme se satisfait d\'un fichier
    // vide. On vérifie donc que la forme SÛRE est réellement présente, et
    // largement — sinon le premier test ne prouve rien.
    var occurrences = 0;
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      occurrences +=
          RegExp(r'COALESCE\(\s*\w*\.?is_active\s*,\s*1\s*\)\s*<>\s*0')
              .allMatches(f.readAsStringSync())
              .length;
    }
    expect(occurrences, greaterThanOrEqualTo(20),
        reason: 'La forme sûre a disparu du dépôt : le filtre a été retiré '
            'plutôt que corrigé, ou le sweep a été défait.');
  });
}
