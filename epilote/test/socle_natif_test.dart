import 'dart:io';

import 'package:epilote/core/constants/socle_natif.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE PAGE NATIVE N'EST PAS UN MODULE VENDABLE
//
//  ── LE DÉFAUT DU 2026-09-03 ───────────────────────────────────────────────
//  La base portait `annonces`, `messagerie` et `evenements` comme MODULES,
//  accordés aux cinq profils d'accès. La sidebar du personnel construit ses
//  sections DEPUIS LA BASE et ajoutait la section native par-dessus : chaque
//  agent voyait DEUX sections « COMMUNICATION », « Messagerie » deux fois, et
//  les entrées venues de la base menaient à `/user/m/<slug>` — l'hôte des
//  modules pas encore bâtis. Un clic ouvrait une page vide.
//
//  Ce n'était pas une faute d'écran : le modèle se contredisait. Un canal
//  « jamais vendu, non désactivable » figurait au catalogue vendable, donc
//  coupable par un plan, un profil, ou un impayé.
//
//  ── CE QUE CES TESTS PROTÈGENT ────────────────────────────────────────────
//  1. Les DEUX listes de slugs réservés — celle de Dart et celle du
//     déclencheur SQL — doivent rester identiques. C'est exactement le genre de
//     paire qui diverge, et la divergence ne se verrait qu'à l'écran.
//  2. Le socle doit rester la SEULE déclaration : dès qu'une entrée native est
//     réécrite à la main dans une barre, les deux copies recommencent à
//     dériver (« Messages » d'un côté, « Messagerie » de l'autre).
// ════════════════════════════════════════════════════════════════════════════

const _migration = '../database/migrations/'
    '0177_AVANT_LE_BUILD_le_socle_natif_nest_pas_vendable.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le SQL débarrassé de ses commentaires.
///
/// ⚠️ INDISPENSABLE. L'en-tête de la migration cite les slugs une dizaine de
/// fois, et le français y met des apostrophes (« n'a », « l'écran ») que le
/// motif de chaîne SQL prendrait pour des quotes. Deux sondes de ce dépôt sont
/// déjà tombées pour avoir lu la prose au lieu du code.
String _sansCommentaires(String sql) => sql
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('--'))
    .join('\n');

Set<String> _chaines(String fragment) =>
    RegExp("'([^']+)'").allMatches(fragment).map((m) => m.group(1)!).toSet();

