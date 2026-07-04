import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class SubscriptionAccess {
  const SubscriptionAccess({
    required this.phase,
    required this.status,
    required this.end,
    required this.daysLeft,
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

  /// Verrou d'écriture (2ᵉ verrou « plan », version online admin_groupe).
  bool get canWrite => phase != SubscriptionPhase.readOnly;
  bool get isActive => phase == SubscriptionPhase.active;

  /// Alerte de fin proche (dans les 30 j) alors que l'abonnement est encore actif.
  bool get expiresSoon =>
      phase == SubscriptionPhase.active &&
      daysLeft != null &&
      daysLeft! >= 0 &&
      daysLeft! <= 30;
}

/// Calcul pur (testable) de la phase à partir du statut brut + date de fin.
/// `today` est injectable pour les tests ; par défaut = maintenant.
SubscriptionAccess computeSubscriptionAccess({
  required String status,
  required DateTime? end,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  // Comparaison au jour près (les dates de fin sont des DATE, sans heure).
  final int? daysLeft = end == null
      ? null
      : DateTime(end.year, end.month, end.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

  final entitling = status == 'active' || status == 'trial';
  final dateOk = daysLeft == null || daysLeft >= 0;

  // Toujours entitlé : statut porteur ET date non dépassée.
  if (entitling && dateOk) {
    return SubscriptionAccess(
        phase: SubscriptionPhase.active, status: status, end: end, daysLeft: daysLeft);
  }

  // Échu. La grâce ne s'applique qu'à une expiration NATURELLE et récente ;
  // 'suspended' (impayé, posé par le super_admin) et 'cancelled' (résilié)
  // passent directement en lecture seule.
  final naturalExpiry = status != 'suspended' && status != 'cancelled';
  final overdueDays = daysLeft == null ? 1 << 30 : -daysLeft;
  final inGrace = naturalExpiry && daysLeft != null && overdueDays <= kSubscriptionGraceDays;

  return SubscriptionAccess(
    phase: inGrace ? SubscriptionPhase.grace : SubscriptionPhase.readOnly,
    status: status,
    end: end,
    daysLeft: daysLeft,
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: Color(0xFFDC2626),
      content: Text('Abonnement expiré — espace en lecture seule. '
          'Renouvelez pour effectuer des modifications.'),
    ));
    return false;
  }
  return true;
}

/// État d'accès abonnement du groupe courant (online). Fail-soft : toute erreur
/// ⇒ `unknown()` (n'entrave rien). N'est consommé que dans l'espace admin_groupe.
final subscriptionAccessProvider =
    FutureProvider.autoDispose<SubscriptionAccess>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || groupId.isEmpty) return SubscriptionAccess.unknown();

  final client = ref.watch(supabaseClientProvider);
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
    return computeSubscriptionAccess(status: status, end: end);
  } catch (_) {
    // Fail-soft absolu : on ne verrouille jamais sur une incertitude.
    return SubscriptionAccess.unknown();
  }
});
