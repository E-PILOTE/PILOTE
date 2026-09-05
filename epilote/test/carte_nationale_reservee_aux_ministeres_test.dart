import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'ecran_tableau_de_bord_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CARTE NATIONALE EST UN OUTIL DE TUTELLE, PAS UN OUTIL DE CLIENT
//
//  ── CE QU'UN GROUPE PRIVÉ VOYAIT (2026-09-04) ─────────────────────────────
//  Le second onglet du tableau de bord — « Vue régionale » — dessine les DOUZE
//  DÉPARTEMENTS du Congo, les villes réelles (OSM) et une analyse territoriale
//  des distances. C'est la carte de couverture d'un ministère qui supervise un
//  parc national. Elle s'affichait pour TOUT admin de groupe : un réseau privé
//  de deux écoles y voyait le pays entier avec deux épingles dessus.
//
//  ── ET LE COÛT INVISIBLE ──────────────────────────────────────────────────
//  Les trois jeux GeoJSON nationaux (frontière, départements, localités) se
//  pré-chargeaient à CHAQUE ouverture du tableau de bord, pour tout le monde,
//  sur des connexions congolaises. Masquer l'onglet sans couper ce
//  pré-chargement aurait déplacé le problème là où plus personne ne le voit.
//
//  ⚠️ « Vue Nationale » (majuscule) est l'onglet du FONDATEUR, dans l'espace
//  super_admin. Elle n'est pas concernée : c'est son métier de voir le pays.
// ════════════════════════════════════════════════════════════════════════════

const _drapeaux =
    'lib/features/admin_groupe/providers/referentiel_national_provider.dart';
const _dashboardFondateur =
    'lib/features/super_admin/screens/super_dashboard_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Un groupe privé n’a pas la carte du pays', () {
    test('l’onglet n’existe que pour un ministère', () {
      final src = sourceTableauDeBord();
      expect(src.contains('if (estMinistere) _DashTabs(tab: tab),'), isTrue,
          reason: 'La barre d’onglets est revenue pour tout le monde : un '
              'client privé retrouve la carte nationale.');
    });

    test('⚠️ et le contenu suit, pas seulement l’onglet', () {
      // Masquer la pastille en laissant l'onglet 1 actif afficherait la carte
      // à un client qui l'avait ouverte avant la mise à jour : l'état de
      // l'onglet survit au redémarrage.
      final src = sourceTableauDeBord();
      expect(src.contains('final surLaCarte = estMinistere && tab == 1;'),
          isTrue,
          reason: 'Le contenu ne dépend plus du rôle : un onglet déjà '
              'sélectionné rouvre la carte.');
      expect(src.contains('surLaCarte ? const _RegionalTab()'), isTrue);
    });

    test('⚠️ le pré-chargement géographique est coupé, pas seulement caché', () {
      // C'est la moitié du correctif qu'on oublie : trois GeoJSON nationaux
      // téléchargés à chaque ouverture, chez des clients qui n'en verront
      // jamais la carte.
      final src = sourceTableauDeBord();
      final i = src.indexOf('if (estMinistere) {');
      expect(i, greaterThan(0),
          reason: 'Les données géo se chargent de nouveau pour tout le monde.');
      final bloc = src.substring(i, src.indexOf('}', i));
      for (final p in [
        'congoBoundaryProvider',
        'congoDepartmentsProvider',
        'congoPlacesProvider',
      ]) {
        expect(bloc.contains(p), isTrue,
            reason: '$p est sorti de la garde : il se charge pour un privé.');
      }
    });

    test('au doute, on retire l’outil plutôt que de l’ouvrir', () {
      // Le drapeau arrive de façon asynchrone. Un `?? true` mettrait la carte
      // nationale chez le client pendant chaque chargement.
      final src = sourceTableauDeBord();
      expect(
          src.contains(
              'ref.watch(groupeEstMinistereProvider).valueOrNull ?? false'),
          isTrue,
          reason: 'Le repli n’est plus FAUX : la carte s’affiche pendant que '
              'le rôle se charge.');
    });
  });

  group('La NATURE du groupe et le DROIT du fondateur sont deux questions', () {
    test('⚠️ estMinistere ne répond pas OUI au super_admin', () {
      // `groupeAdministreReferentielProvider` répond oui au super_admin, qui
      // n'a pas de groupe. S'en servir pour décider du contenu d'un espace
      // client marcherait aujourd'hui et se retournerait au premier réemploi.
      final src = _lire(_drapeaux);
      final i = src.indexOf('final groupeEstMinistereProvider');
      expect(i, greaterThan(0), reason: 'Le drapeau de NATURE a disparu.');
      final corps = src.substring(i);
      expect(corps.contains('isSuperAdmin'), isFalse,
          reason: 'Le drapeau de nature s’est remis à répondre OUI au '
              'fondateur : il n’est pas un ministère.');
    });

    test('le droit référentiel s’appuie dessus, sans le dupliquer', () {
      final src = _lire(_drapeaux);
      expect(src.contains('return ref.watch(groupeEstMinistereProvider.future);'),
          isTrue,
          reason: 'Deux requêtes pour la même colonne : elles divergeront.');
      expect("select('administre_referentiel_national')".allMatches(src).length,
          1,
          reason: 'La colonne est lue à deux endroits.');
    });
  });

  group('L’espace du fondateur garde sa Vue Nationale', () {
    test('elle n’a pas été retirée par ricochet', () {
      // C'est son métier de voir le pays. Le correctif ne visait que les
      // espaces clients.
      final src = _lire(_dashboardFondateur);
      expect(src.contains("label: 'Vue Nationale'"), isTrue,
          reason: 'La Vue Nationale du fondateur a disparu avec celle des '
              'clients : il ne voit plus son parc.');
    });
  });
}
