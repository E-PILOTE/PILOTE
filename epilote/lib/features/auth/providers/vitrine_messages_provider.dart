import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/booleen_offline.dart';
import '../../../services/powersync/powersync_service.dart';

/// Un message de service est-il « vivant » maintenant ? Actif ET dans sa fenêtre
/// de dates (bornes optionnelles). Fonction pure, testable.
bool isMessageLive(DateTime now, DateTime? starts, DateTime? ends, bool active) {
  if (!active) return false;
  if (starts != null && now.isBefore(starts)) return false;
  if (ends != null && now.isAfter(ends)) return false;
  return true;
}

DateTime? _parse(String? s) => s == null ? null : DateTime.tryParse(s);

/// Messages de service à afficher sur la vitrine (offline, `db.watch`). Filtrés
/// actifs + dans leur fenêtre, plafonnés à 3 (le carrousel de `VitrineShell`).
final serviceMessagesProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  return db
      .watch(
        'SELECT body, is_active, starts_at, ends_at '
        'FROM platform_service_messages',
      )
      .map((rows) {
    final now = DateTime.now();
    final live = <String>[];
    for (final r in rows) {
      // Même correction que pour les partenaires : par défaut VRAI.
      final active = actifOffline(r['is_active']);
      final body = (r['body'] as String? ?? '').trim();
      if (body.isEmpty) continue;
      if (isMessageLive(now, _parse(r['starts_at'] as String?),
          _parse(r['ends_at'] as String?), active)) {
        live.add(body);
      }
    }
    return live.take(3).toList();
  });
});
