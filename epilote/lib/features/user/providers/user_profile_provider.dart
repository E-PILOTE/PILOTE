import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile_model.dart';
import '../../../features/auth/providers/active_agent_provider.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Profil du membre courant — lecture/écriture 100% offline-first (SQLite).
//  La table `profiles` est synchronisée par PowerSync : on lit la ligne du
//  membre en réactif (db.watch) et on l'édite en local (db.execute) ; PowerSync
//  remonte la modification vers Supabase à la prochaine connexion.
// ════════════════════════════════════════════════════════════════════════════

/// Ligne `profiles` de l'AGENT ACTIF, en réactif depuis SQLite.
/// Source de vérité de l'écran « Mon profil » (mise à jour instantanée après
/// édition, sans dépendre du réseau). Sur poste partagé, suit l'agent au
/// clavier (cf. [activeAgentIdProvider]), pas seulement l'utilisateur appareil.
final myProfileRowProvider =
    StreamProvider.autoDispose<ProfileModel?>((ref) {
  final id = ref.watch(activeAgentIdProvider);
  if (id == null || id.isEmpty) return Stream.value(null);
  return db
      .watch('SELECT * FROM profiles WHERE id = ? LIMIT 1', parameters: [id])
      .map((rows) => rows.isEmpty ? null : ProfileModel.fromMap(rows.first));
});

/// Met à jour l'identité du membre (prénom / nom / téléphone) en local.
/// Écriture offline-first : remontée vers Supabase gérée par le connecteur.
Future<void> updateMyProfile({
  required String id,
  required String firstName,
  required String lastName,
  String? phone,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE profiles
    SET    first_name = ?,
           last_name  = ?,
           phone      = ?,
           updated_at = ?
    WHERE  id = ?
    ''',
    [firstName.trim(), lastName.trim(), phone?.trim(), now, id],
  );
}