void main() {
  group('Les deux listes ne divergent pas', () {
    final sql = _sansCommentaires(_lire(_migration));

    test('le déclencheur SQL réserve EXACTEMENT les mêmes slugs que Dart', () {
      final m = RegExp(r'SELECT ARRAY\[([^\]]+)\]').firstMatch(sql);
      expect(m, isNotNull,
          reason: 'La fonction `slugs_natifs()` a changé de forme : cette '
              'sonde ne surveille plus rien.');

      expect(_chaines(m!.group(1)!), kSlugsReserves,
          reason: 'La liste SQL et la liste Dart ont divergé. C\'est cette '
              'divergence-là qui laisse une page native redevenir un module — '
              'et le doublon revient chez tous les agents.');
    });

    test('le contrôle d’entrée de la migration couvre la même liste', () {
      // Le bloc DO refuse de passer si un module ACTIF occupe déjà un slug
      // réservé. S'il en oubliait un, la migration passerait et le déclencheur
      // bloquerait plus tard une mise à jour anodine, sans rapport apparent.
      final m = RegExp(r'slug IN \(([^)]+)\)').firstMatch(sql);
      expect(m, isNotNull, reason: 'Le contrôle d’entrée a disparu.');
      expect(_chaines(m!.group(1)!), kSlugsReserves);
    });

    test('un verrou empêche la réactivation', () {
      // Sans lui, la correction ne tient que jusqu'au prochain qui recoche la
      // case dans l'écran des modules. Le déclencheur lui-même vient de 0176 ;
      // 0177 ne réécrit que la fonction qu'il appelle.
      final avant = _sansCommentaires(_lire('../database/migrations/'
          '0176_AVANT_LE_BUILD_un_canal_natif_nest_pas_un_module_vendable.sql'));
      expect(avant.contains('CREATE TRIGGER trg_module_pas_un_canal_natif'),
          isTrue);
      expect(avant.contains('BEFORE INSERT OR UPDATE OF is_active, slug'), isTrue,
          reason: 'Le verrou doit couvrir l’INSERT autant que l’UPDATE : on '
              'peut recréer le module au lieu de le rallumer.');
      expect(sql.contains('public.slugs_natifs()'), isTrue,
          reason: 'La fonction du déclencheur doit lire la NOUVELLE liste.');
    });
  });

  group('Le socle se tient', () {
    test('chaque entrée mène quelque part', () {
      expect(kSocleNatif, isNotEmpty);
      for (final e in kSocleNatif) {
        expect(e.places, isNotEmpty,
            reason: '« ${e.libelle} » n’apparaît dans aucun espace.');
        for (final place in e.places.values) {
          expect(place.route, startsWith('/'),
              reason: '« ${e.libelle} » a une route vide ou relative.');
        }
      }
    });

    test('aucun libellé, aucune route en double', () {
      final libelles = kSocleNatif.map((e) => e.libelle).toList();
      expect(libelles.toSet().length, libelles.length,
          reason: 'Deux entrées natives portent le même nom : `sans:` en '
              'retirerait deux d’un coup, silencieusement.');

      for (final espace in EspaceNav.values) {
        final routes = [
          for (final e in kSocleNatif)
            if (e.places[espace] != null) e.places[espace]!.route
        ];
        expect(routes.toSet().length, routes.length,
            reason: 'Deux entrées mènent au même écran dans $espace.');
      }
    });

    test('on ne réserve un slug que là où un module pourrait le doubler', () {
      // Seule la barre du personnel se construit depuis la base. Réserver un
      // slug pour une entrée que seul un cabinet de groupe voit n'empêcherait
      // rien et retirerait un nom du catalogue sans raison.
      for (final e in kSocleNatif) {
        if (e.slug == null) continue;
        expect(e.places.containsKey(EspaceNav.etablissement), isTrue,
            reason: '« ${e.libelle} » réserve « ${e.slug} » alors qu’elle '
                'n’apparaît pas dans la barre du personnel.');
      }
    });

    test('les zones rendent les entrées dans l’ordre de déclaration', () {
      // L'ordre de la liste EST l'ordre à l'écran : c'est le contrat du
      // fichier, et il se casse sans bruit.
      final systeme = socleDe(EspaceNav.groupe, ZoneNav.systeme);
      expect(systeme.map((e) => e.libelle),
          ['Tickets', "Journal d'audit", 'Paramètres']);

      // La MÊME page change de bloc en changeant d'espace : côté école,
      // l'audit est une config de direction, pas un outil offert à tout agent.
      expect(socleDe(EspaceNav.etablissement, ZoneNav.systeme).map((e) => e.libelle),
          ['Tickets', 'Paramètres']);
      expect(
          socleDe(EspaceNav.etablissement, ZoneNav.etablissement)
              .map((e) => e.libelle),
          ['Calendrier scolaire', 'Rapports', "Journal d'audit"]);
    });

    test('la sauvegarde des mineurs retire la messagerie aux élèves', () {
      final avec = socleDe(EspaceNav.etablissement, ZoneNav.communication);
      final sans = socleDe(EspaceNav.etablissement, ZoneNav.communication,
          sans: {'Messagerie'});
      expect(avec.map((c) => c.libelle), contains('Messagerie'));
      expect(sans.map((c) => c.libelle), isNot(contains('Messagerie')));
      expect(sans.map((c) => c.libelle), contains('Annonces & Agenda'),
          reason: 'Le filtre ne doit retirer QUE ce qu’on lui nomme.');
    });

    test('« & Agenda » n’est pas décoratif', () {
      // L'agenda est un ONGLET de l'écran d'annonces
      // (`StaffAnnouncementsScreen(initialTab: 1)`), pas une page à part. Le
      // module `evenements` prétendait le contraire et menait à une coquille —
      // son slug reste donc réservé, sans porter de ligne de menu.
      expect(kSocleNatif.first.libelle, 'Tableau de bord');
      expect(kSlugsSansEntree, contains('evenements'));
      expect(kSocleNatif.any((e) => e.slug == 'evenements'), isFalse);
      final router = _lire('lib/core/router/app_router.dart');
      expect(router.contains('StaffAnnouncementsScreen(initialTab: 1)'), isTrue);
    });
  });

  group('Une seule déclaration pour les deux espaces', () {
    final nav = _lire('lib/core/widgets/app_shell/nav_config.dart');

    test('les deux barres dérivent du socle', () {
      for (final espace in EspaceNav.values) {
        final nom = espace.name;
        expect(RegExp('_entreesNatives\\(\\s*EspaceNav\\.$nom').hasMatch(nav),
            isTrue,
            reason: 'L’espace $nom ne dérive plus ses entrées du socle.');
      }
    });

    test('aucune entrée native n’est réécrite à la main', () {
      // Elles l'étaient DEUX fois — une par espace — et avaient déjà divergé.
      // ⚠️ On cible `route: Routes.x`, la ligne CONSTRUITE, jamais un
      // identifiant cité dans un commentaire.
      for (final route in const [
        'Routes.adminDashboard',
        'Routes.userDashboard',
        'Routes.adminTutelle',
        'Routes.adminAnnonces',
        'Routes.adminMessagerie',
        'Routes.annonces',
        'Routes.messagerie',
        'Routes.espaceParent',
        'Routes.adminSupport',
        'Routes.userSupport',
        'Routes.adminAudit',
        'Routes.userAudit',
        'Routes.adminParametres',
        'Routes.userParametres',
        'Routes.calendrier',
        'Routes.userRapports',
      ]) {
        expect(nav.contains('route: $route'), isFalse,
            reason: '$route est réécrit en dur dans la barre.');
      }
    });
  });
}
