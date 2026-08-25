import 'package:epilote/core/utils/plan_proration.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER DE PLAN EN COURS D'ABONNEMENT
//
//  ── LE TROU QU'ON A BOUCHÉ ─────────────────────────────────────────────────
//  `trg_auto_create_invoice` ne se déclenche qu'à la CRÉATION d'un groupe.
//  Déplacer ensuite un groupe d'un plan à l'autre ne produisait rien : ni
//  facture, ni trace. Le cas était en base — le METP a réglé 150 000 FCFA en
//  premium et consommait de l'institutionnel.
//
//  ── CE QUE CES TESTS VERROUILLENT ──────────────────────────────────────────
//  L'aperçu affiché à l'opérateur AVANT qu'il n'enregistre. Il doit annoncer
//  exactement ce que `fn_regularize_plan_change` (migration 0078) va faire :
//  deux formules divergentes, et l'écran promettrait un montant que la facture
//  contredirait. Le pendant côté base est
//  `database/checks/0078_regularisation_changement_plan.sql`.
// ════════════════════════════════════════════════════════════════════════════

final _today = DateTime(2026, 8, 1);

void main() {
  group('Tarif annualisé', () {
    test('il rend deux périodicités comparables', () {
      // 10 000/mois, 30 000/trimestre et 120 000/an sont le MÊME tarif.
      expect(annualizedXaf(120000, 'annuel'), 120000);
      expect(annualizedXaf(10000, 'mensuel'), 120000);
      expect(annualizedXaf(30000, 'trimestriel'), 120000);
      expect(annualizedXaf(60000, 'semestriel'), 120000);
    });

    test('une période inconnue est traitée comme annuelle', () {
      expect(annualizedXaf(120000, null), 120000);
    });
  });

  group('Montée en gamme', () {
    test('la facture couvre les jours restants au prorata', () {
      final e = _effect(from: 120000, to: 360000, endInDays: 365);
      expect(e.isUpgrade, isTrue);
      expect(e.remainingDays, 365);
      expect(e.amountXaf, 240000); // l'écart annuel entier
    });

    test('à mi-parcours, la moitié de l\'écart', () {
      final e = _effect(from: 120000, to: 360000, endInDays: 182);
      expect(e.amountXaf, ((360000 - 120000) * 182 / 365).round());
    });

    test('la périodicité n\'entre pas dans le calcul, seul le tarif annualisé',
        () {
      // Passer d'un plan à 10 000/mois à un plan à 360 000/an, c'est le même
      // écart que de 120 000/an à 360 000/an.
      final parMois = _effect(
          from: 10000, fromPeriod: 'mensuel', to: 360000, endInDays: 365);
      final parAn = _effect(from: 120000, to: 360000, endInDays: 365);
      expect(parMois.amountXaf, parAn.amountXaf);
    });
  });

  group('Descente en gamme', () {
    test('elle ne facture rien et ne rembourse rien', () {
      // `group_invoices` ne sait représenter ni un avoir ni un montant négatif :
      // un `amount_xaf` négatif traverserait tous les totaux de la plateforme.
      final e = _effect(from: 360000, to: 120000, endInDays: 300);
      expect(e.isUpgrade, isFalse);
      expect(e.amountXaf, 0);
      expect(e.billsSomething, isFalse);
    });

    test('deux plans au même tarif annualisé ne produisent aucune facture', () {
      final e = _effect(
          from: 120000, to: 10000, toPeriod: 'mensuel', endInDays: 300);
      expect(e.amountXaf, 0);
    });
  });

  group('Quand il n\'y a rien à régulariser', () {
    test('un groupe en essai n\'a pas de période payée d\'avance', () {
      final e = _effect(
          from: 120000, to: 360000, endInDays: 365, isActive: false);
      expect(e.amountXaf, 0);
      expect(e.isUpgrade, isTrue); // la montée est réelle, elle n'est pas facturée
    });

    test('un abonnement échu ne se régularise pas', () {
      final e = _effect(from: 120000, to: 360000, endInDays: -10);
      expect(e.amountXaf, 0);
      expect(e.remainingDays, 0);
    });

    test('un abonnement qui se termine aujourd\'hui non plus', () {
      final e = _effect(from: 120000, to: 360000, endInDays: 0);
      expect(e.amountXaf, 0);
    });

    test('sans échéance connue, on ne facture pas au hasard', () {
      final e = planChangeEffect(
        fromPriceXaf: 120000,
        fromPeriod: 'annuel',
        toPriceXaf: 360000,
        toPeriod: 'annuel',
        end: null,
        isActive: true,
        today: _today,
      );
      expect(e.amountXaf, 0);
    });
  });

  group('Le cas réel qui a motivé le chantier', () {
    test('METP : premium 120 000/an → institutionnel 2 500 000/an', () {
      // Le groupe est actif jusqu'au 2027-05-30 sur la foi d'un reçu premium.
      final e = planChangeEffect(
        fromPriceXaf: 120000,
        fromPeriod: 'annuel',
        toPriceXaf: 2500000,
        toPeriod: 'annuel',
        end: DateTime(2027, 5, 30),
        isActive: true,
        today: _today,
      );
      expect(e.isUpgrade, isTrue);
      expect(e.remainingDays, 302);
      expect(e.amountXaf, ((2500000 - 120000) * 302 / 365).round());
      // L'écart n'était facturé nulle part : il était offert.
      expect(e.amountXaf, greaterThan(1900000));
    });
  });
}

PlanChangeEffect _effect({
  required int from,
  required int to,
  required int endInDays,
  String fromPeriod = 'annuel',
  String toPeriod = 'annuel',
  bool isActive = true,
}) =>
    planChangeEffect(
      fromPriceXaf: from,
      fromPeriod: fromPeriod,
      toPriceXaf: to,
      toPeriod: toPeriod,
      // ⚠️ PAS `_today.add(Duration(days: n))` : une durée est un temps absolu,
      // et la nuit où l'on recule d'une heure la fait retomber sur la veille.
      // C'est exactement le piège que corrige `plan_proration.dart` — le
      // reproduire ici testerait le bug au lieu du correctif.
      end: DateTime(_today.year, _today.month, _today.day + endInDays),
      isActive: isActive,
      today: _today,
    );
