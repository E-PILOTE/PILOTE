import 'dart:io';

import 'package:epilote/core/widgets/app_shell/nav_models.dart';
import 'package:epilote/core/widgets/app_shell/nav_repli_prefs.dart';
import 'package:epilote/core/widgets/app_shell/shell_providers.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REPLI DE LA BARRE : DEUX DÉFAUTS CORRIGÉS ENSEMBLE
//
//  ── 1. ÉPINGLÉ N'EST PAS FIGÉ ─────────────────────────────────────────────
//  La barre posait `repliable = titrée && !épinglée`. Une seule ligne, deux
//  questions distinctes réunies par commodité :
//
//    « où la section est-elle rendue ? »  → épinglée = en bas, hors défilement
//    « peut-on masquer ses entrées ? »    → repliable
//
//  Rien ne les lie. COMMUNICATION et SYSTÈME doivent rester en bas — une école
//  qu'on ne peut plus joindre parce que le canal est passé sous la ligne de
//  flottaison est une école coupée — ET doivent pouvoir se replier, parce
//  qu'un agent qui n'écrit pas aujourd'hui préfère rendre ces lignes à ses
//  modules. Toute section TITRÉE se replie désormais ; le bloc de tête n'a pas
//  de titre, donc « Tableau de bord » reste indéracinable.
//
//  ── 2. UN RÉGLAGE QU'IL FAUT REFAIRE N'EST PAS UN RÉGLAGE ────────────────
//  L'état vivait dans un `StateProvider` en mémoire : replier FINANCE tenait
//  jusqu'à la fermeture de l'application. Il est maintenant écrit sur le
//  disque, et **par agent** — sur un poste partagé d'établissement, celui qui
//  replie une section ne la replie pas pour le collègue qui prend sa place.
//
//  ── POURQUOI UNE FONCTION ET UN FICHIER DE PRÉFÉRENCES ───────────────────
//  À leur place d'origine — une ligne dans `build()`, un `StateProvider` nu —
//  ni la règle ni la persistance n'étaient vérifiables sans rendre toute la
//  barre. `sidebar_hardlock_test.dart` le fait, mais pour une autre question
//  (le cadenas d'abonnement) : il ne dit rien du repli, et il est tombé le
//  jour où la persistance a été branchée. Les deux tiennent maintenant sans
//  écran — et le dernier groupe ci-dessous garde ce qu'il a appris.
// ════════════════════════════════════════════════════════════════════════════

const _entree = NavEntry.item(
  icon: Icons.forum_rounded,
  label: 'Messagerie',
  route: '/user/messagerie',
);

