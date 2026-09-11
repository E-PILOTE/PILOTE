import 'dart:io';

import 'package:epilote/features/super_admin/providers/super_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecran_dashboard_fondateur_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ZÉRO N'EST PAS « JE NE SAIS PAS »
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  Le tableau de bord du fondateur faisait NEUF lectures, chacune enveloppée
//  dans un `catch (_) {}`. Réseau coupé, RLS resserrée, colonne renommée : la
//  mesure restait à zéro et l'écran annonçait « 0 élève », « 0 FCFA de
//  revenus », « 0 groupe actif » — avec le même aplomb que la vérité, et sans
//  la moindre trace.
//
//  C'est le défaut de famille de cet écran. Il portait déjà « Sync réussie
//  99,7 % » et « SLA 99,5 % », deux constantes que rien ne mesurait, et une
//  courbe de revenus fabriquée en multipliant le mois courant par une suite
//  croissante. Trois fois la même erreur : afficher un chiffre plutôt que
//  d'avouer qu'on ne l'a pas.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Qu'aucune lecture ne redevienne muette, que chaque échec ait un nom lisible,
//  et que les cartes concernées disent « — » au lieu d'un zéro.
// ════════════════════════════════════════════════════════════════════════════

const _provider =
    'lib/features/super_admin/providers/super_dashboard_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Aucune lecture ne retombe dans le silence', () {
    test('plus un seul `catch (_) {}` dans le tableau de bord', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('catch (_) {}'), isFalse,
          reason: 'Une lecture avalée en silence rend la mesure à zéro, et '
              'zéro se lit comme un fait.');
    });

    test('chaque échec est nommé et tracé', () {
      final src = _sansCommentaires(_lire(_provider));
      // Neuf lectures, neuf enregistrements.
      expect('echecs.add('.allMatches(src).length, 9,
          reason: 'Une lecture a été ajoutée ou retirée sans dire ce qu’elle '
              'devient quand elle échoue.');
      expect('debugPrint('.allMatches(src).length, greaterThanOrEqualTo(9),
          reason: 'Sans trace, on ne saura jamais POURQUOI la mesure manque.');
    });

    test('le résultat porte la liste des mesures manquantes', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('mesuresIndisponibles: echecs,'), isTrue,
          reason: 'Les échecs sont collectés mais jamais rendus à l’écran.');
    });
  });

  group('Le vocabulaire des mesures', () {
    test('chaque clé a un libellé lisible', () {
      // Un bandeau qui afficherait « ecoles_et_groupes » à un ministre
      // n'expliquerait rien.
      const cles = [
        MesuresDashboard.eleves,
        MesuresDashboard.personnel,
        MesuresDashboard.departements,
        MesuresDashboard.ecolesEtGroupes,
        MesuresDashboard.personnelParRole,
        MesuresDashboard.activite,
        MesuresDashboard.tendances,
      ];
      for (final c in cles) {
        final l = MesuresDashboard.libelle(c);
        expect(l, isNot(c), reason: 'La clé $c n’a pas de libellé.');
        expect(l.contains('_'), isFalse, reason: '$c → « $l » : clé brute.');
      }
    });

    test('une clé inconnue se rend telle quelle plutôt que de disparaître', () {
      expect(MesuresDashboard.libelle('nouvelle_mesure'), 'nouvelle_mesure');
    });
  });

  group('Le cas normal reste silencieux', () {
    test('aucune mesure manquante par défaut', () {
      expect(SuperDashboardData.empty.mesuresIndisponibles, isEmpty);
      expect(SuperDashboardData.empty.indisponible(MesuresDashboard.eleves),
          isFalse);
    });

    test('`indisponible` répond sur la clé exacte', () {
      const d = SuperDashboardData(
        groupesActifs: 0, groupesTotal: 0, elevesTotal: 0, personnelTotal: 0,
        revenusXafMois: 0, ecolesTotal: 0, abonnementsActifs: 0,
        expirantDans30j: 0, groupesByPlan: [], recentActivity: [],
        deptStats: [], trendGroupes: [], trendEcoles: [], trendEleves: [],
        trendRevenus: [], personnelByRole: [], abonnementsByStatus: [],
        revenueMonthly: [],
        mesuresIndisponibles: {MesuresDashboard.eleves},
      );
      expect(d.indisponible(MesuresDashboard.eleves), isTrue);
      expect(d.indisponible(MesuresDashboard.personnel), isFalse);
    });
  });

  group('L’écran dit « — », pas zéro', () {
    test('les six cartouches savent d’où vient leur mesure', () {
      final src = _sansCommentaires(sourceDashboardFondateur());
      expect('inconnu: stats.indisponible('.allMatches(src).length, 6,
          reason: 'Une carte sans cette garde affichera un zéro inventé.');
    });

    test('la carte affiche un tiret au lieu d’un compteur qui monte vers 0',
        () {
      final src = _sansCommentaires(sourceDashboardFondateur());
      expect(src.contains('if (d.inconnu)'), isTrue);
      final tiret = src.indexOf("Text('—'");
      final compteur = src.indexOf('_CountUp(');
      expect(tiret, greaterThan(-1));
      expect(tiret, lessThan(compteur),
          reason: 'Le tiret doit passer AVANT le compteur : sinon la carte '
              'anime une montée jusqu’à zéro.');
    });

    test('le bandeau se lit AVANT les chiffres', () {
      // On doit savoir que des mesures manquent avant de se faire une opinion,
      // pas après.
      final src = _sansCommentaires(sourceDashboardFondateur());
      final bandeau = src.indexOf('_MesuresIndisponiblesBanner(stats: stats)');
      final grille = src.indexOf('_KpiGrid(stats: stats');
      expect(bandeau, greaterThan(-1));
      expect(grille, greaterThan(-1));
      expect(bandeau, lessThan(grille));
    });

    test('le bandeau propose de réessayer', () {
      final src = _sansCommentaires(sourceDashboardFondateur());
      expect(src.contains('invalidate(superDashboardProvider)'), isTrue,
          reason: 'Dire « je n’ai pas pu lire » sans offrir de réessayer '
              'laisse l’utilisateur recharger la page à l’aveugle.');
    });
  });
}
