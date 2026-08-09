import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/subscription_days.dart';
import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';

/// Phase d'accès dérivée de l'abonnement du groupe (chemin ONLINE admin_groupe).
///
/// Cascade DOUCE (jamais de blocage sec) :
///   active   → tout fonctionne.
///   grace    → échu récemment : accès complet + bandeau d'alerte insistant.
///   readOnly → échu au-delà de la grâce (ou suspendu/résilié) : lecture seule,
///              l'admin peut toujours consulter, exporter et RENOUVELER.
enum SubscriptionPhase { active, grace, readOnly }

/// Nombre de jours de grâce après la date de fin avant de passer en lecture seule.
const int kSubscriptionGraceDays = 15;

/// Fenêtre d'alerte AVANT l'échéance : le bandeau ne s'allume qu'à moins de
/// [kSubscriptionAlertDays] jours de la fin.
///
/// Valait 30 en dur — le bandeau criait un mois entier à l'avance, tous les
/// jours, sur toutes les pages. Une alerte permanente n'est plus une alerte :
/// on la lit une fois puis on cesse de la voir, y compris la veille de la
/// coupure. Une semaine, c'est court assez pour rester crédible et long assez
/// pour émettre et payer une facture.
///
/// Réglable par le super_admin (`platform_settings.subscription_alert_days`,
/// lu via `subscriptionSettingsProvider`) ; cette constante n'est que le
/// filet de sécurité quand le réglage est absent ou injoignable.
const int kSubscriptionAlertDays = 7;

class SubscriptionAccess {
  const SubscriptionAccess({
    required this.phase,
    required this.status,
    required this.end,
    required this.daysLeft,
    this.alertDays = kSubscriptionAlertDays,
  });

  /// État « inconnu » = fail-soft : on n'a pas pu déterminer l'abonnement
  /// (pas de groupe, erreur réseau, chargement) → on N'ENTRAVE RIEN.
  factory SubscriptionAccess.unknown() => const SubscriptionAccess(
        phase: SubscriptionPhase.active,
        status: 'unknown',
        end: null,
        daysLeft: null,
      );

  final SubscriptionPhase phase;
  final String status; // valeur brute school_groups.subscription_status
  final DateTime? end;
  final int? daysLeft; // >=0 : jours restants ; <0 : jours de dépassement

  /// Fenêtre d'alerte effectivement appliquée (réglage plateforme).
  final int alertDays;

  /// Verrou d'écriture (2ᵉ verrou « plan », version online admin_groupe).
  bool get canWrite => phase != SubscriptionPhase.readOnly;
  bool get isActive => phase == SubscriptionPhase.active;

  /// Alerte de fin proche alors que l'abonnement est encore actif.
  bool get expiresSoon =>
      phase == SubscriptionPhase.active &&
      daysLeft != null &&
      daysLeft! >= 0 &&
      daysLeft! <= alertDays;
}

/// Calcul pur (testable) de la phase à partir du statut brut + date de fin.
/// `today` est injectable pour les tests ; par défaut = maintenant.
SubscriptionAccess computeSubscriptionAccess({
  required String status,
  required DateTime? end,
  DateTime? today,
  int graceDays = kSubscriptionGraceDays,
  int alertDays = kSubscriptionAlertDays,
}) {
  // Comparaison au jour près (les dates de fin sont des DATE, sans heure).
  final int? daysLeft = daysUntilDate(end, today);

  final dateOk = daysLeft == null || daysLeft >= 0;

  // Toujours entitlé : statut porteur ET date non dépassée.
  if (isEntitlingStatus(status) && dateOk) {
    return SubscriptionAccess(
      phase: SubscriptionPhase.active,
      status: status,
      end: end,
      daysLeft: daysLeft,
      alertDays: alertDays,
    );
  }

  // Échu. La grâce ne s'applique qu'à une expiration NATURELLE et récente ;
  // 'suspended' (impayé, posé par le super_admin) et 'cancelled' (résilié)
  // passent directement en lecture seule.
  final overdueDays = daysLeft == null ? 1 << 30 : -daysLeft;
  final inGrace =
      isNaturalExpiry(status) && daysLeft != null && overdueDays <= graceDays;

  return SubscriptionAccess(
    phase: inGrace ? SubscriptionPhase.grace : SubscriptionPhase.readOnly,
    status: status,
    end: end,
    daysLeft: daysLeft,
    alertDays: alertDays,
  );
}

