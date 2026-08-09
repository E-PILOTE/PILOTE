// ════════════════════════════════════════════════════════════════════════════
//  JOURS RESTANTS AVANT ÉCHÉANCE — un seul calcul pour toute l'application
//
//  ── CE QU'ON RÉPARE ────────────────────────────────────────────────────────
//  Trois écrans comptaient les jours restants de trois façons, et affichaient
//  deux nombres DIFFÉRENTS sur la même page à la même seconde :
//
//    bandeau  → dates normalisées à minuit          → « expire dans 22 jours »
//    carte    → end.difference(DateTime.now())      → « Expire dans 21 j »
//    dashboard→ idem carte                          → 21
//
//  `subscription_end` est un DATE : il se parse à minuit. `DateTime.now()`, lui,
//  porte l'heure courante. La soustraction brute donne 21,6 jours, que `.inDays`
//  TRONQUE à 21. L'écart apparaît dès que la journée avance, et grandit jusqu'au
//  soir. Sur un compte à rebours d'abonnement, deux chiffres contradictoires à
//  l'écran ruinent la confiance dans les deux.
//
//  ── LA RÈGLE ───────────────────────────────────────────────────────────────
//  Une échéance est une DATE, pas un instant. On compare donc des jours civils :
//  on ramène les deux bornes à minuit avant de soustraire. Personne ne
//  recalcule ça à la main — tout passe par `daysUntilDate`.
//
//  Miroir exact de `subscription_end - CURRENT_DATE` en base (arithmétique de
//  `date`), pour que le serveur, le cron de rappels et l'écran s'accordent.
// ════════════════════════════════════════════════════════════════════════════

/// Nombre de jours civils entre aujourd'hui et [end].
///
/// Positif ou nul : jours restants (0 = échoit aujourd'hui).
/// Négatif : jours de dépassement.
/// `null` quand [end] est `null` — un abonnement sans échéance ne se compte pas.
///
/// [today] est injectable pour les tests ; par défaut = maintenant.
int? daysUntilDate(DateTime? end, [DateTime? today]) {
  if (end == null) return null;
  final now = today ?? DateTime.now();
  return DateTime(end.year, end.month, end.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

/// Vrai si l'échéance est dépassée d'AU PLUS [graceDays] jours pour un statut
/// qui donne droit à la grâce.
///
/// La grâce ne récompense qu'une expiration NATURELLE : `suspended` (impayé
/// posé par le super_admin) et `cancelled` (résiliation) tombent tout de suite.
/// Règle partagée par le soft-gate `admin_groupe` et la vue recouvrement
/// `super_admin` — les deux la dupliquaient, et pouvaient donc diverger.
bool isNaturalExpiry(String status) =>
    status != 'suspended' && status != 'cancelled';

/// Statuts qui ouvrent des droits tant que la date tient.
bool isEntitlingStatus(String status) =>
    status == 'active' || status == 'trial';
