import 'dart:io';

import 'package:epilote/features/super_admin/providers/subscriptions_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecran_abonnements_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REVENU MENSUEL — UN SEUL CHIFFRE, DEUX ÉCRANS
//
//  ── CE QUI A ÉTÉ VU À L'ÉCRAN (2026-09-04, session super_admin) ───────────
//  La page « Abonnements » annonçait **120 000 F** de revenu mensuel. La page
//  « Économie & licences » annonçait **184 000 F**. Même mois, même parc.
//
//  La page Abonnements additionnait le tarif de BASE des plans — 30 000
//  (Standard) + 50 000 (Pro) + 40 000 (Institutionnel) — et perdait deux
//  choses : les écoles supplémentaires (Saint-Pierre en a 3, Horizon 3,
//  Savorgnan 2) et les tarifs négociés. Soit **64 000 F par mois, 35 %**, en
//  moins — sur la page qu'on ouvre en premier pour regarder ses abonnements.
//
//  ── LA RÈGLE ──────────────────────────────────────────────────────────────
//  Un tarif ne veut rien dire sans son assiette. Le barème vit à UN endroit,
//  `tarifPlanRow`, miroir de `plan_price_xaf()` en base (0159). Tout écran qui
//  affiche un montant d'abonnement passe par lui — sinon deux pages du même
//  logiciel se contredisent sur le chiffre d'affaires, et c'est le fondateur
//  qui arbitre entre ses propres écrans.
// ════════════════════════════════════════════════════════════════════════════

const _provider = 'lib/features/super_admin/providers/subscriptions_provider.dart';
const _economie = 'lib/features/super_admin/providers/economie_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Une ligne `school_groups` telle que PostgREST la rend, plan joint compris.
Map<String, dynamic> _ligne({
  required String plan,
  required int base,
  required int tranche2a5,
  int? assiette,
  int? negocie,
  String periode = 'mensuel',
}) =>
    {
      'id': 'g1',
      'name': 'Groupe',
      'admin_email': 'a@b.cg',
      'group_type': 'prive',
      'subscription_status': 'active',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'billed_schools': assiette,
      'price_override_xaf': negocie,
      'plan': {
        'name': plan,
        'slug': 'x',
        'price_xaf': base,
        'billing_period': periode,
        'extra_school_2_5_xaf': tranche2a5,
        'extra_school_6_10_xaf': 0,
        'extra_school_11_20_xaf': 0,
        'extra_school_21p_xaf': 0,
      },
    };

