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

// ════════════════════════════════════════════════════════════════════════════
//  FENÊTRE D'ALERTE — le même seuil pour le groupe ET pour ses écoles
//
//  Deux bandeaux annoncent la même échéance à deux publics : l'admin de groupe
//  (online, Supabase) et le personnel d'école (offline, PowerSync). Ils avaient
//  chacun leur seuil — 7 jours d'un côté, 30 de l'autre — donc l'école
//  s'inquiétait trois semaines avant celui qui peut payer. Le seuil vit
//  désormais ici, et les deux chemins le lisent.
//
//  Valeur effective : réglée par le super_admin
//  (`platform_settings.subscription_alert_days`), servie en ligne par la RPC
//  `get_subscription_settings` et recopiée hors ligne dans
//  `school_groups.subscription_alert_days` (migration 0106). La constante
//  ci-dessous n'est QUE le filet quand aucune des deux sources n'est joignable.
// ════════════════════════════════════════════════════════════════════════════

/// Fenêtre d'alerte de repli : le bandeau s'allume à moins de N jours.
///
/// Valait 30 (bandeau permanent, donc invisible), puis 7. Ramenée à **5** le
/// 2026-08-14 : un bandeau est une pression, pas une information. Prévenir tôt
/// est le rôle de la cloche (`notif_reminder_days` = 30,15,7,1,0), qui ne
/// s'affiche qu'une fois et ne fatigue pas.
const int kSubscriptionAlertDays = 5;

/// Jours civils restants **si l'échéance tombe dans la fenêtre d'alerte**,
/// `null` sinon (trop loin, pas de date, ou déjà dépassée — le dépassement
/// relève des phases grâce / lecture seule / hard-lock, pas du compte à rebours).
int? alertDaysLeft(DateTime? end, {required int alertDays, DateTime? today}) {
  final d = daysUntilDate(end, today);
  if (d == null || d < 0 || d > alertDays) return null;
  return d;
}

/// Seuils de rappel « 30,15,7,1,0 » → `[30, 15, 7, 1, 0]`.
/// Miroir exact du parseur SQL d'`emit_subscription_reminders` : on ignore les
/// fragments non numériques au lieu de rejeter toute la liste.
List<int> parseReminderDays(String csv) {
  final out = <int>[];
  for (final part in csv.split(',')) {
    final n = int.tryParse(part.trim());
    if (n != null && n >= 0) out.add(n);
  }
  out.sort((a, b) => b.compareTo(a));
  return out;
}

/// Vrai si au moins un rappel tombe **à l'intérieur** de la fenêtre du bandeau.
///
/// C'est l'invariant qui tient les deux réglages ensemble : sans lui, régler
/// l'alerte à 5 en laissant les rappels à `30,15,7` éteint le canal cloche
/// précisément dans les cinq jours qui décident du paiement.
bool remindersCoverAlertWindow({
  required List<int> reminderDays,
  required int alertDays,
}) =>
    reminderDays.any((d) => d <= alertDays);
