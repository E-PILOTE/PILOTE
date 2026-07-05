/// Phase d'accès dérivée des DEUX horloges. Ordre = du plus permissif au plus
/// restrictif (utile pour prendre « la pire » des deux ladders : `index` croît
/// avec la sévérité).
enum LicensePhase {
  active,   // tout fonctionne
  grace,    // échu récemment OU proche de la fin de fenêtre : accès complet + alerte
  readOnly, // au-delà de la grâce, OU fenêtre de confiance dépassée : lecture seule
  hardLock, // impayé métier CONFIRMÉ au-delà de la grâce, plan éligible (privé) :
            // modules inaccessibles (clic mort) — seuls Dashboard/Profil/Paramètres
            // /Renouveler/Support restent. JAMAIS déclenché par la seule fenêtre de
            // confiance (un souci de réseau ne doit pas bloquer une école honnête).
}

/// Jours de grâce après l'échéance métier avant lecture seule.
/// Aligné sur le chemin online (`kSubscriptionGraceDays`) — voir ADR-0006.
const int kLicenseGraceDays = 15;

/// Calcul PUR de la phase (double horloge). Aucune dépendance I/O.
///
/// - Horloge 1 (métier) : `validTo` → grâce (≤ [graceDays]) → lecture seule, ou
///   `hardLock` si [hardLockEligible] (plan privé) : impayé confirmé au-delà de
///   la grâce ⇒ modules inaccessibles.
/// - Horloge 2 (confiance) : `now - lastSyncAt > offlineWindow` → lecture seule
///   (comble l'angle mort de la révocation invisible hors ligne). N'escalade
///   JAMAIS jusqu'à `hardLock` : un appareil resté hors ligne peut être une
///   école honnête mal connectée, pas un impayé.
///
/// La phase retenue = la PIRE des deux ladders (max `index`).
///
/// Fail-soft : entrées inconnues (`validTo`/`lastSyncAt` null, `offlineWindow`
/// nulle) ⇒ on N'AGGRAVE pas — au doute, `active`. [hardLockEligible] par défaut
/// `false` ⇒ comportement inchangé (aucune école ne se durcit tant que la licence
/// ne porte pas explicitement le flag). Ne jamais rejeter sur une anomalie
/// d'horloge (piles CMOS mortes) : c'est `now` qui doit être le « meilleur temps
/// connu » calculé en amont, pas ici.
LicensePhase computeLicensePhase({
  required DateTime? validTo,
  required Duration offlineWindow,
  required DateTime? lastSyncAt,
  required DateTime now,
  int graceDays = kLicenseGraceDays,
  bool hardLockEligible = false,
}) {
  var phase = LicensePhase.active;

  // Horloge 2 — fenêtre de confiance (au pire `readOnly`, jamais `hardLock`).
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
      // Impayé CONFIRMÉ au-delà de la grâce : hard-lock si le plan y est éligible
      // (privé), sinon lecture seule (écoles publiques/État jamais bloquées).
      final expired =
          hardLockEligible ? LicensePhase.hardLock : LicensePhase.readOnly;
      if (expired.index > phase.index) phase = expired;
    } else if (overdue >= 0 && phase == LicensePhase.active) {
      phase = LicensePhase.grace;
    }
  }

  return phase;
}