void main() {
  group('Le montant suit l’assiette, pas le tarif d’affiche', () {
    test('⚠️ deux écoles sur Institutionnel : 52 000, pas 40 000', () {
      // Le cas exact vu à l'écran : Savorgnan et EDEC, 2 écoles chacun.
      final s = SubscriptionDetail.fromMap(
          _ligne(plan: 'Institutionnel', base: 40000, tranche2a5: 12000,
              assiette: 2));
      expect(s.priceXaf, 52000,
          reason: 'Le tarif de base est revenu : le revenu de la page '
              'Abonnements repart 12 000 F sous la vérité, par groupe.');
      expect(s.ecolesFacturees, 2);
      expect(s.monthlyPrice, 52000);
    });

    test('trois écoles sur Standard : 50 000', () {
      final s = SubscriptionDetail.fromMap(
          _ligne(plan: 'Standard', base: 30000, tranche2a5: 10000,
              assiette: 3));
      expect(s.priceXaf, 50000);
    });

    test('trois écoles sur Pro : 82 000', () {
      final s = SubscriptionDetail.fromMap(
          _ligne(plan: 'Pro', base: 50000, tranche2a5: 16000, assiette: 3));
      expect(s.priceXaf, 82000);
    });

    test('le total du parc réel fait bien 184 000, plus 120 000', () {
      // C'est LE chiffre qui se lisait faux à l'écran.
      final parc = [
        SubscriptionDetail.fromMap(_ligne(
            plan: 'Standard', base: 30000, tranche2a5: 10000, assiette: 3)),
        SubscriptionDetail.fromMap(
            _ligne(plan: 'Pro', base: 50000, tranche2a5: 16000, assiette: 3)),
        SubscriptionDetail.fromMap(_ligne(
            plan: 'Institutionnel', base: 40000, tranche2a5: 12000,
            assiette: 2)),
      ];
      expect(parc.fold<int>(0, (t, s) => t + s.monthlyPrice), 184000);
    });

    test('⚠️ un tarif négocié ne se recalcule jamais', () {
      // Un montant négocié est un engagement contractuel : le barème n'a plus
      // voix au chapitre, même si l'assiette bouge.
      final s = SubscriptionDetail.fromMap(_ligne(
          plan: 'Institutionnel', base: 40000, tranche2a5: 12000,
          assiette: 9, negocie: 75000));
      expect(s.priceXaf, 75000);
      expect(s.tarifNegocie, isTrue);
    });

    test('sans assiette connue, le plancher est à une école', () {
      // Un groupe qui vient d'être créé n'a pas encore d'écoles — il n'est pas
      // gratuit pour autant.
      final s = SubscriptionDetail.fromMap(
          _ligne(plan: 'Standard', base: 30000, tranche2a5: 10000));
      expect(s.priceXaf, 30000);
      expect(s.ecolesFacturees, 1);
    });

    test('un plan annuel est ramené au mois avant d’être additionné', () {
      final s = SubscriptionDetail.fromMap(_ligne(
          plan: 'Annuel', base: 120000, tranche2a5: 0, periode: 'annuel'));
      expect(s.priceXaf, 120000);
      expect(s.monthlyPrice, 10000,
          reason: 'Le MRR mélange de nouveau des tarifs annuels et mensuels.');
    });
  });

  group('Les deux écrans lisent le MÊME barème', () {
    test('aucun des deux ne recalcule le prix dans son coin', () {
      for (final f in [_provider, _economie]) {
        expect(_lire(f).contains('tarifPlanRow('), isTrue,
            reason: '$f a repris un calcul de prix à lui : les deux pages '
                'vont diverger sur le chiffre d’affaires.');
      }
    });

    test('la requête ramène de quoi calculer', () {
      // Sans ces colonnes, `tarifPlanRow` retombe silencieusement sur la base :
      // le bug d'origine revient sans qu'aucune ligne de calcul ne change.
      final src = _lire(_provider);
      for (final col in [
        'price_override_xaf',
        'billed_schools',
        'extra_school_2_5_xaf',
        'extra_school_6_10_xaf',
        'extra_school_11_20_xaf',
        'extra_school_21p_xaf',
      ]) {
        expect(src.contains(col), isTrue,
            reason: '$col n’est plus demandée : le barème s’applique à des '
                'colonnes absentes, donc à zéro.');
      }
    });

    test('⚠️ aucun écran ne calcule le revenu sur le tarif d’affiche', () {
      // `monthlyPriceOfPlanRow` prend le prix du PLAN, sans assiette ni tarif
      // négocié. C'est le piège qui a produit l'écart : cinq écrans du fondateur
      // s'en servaient pour du revenu. Elle reste utile au catalogue de plans —
      // pas dans une feature.
      final coupables = <String>[];
      for (final f in Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains('monthlyPriceOfPlanRow(')) {
          coupables.add(f.path);
        }
      }
      expect(coupables, isEmpty,
          reason: 'Un écran calcule de nouveau du revenu sur le tarif '
              'd’affiche : il sous-estimera les groupes multi-écoles.');
    });

    test('les quatre écrans de revenu passent par mensualiteGroupe', () {
      // Tableau de bord, Abonnements, Rapports, IA : quatre pages, un seul
      // barème. C'est ce qui garantit qu'elles annoncent le même chiffre.
      for (final f in [
        'lib/features/super_admin/providers/super_dashboard_provider.dart',
        'lib/features/super_admin/providers/reports_provider.dart',
        'lib/features/super_admin/screens/ai_screen.dart',
      ]) {
        expect(_lire(f).contains('mensualiteGroupe('), isTrue,
            reason: '$f a repris un calcul de revenu à lui.');
      }
    });

    test('la carte dit ce qu’elle ne compte pas', () {
      // Le plan « Licence de tutelle » est un support à 0 F : les ministères
      // pèsent zéro dans ce total. Sans le dire, ce zéro passe pour un oubli.
      final src = sourceEcranAbonnements();
      expect(src.contains("sub:   'Abonnements — hors licences',"), isTrue);
    });
  });
}
