/// Vue « recouvrement » super_admin : quels groupes approchent de l'échéance,
/// sont en grâce, ou échus/impayés. Logique de classement PURE (testable) ;
/// le provider I/O est ajouté plus bas.

enum DunningBucket { expiringSoon, inGrace, overdue }

/// Classe un groupe dans un seau de recouvrement à partir de son statut brut et
/// de sa date de fin. Renvoie `null` si le groupe n'est PAS concerné (actif et
/// loin de l'échéance, ou sans date de fin). Comparaison au jour près.
/// Miroir de `computeSubscriptionAccess` (même sémantique grâce/statuts).
DunningBucket? bucketDunning({
  required String status,
  required DateTime? end,
  required DateTime now,
  int graceDays = 15,
  int soonDays = 7,
}) {
  if (end == null) return null;
  final e = DateTime(end.year, end.month, end.day);
  final n = DateTime(now.year, now.month, now.day);
  final daysLeft = e.difference(n).inDays;

  final entitling = status == 'active' || status == 'trial';

  if (daysLeft >= 0) {
    if (entitling && daysLeft <= soonDays) return DunningBucket.expiringSoon;
    return null; // actif et loin → hors recouvrement
  }

  // Échu. La grâce ne vaut que pour une expiration NATURELLE et récente ;
  // 'suspended' (impayé posé par le super_admin) et 'cancelled' → overdue direct.
  final overdue = -daysLeft;
  final naturalExpiry = status != 'suspended' && status != 'cancelled';
  if (naturalExpiry && overdue <= graceDays) return DunningBucket.inGrace;
  return DunningBucket.overdue;
}
