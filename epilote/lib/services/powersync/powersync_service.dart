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

/// File de sérialisation des transitions d'authentification.
/// Indispensable pour les POSTES PARTAGÉS (ex. Proviseur puis Comptable sur le
/// même ordinateur) : garantit que la PURGE locale d'un utilisateur qui se
/// déconnecte (`disconnectAndClear`) se termine ENTIÈREMENT avant que la
/// connexion/synchro du suivant ne démarre. Sans ça, les deux opérations
/// asynchrones pourraient se chevaucher → fuite de données entre comptes.
Future<void> _authQueue = Future<void>.value();

void _enqueueAuth(Future<void> Function() op) {
  _authQueue = _authQueue.then((_) => op()).catchError((_) {});
}

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

  // Réagir aux changements de session. Les transitions connexion/déconnexion
  // sont SÉRIALISÉES (_enqueueAuth) : sur un poste partagé, la purge du compte
  // sortant se termine avant la synchro du compte entrant (zéro chevauchement).
  supabase.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
        _enqueueAuth(() async {
          final role = await _resolveRole(supabase);
          if (_isStaffRole(role)) {
            db.connect(connector: connector);
          }
        });
      case AuthChangeEvent.signedOut:
        _enqueueAuth(() async {
          _cachedRole = null;
          await db.disconnectAndClear();
        });
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

/// État de synchro pour l'UI — logique OFFLINE-FIRST : « à jour » dès qu'une
/// synchro a réussi (`lastSyncedAt != null`), même si la connexion live n'est
/// pas active à l'instant T. Évite d'afficher « Hors ligne » alors que les
/// données locales sont complètes et utilisables.
enum SyncUiState { synced, syncing, offline }

final syncUiStateProvider = Provider<SyncUiState>((ref) {
  final s = ref.watch(syncStatusProvider).valueOrNull;
  if (s == null) return SyncUiState.offline;
  if (s.downloading || s.uploading || s.connecting) return SyncUiState.syncing;
  if (s.lastSyncedAt != null) return SyncUiState.synced;
  return s.connected ? SyncUiState.syncing : SyncUiState.offline;
});

/// Horodatage de la dernière synchro réussie (ou null).
final lastSyncedAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncStatusProvider).valueOrNull?.lastSyncedAt;
});
