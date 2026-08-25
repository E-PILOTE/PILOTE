// ════════════════════════════════════════════════════════════════════════════
//  PÉRIODICITÉ D'ABONNEMENT — mensuel, trimestriel, semestriel, annuel
//
//  ── CE QU'ON RÉPARE ────────────────────────────────────────────────────────
//  L'écran des plans annonçait « Prix mensuel » ; la base facturait ce même
//  montant pour DOUZE MOIS (`fn_auto_create_invoice`, `create_renewal_invoice`
//  posaient toutes deux `+ INTERVAL '1 year'`). Les factures réellement émises
//  tranchaient en faveur de la base : 900 000 FCFA pour 2026-01-01 → 12-31.
//  L'étiquette était donc fausse, d'un facteur douze, sur chaque affichage de
//  revenu de la plateforme.
//
//  Depuis la migration 0077 la durée est une propriété du plan
//  (`subscription_plans.billing_period`), choisie à l'écran.
//
//  ── LA RÈGLE ───────────────────────────────────────────────────────────────
//  Un prix ne veut rien dire sans sa période. Deux conséquences :
//    • on n'affiche JAMAIS un tarif sans son suffixe (« / an », « / mois ») ;
//    • on ne SOMME jamais des tarifs de périodicités différentes — il faut les
//      ramener au mois avec `monthlyEquivalent` avant d'additionner.
//
//  `billingPeriodMonths` répond mot pour mot à `billing_period_months()` en
//  base. Les deux doivent bouger ensemble.
// ════════════════════════════════════════════════════════════════════════════

/// Périodicités reconnues, dans l'ordre croissant de durée.
/// Clé = valeur de l'enum `billing_period` en base ; valeur = libellé écran.
const kBillingPeriods = <String, String>{
  'mensuel': 'Mensuel',
  'trimestriel': 'Trimestriel',
  'semestriel': 'Semestriel',
  'annuel': 'Annuel',
};

/// Périodicité par défaut — celle des plans existants (cf. migration 0077).
const kDefaultBillingPeriod = 'annuel';

/// Nombre de mois couverts par une période. Miroir de `billing_period_months()`.
int billingPeriodMonths(String? period) => switch (period) {
      'mensuel' => 1,
      'trimestriel' => 3,
      'semestriel' => 6,
      _ => 12,
    };

/// Libellé de la périodicité : « Trimestriel ».
String billingPeriodLabel(String? period) =>
    kBillingPeriods[period] ?? kBillingPeriods[kDefaultBillingPeriod]!;

/// Suffixe accolé à un montant : « 120 000 FCFA / an ».
String billingPeriodSuffix(String? period) => switch (period) {
      'mensuel' => 'mois',
      'trimestriel' => 'trimestre',
      'semestriel' => 'semestre',
      _ => 'an',
    };

/// Ramène un tarif à son équivalent MENSUEL, seule base sur laquelle des plans
/// de périodicités différentes peuvent s'additionner.
///
/// L'arrondi est au franc le plus proche : le XAF n'a pas de subdivision.
int monthlyEquivalent(int priceXaf, String? period) {
  final months = billingPeriodMonths(period);
  if (months <= 1) return priceXaf;
  return (priceXaf / months).round();
}

/// Tarif mensuel d'une jointure `subscription_plans(price_xaf, billing_period)`.
///
/// Chaque tableau de bord refaisait ce calcul à la main sur la ligne jointe —
/// et tous l'ont fait faux de la même façon, en oubliant la période. Un seul
/// endroit, donc, et un seul endroit à corriger.
double monthlyPriceOfPlanRow(Map? plan) {
  if (plan == null) return 0;
  final price = (plan['price_xaf'] as num?)?.toInt() ?? 0;
  return monthlyEquivalent(price, plan['billing_period'] as String?).toDouble();
}
