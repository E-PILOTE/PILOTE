import 'dart:io';

import 'package:epilote/core/constants/app_constants.dart';
import 'package:epilote/core/constants/socle_natif.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE DISPENSE QUI S'APPUIE SUR UNE GARDE INEXISTANTE
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-09-09 ────────────────────────────────────────
//  Trois pages de l'espace école ne sont pas des modules du catalogue : le
//  Calendrier scolaire, les Rapports de direction et le Journal d'audit. Elles
//  échappent donc au verrou 3 (profil d'accès), et `toute_page_ecole_est_un_
//  module_test` leur accorde une dispense écrite, chacune avec sa raison :
//
//      '/user/journal-audit':
//          'Journal de direction (online). Gardé par le rôle, pas par un module.'
//
//  Cette phrase était FAUSSE. La sidebar masquait bien l'entrée aux autres
//  rôles (`nav_config.dart`, bloc `ZoneNav.etablissement`), mais le `redirect`
//  de `app_router.dart` ne nommait que `calendrier` et `userRapports`. Taper
//  l'URL ouvrait à n'importe quel agent — enseignant, surveillant, élève — le
//  journal de TOUTE l'école : qui a modifié quelle note, encaissé quel
//  paiement, touché à quel dossier du personnel.
//
//  Une barre de navigation n'est pas un verrou : elle ne garde que le chemin
//  qu'on a prévu. C'est la leçon déjà tirée pour `/user/passage` — un bouton
//  gardé ne garde pas la page.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  Il confronte TROIS fichiers qui doivent dire la même chose, et qu'on
//  n'édite jamais ensemble :
//    • `socle_natif.dart`  — quelles entrées sont « configs de direction » ;
//    • `app_router.dart`   — quelles routes le `redirect` réserve à la
//                            direction ;
//    • `toute_page_ecole_est_un_module_test.dart` — quelles dispenses
//                            invoquent le rôle comme garde.
//
//  Le test ne prononce pas de politique : il refuse la DIVERGENCE. Ajouter une
//  page de direction sans la garder, ou la garder sans le dire, échoue ici.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Les routes que le `redirect` réserve aux `directionRoles`.
///
/// Lu à la source plutôt que recopié : une liste recopiée cesse de parler des
/// écrans écrits après elle.
Set<String> _routesGardeesParLeRole() {
  final src = _lire('lib/core/router/app_router.dart');
  final bloc = RegExp(
    r'if \(((?:\s*loc == Routes\.\w+\s*\|\|?)*\s*loc == Routes\.\w+)\)\s*\{\s*'
    r'if \(!AppConstants\.directionRoles\.contains\(role\)\)',
    dotAll: true,
  ).firstMatch(src);
  if (bloc == null) {
    fail('Le garde « directionRoles » du routeur est introuvable. Il a été '
        'renommé, déplacé ou supprimé : ce test passerait à vide, ce qui est '
        'pire que rouge.');
  }
  return {
    for (final m in RegExp(r'Routes\.(\w+)').allMatches(bloc.group(1)!))
      m.group(1)!,
  };
}

/// Les dispenses de `toute_page_ecole_est_un_module_test` dont la raison
/// invoque le RÔLE comme garde.
Set<String> _dispensesQuiInvoquentLeRole() {
  final src = _lire('test/toute_page_ecole_est_un_module_test.dart');
  final debut = src.indexOf('_routesNativesJustifiees = {');
  expect(debut, greaterThan(-1),
      reason: 'La table des dispenses a été renommée.');
  final fin = src.indexOf('\n};', debut);
  final bloc = src.substring(debut, fin);
  final out = <String>{};
  for (final m
      in RegExp(r"'(/user/[^']+)':\s*\n?\s*'([^']*)'", dotAll: true)
          .allMatches(bloc)) {
    final raison = m.group(2)!.toLowerCase();
    if (raison.contains('rôle') || raison.contains('role')) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

/// Le chemin de chaque entrée native rangée dans le bloc « direction ».
Set<String> _entreesDeDirection() => {
      for (final e in socleDe(EspaceNav.etablissement, ZoneNav.etablissement))
        e.places[EspaceNav.etablissement]!.route,
    };

void main() {
  group('Les pages de direction sont gardées par le routeur', () {
    test('la lecture des trois sources aboutit (le test ne se vide pas)', () {
      expect(_routesGardeesParLeRole().length, greaterThanOrEqualTo(2));
      expect(_dispensesQuiInvoquentLeRole(), isNotEmpty);
      expect(_entreesDeDirection(), isNotEmpty);
      expect(AppConstants.directionRoles, isNotEmpty);
    });

    test('le Journal d\'audit est gardé — le défaut du 2026-09-09', () {
      expect(
        _routesGardeesParLeRole(),
        contains('userAudit'),
        reason: '`/user/journal-audit` lit le journal de TOUTE l\'école. La '
            'sidebar le masque aux autres rôles, mais la sidebar n\'est pas '
            'un verrou : sans cette ligne dans le `redirect`, l\'URL tapée à '
            'la main ouvre à un enseignant qui a touché à quelle note, à quel '
            'paiement, à quel dossier du personnel.',
      );
    });

    test('toute dispense « gardée par le rôle » l\'est vraiment', () {
      final gardees = _routesGardeesParLeRole()
          .map((nom) => _cheminDe(nom))
          .whereType<String>()
          .toSet();
      final promises = _dispensesQuiInvoquentLeRole();
      final menteuses = promises.difference(gardees);
      expect(
        menteuses,
        isEmpty,
        reason: 'Ces routes sont dispensées de verrou de module au motif '
            'qu\'elles sont « gardées par le rôle », et le `redirect` de '
            '`app_router.dart` ne les nomme pas : ${menteuses.join(', ')}.\n'
            'Deux issues, une seule est un choix : ajouter la route au garde '
            'des `directionRoles`, ou réécrire sa raison pour qu\'elle dise ce '
            'qui la protège réellement.',
      );
    });

    test('toute entrée du bloc « direction » de la barre est gardée', () {
      final gardees = _routesGardeesParLeRole()
          .map((nom) => _cheminDe(nom))
          .whereType<String>()
          .toSet();
      final nues = _entreesDeDirection().difference(gardees);
      expect(
        nues,
        isEmpty,
        reason: 'Ces entrées sont rangées dans le bloc réservé à la direction '
            '(`ZoneNav.etablissement`, masqué aux autres rôles par '
            '`nav_config.dart`) mais le routeur les laisse passer : '
            '${nues.join(', ')}.\nMasquer un lien n\'empêche pas d\'atteindre '
            "la page — c'est la leçon de `/user/passage`.",
      );
    });
  });
}

/// Le chemin derrière un nom de constante de `Routes`, lu à la source.
String? _cheminDe(String nom) {
  final src = _lire('lib/core/constants/routes.dart');
  final m = RegExp("static\\s+const\\s+String\\s+$nom\\s*=\\s*'([^']*)'")
      .firstMatch(src);
  return m?.group(1);
}
