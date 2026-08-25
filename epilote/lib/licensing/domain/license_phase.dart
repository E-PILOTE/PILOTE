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
/// - Horloge 1 (métier) : `validTo` dépassé ⇒ si [hardLockEligible] (cas normal,
///   flag `hard_lock` émis pour tout groupe provisionné) → `hardLock` DÈS LE
///   PREMIER JOUR DE DÉPASSEMENT (aucune grâce). Sinon (flag absent :
///   fail-soft) → échelle douce grâce (≤ [graceDays]) → lecture seule.
///
///   ⚠️ « Dépassé » se compte en JOURS CIVILS : le jour de l'échéance est le
///   dernier jour PAYÉ, il reste `active`. Ne jamais revenir à une soustraction
///   brute `now - validTo` — `validTo` est à minuit, `now` non, et la coupure
///   repartirait 24 h trop tôt (cf. le groupe de tests « le jour de l'échéance
///   est encore payé »).
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
    // Une échéance est une DATE, pas un instant : `valid_to` se parse à MINUIT
    // alors que `now` porte l'heure courante. Soustraire les deux bruts donnait
    // `overdue == 0` dès 00 h 00 LE JOUR de l'échéance — le hard-lock frappait
    // donc le dernier jour PAYÉ, une journée avant l'heure. Pire, le chemin
    // online (`computeSubscriptionAccess`, via `daysUntilDate`) compte ce même
    // jour comme entitlé : le même client, le même jour, était actif côté
    // admin_groupe et coupé dans ses écoles.
    //
    // On ramène donc les deux bornes au jour civil, comme `daysUntilDate`.
    // `overdue == 0` = jour de l'échéance = ENCORE PAYÉ ; le couperet tombe à
    // `overdue > 0`, ce que dit l'ADR-0009 (« `valid_to` DÉPASSÉ »).
    final overdue = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(validTo.year, validTo.month, validTo.day))
        .inDays; // >0 si échu ; 0 = dernier jour payé
    if (overdue > 0) {
      if (hardLockEligible) {
        // Blocage LE JOUR MÊME : dès l'échéance, hard-lock (aucune grâce). Tous
        // les groupes provisionnés portent le flag → traitement uniforme.
        if (LicensePhase.hardLock.index > phase.index) {
          phase = LicensePhase.hardLock;
        }
      } else {
        // Filet fail-soft (flag `hard_lock` absent : licence héritée, dormant) :
        // on conserve l'échelle douce grâce (≤ graceDays) → lecture seule.
        if (overdue > graceDays) {
          if (LicensePhase.readOnly.index > phase.index) {
            phase = LicensePhase.readOnly;
          }
        } else if (phase == LicensePhase.active) {
          phase = LicensePhase.grace;
        }
      }
    }
  }

  return phase;
}