/// Garde d'écriture du soft-gate admin_groupe. À appeler en tête d'un handler
/// mutant (création/modification). Renvoie `true` si l'écriture est autorisée ;
/// sinon affiche un message « lecture seule » et renvoie `false`.
///
/// Fail-soft : n'entrave QUE l'état explicitement `readOnly`. Si l'abonnement
/// est inconnu/en chargement/en erreur → autorise (ne bloque jamais au doute).
bool ensureSubscriptionWritable(WidgetRef ref, BuildContext context) {
  final access = ref.read(subscriptionAccessProvider).valueOrNull;
  if (access != null && !access.canWrite) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: kRed,
      content: const Text('Abonnement expiré — création suspendue. '
          'Renouvelez pour ajouter de nouvelles écoles ou utilisateurs.'),
    ));
    return false;
  }
  return true;
}

/// Réglages d'abonnement pilotés par le super_admin (écran Paramètres), lus via
/// la RPC curée `get_subscription_settings` — RLS-safe : elle n'expose que ces
/// deux nombres, jamais le reste de `platform_settings`.
class SubscriptionSettings {
  const SubscriptionSettings({required this.graceDays, required this.alertDays});

  /// Défauts codés en dur : le filet quand la RPC est injoignable (terrain).
  static const fallback = SubscriptionSettings(
    graceDays: kSubscriptionGraceDays,
    alertDays: kSubscriptionAlertDays,
  );

  final int graceDays; // jours APRÈS échéance avant la lecture seule
  final int alertDays; // jours AVANT échéance où le bandeau s'allume
}

/// Réglages d'abonnement, rafraîchis à chaque ouverture de session.
///
/// `alert_days` était le trou : la RPC le renvoyait déjà, le client ne lisait
/// que `grace_days` et retombait sur un `<= 30` codé en dur. Le super_admin
/// pouvait donc régler la fenêtre d'alerte sans qu'aucun bandeau ne bouge.
///
/// Fail-soft : au doute (réseau, RPC absente) → défauts. Online — partagé par
/// l'espace admin_groupe ET la vue recouvrement super_admin.
final subscriptionSettingsProvider =
    FutureProvider.autoDispose<SubscriptionSettings>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  int readDays(Map map, String key, int fallback) {
    final v = map[key];
    if (v is int) return v > 0 ? v : fallback;
    final parsed = int.tryParse('$v');
    // 0 ou négatif = réglage vide/aberrant → on garde le défaut plutôt que
    // d'éteindre l'alerte (ou la grâce) sans que personne l'ait demandé.
    return (parsed != null && parsed > 0) ? parsed : fallback;
  }

  try {
    final r = await client.rpc('get_subscription_settings');
    final map = r is Map ? r : const <String, dynamic>{};
    return SubscriptionSettings(
      graceDays: readDays(map, 'grace_days', kSubscriptionGraceDays),
      alertDays: readDays(map, 'alert_days', kSubscriptionAlertDays),
    );
  } catch (_) {
    return SubscriptionSettings.fallback;
  }
});

/// État d'accès abonnement du groupe courant (online). Fail-soft : toute erreur
/// ⇒ `unknown()` (n'entrave rien). N'est consommé que dans l'espace admin_groupe.
final subscriptionAccessProvider =
    FutureProvider.autoDispose<SubscriptionAccess>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || groupId.isEmpty) return SubscriptionAccess.unknown();

  final client = ref.watch(supabaseClientProvider);

  // Realtime : rafraîchit le bandeau DÈS que l'abonnement du groupe change
  // (renouvellement, changement de plan par le super_admin). Sans cela, le
  // bandeau ne se mettait à jour qu'au retour au premier plan / tick 6 h, d'où
  // une désynchro passagère avec la page Abonnement (qui, elle, écoute déjà
  // school_groups). `school_groups` est publiée en Realtime depuis la mig 0032.
  Timer? debounce;
  try {
    final channel = client.channel('sub_access_$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'school_groups',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: groupId),
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 500), ref.invalidateSelf);
          },
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Grâce ET fenêtre d'alerte réglables — plus de valeur codée en dur.
  final settings = await ref.watch(subscriptionSettingsProvider.future);
  try {
    final row = await client
        .from('school_groups')
        .select('subscription_status, subscription_end')
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return SubscriptionAccess.unknown();

    final status = (row['subscription_status'] as String?) ?? 'active';
    final endRaw = row['subscription_end'] as String?;
    final end = endRaw != null ? DateTime.tryParse(endRaw) : null;
    return computeSubscriptionAccess(
      status: status,
      end: end,
      graceDays: settings.graceDays,
      alertDays: settings.alertDays,
    );
  } catch (_) {
    // Fail-soft absolu : on ne verrouille jamais sur une incertitude.
    return SubscriptionAccess.unknown();
  }
});