NavSection _section({String titre = 'COMMUNICATION', bool pinned = false}) =>
    NavSection(title: titre, pinned: pinned, entries: const [_entree]);

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('La règle de repli', () {
    test('une section titrée qui défile se replie', () {
      expect(sectionEstRepliable(_section(), expanded: true), isTrue);
    });

    test('une section ÉPINGLÉE se replie aussi', () {
      // C'est le changement : COMMUNICATION et SYSTÈME restent en bas, hors
      // défilement, et se replient comme n'importe quelle catégorie.
      expect(
          sectionEstRepliable(_section(pinned: true), expanded: true), isTrue);
    });

    test('sans titre, il n’y a pas d’en-tête à cliquer', () {
      // Le bloc de tête (« Tableau de bord » seul) n'a pas de titre : lui
      // donner un chevron reviendrait à proposer de masquer la seule entrée
      // toujours visible de la barre.
      expect(sectionEstRepliable(_section(titre: ''), expanded: true), isFalse);
      expect(
          sectionEstRepliable(_section(titre: '', pinned: true),
              expanded: true),
          isFalse);
    });

    test('en mode icônes, aucune section ne se replie', () {
      // La barre réduite ne rend pas les en-têtes : un repli y serait
      // déclenchable sans que rien ne l'annonce, et invisible une fois fait.
      for (final s in [_section(), _section(pinned: true)]) {
        expect(sectionEstRepliable(s, expanded: false), isFalse);
      }
    });
  });

  group('Le repli survit à la fermeture', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('ce qu’on replie se relit tel quel', () async {
      await saveSectionsRepliees('agent-1', {'COMMUNICATION', 'FINANCE'});
      expect(await loadSectionsRepliees('agent-1'),
          {'COMMUNICATION', 'FINANCE'});
    });

    test('déplier tout revient bien à un ensemble vide', () async {
      // Le piège du « défaut = vide » : si l'écriture d'un ensemble vide
      // n'écrasait pas la valeur précédente, rouvrir toutes ses sections ne
      // tiendrait pas jusqu'au lancement suivant.
      await saveSectionsRepliees('agent-1', {'FINANCE'});
      await saveSectionsRepliees('agent-1', <String>{});
      expect(await loadSectionsRepliees('agent-1'), isEmpty);
    });

    test('un agent ne replie pas la barre de son collègue', () async {
      // Poste partagé d'établissement : même écran, même session Supabase,
      // deux agents. Le repli suit l'agent au clavier, comme le thème.
      await saveSectionsRepliees('agent-1', {'FINANCE'});
      expect(await loadSectionsRepliees('agent-2'), isEmpty);
    });

    test('sans agent, on n’écrit rien plutôt que d’écrire au hasard', () async {
      // Mieux vaut perdre la préférence que la coller au mauvais agent.
      await saveSectionsRepliees(null, {'FINANCE'});
      await saveSectionsRepliees('', {'FINANCE'});
      expect(await loadSectionsRepliees(null), isEmpty);
      expect(await loadSectionsRepliees(''), isEmpty);
    });

    test('une préférence absente rend tout déplié', () async {
      // Fail-soft : une barre qui s'ouvre trop est un désagrément ; une barre
      // qui masque une section sans qu'on sache pourquoi est un défaut.
      expect(await loadSectionsRepliees('jamais-vu'), isEmpty);
    });
  });

  group('Une préférence ne casse pas la navigation', () {
    test('agent introuvable → barre dépliée, pas d’exception', () {
      // ⚠️ CE CAS EST ARRIVÉ. `activeAgentIdProvider` remonte jusqu'à
      // `supabaseClientProvider`, qui lève tant que Supabase n'est pas
      // initialisé. En branchant la persistance, les trois tests d'écran de
      // `sidebar_hardlock_test.dart` sont tombés d'un coup : la barre entière
      // ne se rendait plus parce qu'un réglage d'affichage n'arrivait pas à
      // savoir qui était au clavier.
      final container = ProviderContainer(overrides: [
        activeAgentIdProvider
            .overrideWith((_) => throw StateError('Supabase non initialisé')),
      ]);
      addTearDown(container.dispose);

      expect(container.read(collapsedNavSectionsProvider), isEmpty);
    });
  });

  group('Ce que la barre déclare', () {
    test('elle lit la règle au lieu de la réécrire', () {
      final barre = _lire('lib/core/widgets/app_shell/app_sidebar.dart');
      expect(barre.contains('sectionEstRepliable(section, expanded: expanded)'),
          isTrue,
          reason: 'La règle est retournée dans le `build()` : elle redevient '
              'invisible aux tests.');
    });

    test('un clic passe par le notifier, qui écrit sur le disque', () {
      final barre = _lire('lib/core/widgets/app_shell/app_sidebar.dart');
      expect(barre.contains('.basculer(section.title)'), isTrue,
          reason: 'La barre mute de nouveau l’état à la main : le repli ne '
              'serait plus persisté.');

      final providers = _lire('lib/core/widgets/app_shell/shell_providers.dart');
      expect(
          providers.contains(
              'NotifierProvider<SectionsRepliees, Set<String>>'),
          isTrue,
          reason: 'Le provider est redevenu un `StateProvider` nu : plus '
              'personne n’enregistre le repli.');
      expect(providers.contains('activeAgentIdProvider'), isTrue,
          reason: 'La clé ne suit plus l’agent : sur un poste partagé, le '
              'repli de l’un s’imposerait à l’autre.');
    });
  });
}
