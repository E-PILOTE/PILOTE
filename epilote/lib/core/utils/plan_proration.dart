import 'billing_period.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER DE PLAN EN COURS D'ABONNEMENT — l'aperçu, côté écran
//
//  Le calcul qui fait foi vit en base (`fn_regularize_plan_change`, migration
//  0078) : c'est lui qui émet la facture, quel que soit le chemin d'écriture.
//  Ce fichier n'en est que le MIROIR, pour dire à l'opérateur ce qu'il
//  s'apprête à déclencher avant qu'il ne l'ait déclenché.
//
//  Les deux formules doivent rester identiques ; `test/plan_proration_test.dart`
//  verrouille celle d'ici, `database/checks/0078_*.sql` celle de là-bas.
//
//  ── LA RÈGLE, ET SON ASYMÉTRIE ─────────────────────────────────────────────
//  MONTÉE EN GAMME → facture complémentaire au prorata des jours restants. Le
//  groupe consomme dès maintenant les quotas du plan supérieur.
//  DESCENTE EN GAMME → rien. La période courante est payée, elle est due ; le
//  nouveau tarif s'applique au renouvellement. Ni avoir, ni remboursement —
//  `group_invoices` ne sait représenter ni l'un ni l'autre.
// ════════════════════════════════════════════════════════════════════════════

/// Tarif ramené à l'ANNÉE — seule base comparable entre deux périodicités.
/// Miroir de `plan_annualized_xaf()` en base.
int annualizedXaf(int priceXaf, String? period) {
  final months = billingPeriodMonths(period);
  return (priceXaf * 12 / (months < 1 ? 1 : months)).round();
}

/// Ce qu'un changement de plan va produire.
class PlanChangeEffect {
  const PlanChangeEffect({
    required this.amountXaf,
    required this.remainingDays,
    required this.isUpgrade,
  });

  /// Montant de la facture complémentaire. Zéro si rien n'est facturé.
  final int amountXaf;
  final int remainingDays;
  final bool isUpgrade;

  bool get billsSomething => amountXaf > 0;
}

/// Calcule l'effet d'un passage de [fromPriceXaf]/[fromPeriod] à
/// [toPriceXaf]/[toPeriod] pour un abonnement qui court jusqu'à [end].
///
/// [isActive] et [end] décident s'il y a matière : un groupe en essai ou déjà
/// échu n'a pas de période payée d'avance à corriger.
PlanChangeEffect planChangeEffect({
  required int fromPriceXaf,
  required String? fromPeriod,
  required int toPriceXaf,
  required String? toPeriod,
  required DateTime? end,
  required bool isActive,
  required DateTime today,
}) {
  final fromYear = annualizedXaf(fromPriceXaf, fromPeriod);
  final toYear = annualizedXaf(toPriceXaf, toPeriod);
  final upgrade = toYear > fromYear;

  if (!isActive || end == null) {
    return PlanChangeEffect(
        amountXaf: 0, remainingDays: 0, isUpgrade: upgrade);
  }

  // ⚠️ Compté en UTC, volontairement. `difference().inDays` sur deux dates
  // LOCALES traverse les changements d'heure : du 1ᵉʳ août au 30 janvier, la
  // nuit où l'on recule d'une heure fait rendre 181 jours au lieu de 182, et le
  // montant facturé se met à dépendre de la saison. La date civile n'a pas de
  // fuseau ; on la compare donc sans.
  final days = DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days <= 0 || !upgrade) {
    return PlanChangeEffect(
        amountXaf: 0, remainingDays: days < 0 ? 0 : days, isUpgrade: upgrade);
  }

  return PlanChangeEffect(
    amountXaf: ((toYear - fromYear) * days / 365).round(),
    remainingDays: days,
    isUpgrade: true,
  );
}
