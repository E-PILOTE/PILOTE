import 'package:epilote/core/utils/billing_period.dart';
import 'package:epilote/features/super_admin/providers/plans_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PÉRIODICITÉ D'ABONNEMENT — mensuel, trimestriel, semestriel, annuel
//
//  ── LE MENSONGE QU'ON A CORRIGÉ ────────────────────────────────────────────
//  L'écran des plans annonçait « Prix mensuel ». La base facturait ce même
//  montant pour DOUZE MOIS — `fn_auto_create_invoice` et
//  `create_renewal_invoice` posaient toutes deux `+ INTERVAL '1 year'`. Les
//  factures réellement émises tranchaient : 900 000 FCFA pour la période
//  2026-01-01 → 2026-12-31.
//
//  Pire, les deux espaces se contredisaient à l'écran sur le MÊME abonnement :
//  l'espace admin de groupe affichait « / an », l'espace plateforme « / mois ».
//
//  Depuis la migration 0077 la durée est une propriété du plan. Ces tests
//  verrouillent les deux invariants qui en découlent :
//    • un montant ne s'affiche jamais sans sa période ;
//    • des tarifs de périodicités différentes ne s'additionnent qu'une fois
//      ramenés au mois.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('Correspondance période → mois', () {
    test('les quatre périodicités connues', () {
      expect(billingPeriodMonths('mensuel'), 1);
      expect(billingPeriodMonths('trimestriel'), 3);
      expect(billingPeriodMonths('semestriel'), 6);
      expect(billingPeriodMonths('annuel'), 12);
    });

    test('une valeur inconnue ou nulle retombe sur l\'annuel', () {
      // C'est la périodicité des plans existants : une ligne sans valeur ne
      // doit pas se retrouver facturée au mois par accident.
      expect(billingPeriodMonths(null), 12);
      expect(billingPeriodMonths(''), 12);
      expect(billingPeriodMonths('hebdomadaire'), 12);
      expect(billingPeriodMonths(kDefaultBillingPeriod), 12);
    });

    test('le catalogue Dart couvre exactement l\'enum de la base', () {
      // `billing_period` en base (migration 0077) a ces quatre valeurs, et
      // `billing_period_months()` leur répond la même chose. Ajouter une
      // périodicité ici sans toucher au SQL casserait la facturation.
      expect(kBillingPeriods.keys.toSet(),
          {'mensuel', 'trimestriel', 'semestriel', 'annuel'});
    });
  });

  group('Étiquettes', () {
    test('le suffixe accolé au montant', () {
      expect(billingPeriodSuffix('mensuel'), 'mois');
      expect(billingPeriodSuffix('trimestriel'), 'trimestre');
      expect(billingPeriodSuffix('semestriel'), 'semestre');
      expect(billingPeriodSuffix('annuel'), 'an');
      expect(billingPeriodSuffix(null), 'an');
    });

    test('le libellé du sélecteur', () {
      expect(billingPeriodLabel('trimestriel'), 'Trimestriel');
      expect(billingPeriodLabel(null), 'Annuel');
    });

    test('un tarif ne s\'affiche jamais sans sa période', () {
      final annuel = _plan(priceXaf: 2500000, period: 'annuel');
      final mensuel = _plan(priceXaf: 120000, period: 'mensuel');
      expect(annuel.priceLabel, '2 500 000 FCFA / an');
      expect(mensuel.priceLabel, '120 000 FCFA / mois');
    });

    test('un plan gratuit n\'affiche pas de période', () {
      // « 0 FCFA / an » n'apprend rien et alourdit la ligne.
      expect(_plan(priceXaf: 0).priceLabel, 'Gratuit');
    });
  });

  group('Ramener au mois', () {
    test('un tarif annuel se divise par douze', () {
      expect(monthlyEquivalent(2500000, 'annuel'), 208333);
      expect(monthlyEquivalent(120000, 'annuel'), 10000);
    });

    test('un tarif mensuel reste intact', () {
      expect(monthlyEquivalent(120000, 'mensuel'), 120000);
    });

    test('trimestriel et semestriel', () {
      expect(monthlyEquivalent(300000, 'trimestriel'), 100000);
      expect(monthlyEquivalent(600000, 'semestriel'), 100000);
    });

    test('l\'arrondi tombe au franc — le XAF n\'a pas de subdivision', () {
      // 100 000 / 12 = 8 333,33…
      expect(monthlyEquivalent(100000, 'annuel'), 8333);
      expect(monthlyEquivalent(100, 'annuel'), 8);
    });

    test('la gratuité reste la gratuité', () {
      expect(monthlyEquivalent(0, 'annuel'), 0);
    });
  });

  group('Lecture d\'une ligne jointe subscription_plans', () {
    test('elle applique la période de la ligne', () {
      expect(
        monthlyPriceOfPlanRow({'price_xaf': 2500000, 'billing_period': 'annuel'}),
        208333,
      );
      expect(
        monthlyPriceOfPlanRow({'price_xaf': 50000, 'billing_period': 'mensuel'}),
        50000,
      );
    });

    test('une jointure absente vaut zéro, pas une exception', () {
      // Un groupe sans plan existe : le tableau de bord ne doit pas tomber.
      expect(monthlyPriceOfPlanRow(null), 0);
      expect(monthlyPriceOfPlanRow(const {}), 0);
    });

    test('une période manquante est traitée comme annuelle', () {
      expect(monthlyPriceOfPlanRow({'price_xaf': 1200000}), 100000);
    });
  });

  group('Le plan porte sa périodicité', () {
    test('les mois et le libellé viennent du plan', () {
      final p = _plan(priceXaf: 300000, period: 'trimestriel');
      expect(p.billingMonths, 3);
      expect(p.periodLabel, 'Trimestriel');
      expect(p.monthlyPrice, 100000);
    });

    test('un plan sans période explicite est annuel', () {
      final p = _plan(priceXaf: 1200000);
      expect(p.billingMonths, 12);
      expect(p.monthlyPrice, 100000);
    });
  });
}

PlanDetail _plan({int priceXaf = 0, String period = 'annuel'}) => PlanDetail(
      id: 'p1',
      name: 'Test',
      slug: 'premium',
      priceXaf: priceXaf,
      maxSchools: 5,
      maxStudents: 2000,
      maxStaff: 200,
      moduleCount: 16,
      billingPeriod: period,
      isPublicPlan: false,
      isActive: true,
      linkedModules: 16,
      subscribersTotal: 0,
      subscribersActive: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
