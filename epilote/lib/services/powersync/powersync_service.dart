import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_connector.dart';
import 'powersync_schema.dart';

// ─── Base de données PowerSync (SQLite local) ──────────────────────────────

/// Instance globale de la base de données PowerSync.
/// Utilisée uniquement par le personnel scolaire (tout rôle SAUF
/// super_admin et admin_groupe, qui passent par Supabase direct).
late PowerSyncDatabase db;

/// Vrai si le rôle correspond au personnel scolaire (offline-first).
/// super_admin et admin_groupe sont online/Supabase direct → exclus.
/// ⚠️ La valeur 'utilisateur' N'EXISTE PAS dans l'enum user_role :
/// le personnel = enseignant, secretaire, cpe, comptable, surveillant,
/// directeur, proviseur, parent, eleve, infirmier, responsable_cantine.
bool _isStaffRole(String? role) =>
    role != null && role != 'super_admin' && role != 'admin_groupe';

/// Rôle du dernier utilisateur connecté (mis en cache pour l'offline).
String? _cachedRole;

/// Initialise PowerSync : ouvre la base SQLite locale.
/// La connexion réseau est conditionnée au rôle (utilisateur seulement).
Future<void> initPowerSync() async {
  final dir  = await getApplicationDocumentsDirectory();
  final path = join(dir.path, 'epilote_v3.db');

  db = PowerSyncDatabase(schema: schema, path: path);
  await db.initialize();

  final supabase  = Supabase.instance.client;
  final connector = SupabasePowerSyncConnector(supabase);

  // Connexion au démarrage si session existante ET rôle personnel scolaire
  if (supabase.auth.currentSession != null) {
    final role = await _resolveRole(supabase);
    if (_isStaffRole(role)) {
      db.connect(connector: connector);
    }
  }

  // Réagir aux changements de session
  supabase.auth.onAuthStateChange.listen((data) async {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
        final role = await _resolveRole(supabase);
        if (_isStaffRole(role)) {
          db.connect(connector: connector);
        }
      case AuthChangeEvent.signedOut:
        _cachedRole = null;
        await db.disconnectAndClear();
      case AuthChangeEvent.tokenRefreshed:
        // Renouveler les credentials uniquement si déjà connecté (utilisateur)
        if (db.currentStatus.connected) {
          connector.prefetchCredentials();
        }
      default:
        break;
    }
  });
}

/// Résout le rôle de l'utilisateur connecté.
/// Priorité : SQLite local (offline-safe) → Supabase (premier login réseau).
Future<String?> _resolveRole(SupabaseClient supabase) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;

  // 1. SQLite local (fonctionne hors-ligne — sauf premier démarrage)
  try {
    final rows = await db.execute(
      'SELECT role FROM profiles WHERE id = ? LIMIT 1',
      [uid],
    );
    if (rows.isNotEmpty) {
      _cachedRole = rows.first['role'] as String?;
      return _cachedRole;
    }
  } catch (_) {}

  // 2. Supabase (premier login — nécessite le réseau)
  try {
    final row = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    _cachedRole = row?['role'] as String?;
    return _cachedRole;
  } catch (_) {
    return _cachedRole; // utiliser le cache si réseau indisponible
  }
}

// ─── Providers Riverpod ────────────────────────────────────────────────────

final powerSyncProvider = Provider<PowerSyncDatabase>((ref) => db);

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(powerSyncProvider).statusStream;
});

/// Vrai quand la synchronisation PowerSync est active et connectée.
/// N'est vrai que pour le personnel scolaire (cf. _isStaffRole).
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStatusProvider).valueOrNull?.connected ?? false;
});
