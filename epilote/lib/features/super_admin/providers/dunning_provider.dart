import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/subscription_days.dart';
import '../../admin_groupe/providers/subscription_access_provider.dart';
import '../../auth/providers/auth_provider.dart';

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
  int graceDays = kSubscriptionGraceDays,
  int soonDays = kSubscriptionAlertDays,
}) {
  final daysLeft = daysUntilDate(end, now);
  if (daysLeft == null) return null;

  if (daysLeft >= 0) {
    if (isEntitlingStatus(status) && daysLeft <= soonDays) {
      return DunningBucket.expiringSoon;
    }
    return null; // actif et loin → hors recouvrement
  }

  // Échu. La grâce ne vaut que pour une expiration NATURELLE et récente ;
  // 'suspended' (impayé posé par le super_admin) et 'cancelled' → overdue direct.
  if (isNaturalExpiry(status) && -daysLeft <= graceDays) {
    return DunningBucket.inGrace;
  }
  return DunningBucket.overdue;
}

/// Une ligne de recouvrement (un groupe concerné).
class DunningRow {
  const DunningRow({
    required this.groupId,
    required this.groupName,
    required this.planName,
    required this.end,
    required this.daysLeft,
    required this.amountDueXaf,
    required this.bucket,
  });
  final String groupId;
  final String groupName;
  final String planName;
  final DateTime? end;
  final int? daysLeft; // >=0 restants ; <0 dépassement
  final int amountDueXaf; // impayés (overdue + pending) agrégés
  final DunningBucket bucket;
}

/// Groupes en recouvrement (échéance proche / grâce / échus-impayés), triés par
/// date de fin croissante. Online (super_admin). Fail-soft : erreur → liste vide.
final dunningProvider =
    FutureProvider.autoDispose<List<DunningRow>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  // Grâce ET fenêtre « échéance proche » réglables (super_admin) — la vue
  // recouvrement doit lister exactement les groupes qui voient le bandeau.
  final settings = await ref.watch(subscriptionSettingsProvider.future);

  try {
    final groups = await client
        .from('school_groups')
        .select('id, name, subscription_status, subscription_end, '
            'subscription_plans!plan_id(name)') as List;

    // Impayés par groupe (statuts pending/overdue).
    final Map<String, int> due = {};
    try {
      final inv = await client
          .from('group_invoices')
          .select('group_id, amount_xaf, status')
          .inFilter('status', ['pending', 'overdue']) as List;
      for (final r in inv) {
        final m = r as Map;
        final gid = m['group_id'] as String?;
        if (gid == null) continue;
        due[gid] = (due[gid] ?? 0) + ((m['amount_xaf'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}

    final rows = <DunningRow>[];
    for (final r in groups) {
      final m = r as Map;
      final status = (m['subscription_status'] as String?) ?? 'active';
      final endRaw = m['subscription_end'] as String?;
      final end = endRaw != null ? DateTime.tryParse(endRaw) : null;
      final bucket = bucketDunning(
        status: status,
        end: end,
        now: now,
        graceDays: settings.graceDays,
        soonDays: settings.alertDays,
      );
      if (bucket == null) continue;

      final gid = m['id'] as String;
      final daysLeft = daysUntilDate(end, now);
      rows.add(DunningRow(
        groupId: gid,
        groupName: (m['name'] as String?) ?? '—',
        planName: (m['subscription_plans'] as Map?)?['name'] as String? ?? '—',
        end: end,
        daysLeft: daysLeft,
        amountDueXaf: due[gid] ?? 0,
        bucket: bucket,
      ));
    }
    rows.sort((a, b) {
      final ea = a.end, eb = b.end;
      if (ea == null && eb == null) return 0;
      if (ea == null) return 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });
    return rows;
  } catch (_) {
    return const []; // fail-soft : jamais d'écran d'erreur bloquant
  }
});
