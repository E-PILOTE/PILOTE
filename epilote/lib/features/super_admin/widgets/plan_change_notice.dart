import 'package:flutter/material.dart';

import '../../../core/utils/plan_proration.dart';
import '../providers/plans_provider.dart' show moneyXaf;
import '../providers/school_groups_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER LE PLAN D'UN GROUPE — le dire AVANT de le faire
//
//  Depuis la migration 0078, déplacer un groupe actif vers un plan supérieur
//  émet une facture complémentaire au prorata des jours restants. C'est la
//  bonne règle, mais elle serait insupportable si elle surprenait : l'opérateur
//  changerait un plan « pour voir » et découvrirait une créance de plusieurs
//  centaines de milliers de francs au nom d'un ministère.
//
//  Ce bandeau annonce le montant exact, avant l'enregistrement. Il annonce
//  aussi le cas inverse — la descente en gamme ne rembourse rien — parce que
//  laisser croire à un avoir serait une promesse qu'on ne tiendra pas.
// ════════════════════════════════════════════════════════════════════════════

const _kAmber = Color(0xFFF59E0B);
const _kBlue = Color(0xFF0EA5E9);

class PlanChangeNotice extends StatelessWidget {
  const PlanChangeNotice({
    super.key,
    required this.existing,
    required this.plans,
    required this.selectedPlanId,
    this.today,
  });

  final GroupDetail? existing;
  final List<PlanInfo> plans;
  final String? selectedPlanId;

  /// Injectable pour les tests ; `DateTime.now()` sinon.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final g = existing;
    // Création de groupe, ou plan inchangé : rien à annoncer.
    if (g == null || selectedPlanId == null || selectedPlanId == g.planId) {
      return const SizedBox.shrink();
    }

    PlanInfo? target;
    for (final p in plans) {
      if (p.id == selectedPlanId) target = p;
    }
    if (target == null) return const SizedBox.shrink();

    final effect = planChangeEffect(
      fromPriceXaf: g.priceXaf,
      fromPeriod: g.billingPeriod,
      toPriceXaf: target.priceXaf,
      toPeriod: target.billingPeriod,
      end: g.subscriptionEnd,
      isActive: g.isActif,
      today: today ?? DateTime.now(),
    );

    final (icon, color, text) = switch (effect) {
      final e when e.billsSomething => (
          Icons.receipt_long_rounded,
          _kAmber,
          'Une facture complémentaire de ${moneyXaf(e.amountXaf)} FCFA sera '
              'émise : elle couvre les ${e.remainingDays} jour(s) restants '
              'jusqu\'au terme en cours, au tarif du nouveau plan.',
        ),
      final e when e.isUpgrade => (
          Icons.info_outline_rounded,
          _kBlue,
          'Montée en gamme sans facture complémentaire : cet abonnement n\'a '
              'pas de période payée d\'avance à régulariser. Le nouveau tarif '
              's\'appliquera au prochain terme.',
        ),
      _ => (
          Icons.info_outline_rounded,
          _kBlue,
          'Descente en gamme : la période en cours reste due aux conditions '
              'précédentes — aucun remboursement ni avoir. Le nouveau tarif '
              's\'appliquera au prochain renouvellement.',
        ),
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: color.withValues(alpha: 0.95))),
        ),
      ]),
    );
  }
}
