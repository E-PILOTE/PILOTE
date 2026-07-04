/// Phase d'accès dérivée des DEUX horloges. Ordre = du plus permissif au plus
/// restrictif (utile pour prendre « la pire » des deux ladders).
enum LicensePhase {
  active,   // tout fonctionne
  grace,    // échu récemment OU proche de la fin de fenêtre : accès complet + alerte
  readOnly, // au-delà de la grâce, OU fenêtre de confiance dépassée : lecture seule
}

/// Jours de grâce après l'échéance métier avant lecture seule.
/// Aligné sur le chemin online (`kSubscriptionGraceDays`) — voir ADR-0006.
const int kLicenseGraceDays = 15;

/// Calcul PUR de la phase (double horloge). Aucune dépendance I/O.
///
/// - Horloge 1 (métier) : `validTo` → grâce (≤ [graceDays]) → lecture seule.
/// - Horloge 2 (confiance) : `now - lastSyncAt > offlineWindow` → lecture seule
///   (comble l'angle mort de la révocation invisible hors ligne).
///
/// Fail-soft : entrées inconnues (`validTo`/`lastSyncAt` null, `offlineWindow`
/// nulle) ⇒ on N'AGGRAVE pas — au doute, `active`. Ne jamais rejeter sur une
/// anomalie d'horloge (piles CMOS mortes) : c'est `now` qui doit être le
/// « meilleur temps connu » calculé en amont, pas ici.
LicensePhase computeLicensePhase({
  required DateTime? validTo,
  required Duration offlineWindow,
  required DateTime? lastSyncAt,
  required DateTime now,
  int graceDays = kLicenseGraceDays,
}) {
  var phase = LicensePhase.active;

  // Horloge 2 — fenêtre de confiance.
  if (lastSyncAt != null && offlineWindow > Duration.zero) {
    final offlineFor = now.difference(lastSyncAt);
    if (offlineFor > offlineWindow) {
      phase = LicensePhase.readOnly;
    }
  }

  // Horloge 1 — expiration métier (peut aggraver, jamais adoucir).
  if (validTo != null) {
    final overdue = now.difference(validTo).inDays; // >0 si dépassé
    if (overdue > graceDays) {
      phase = LicensePhase.readOnly;
    } else if (overdue >= 0 && phase == LicensePhase.active) {
      phase = LicensePhase.grace;
    }
  }

  return phase;
}
