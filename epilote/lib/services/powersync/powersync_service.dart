import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_connector.dart';
import 'powersync_schema.dart';
import 'upload_outbox.dart';

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

/// Vrai quand la synchro offline est ACTIVE sur cet appareil (= session du
/// personnel scolaire). Seuls ces appareils mettent des fichiers en file
/// d'attente : chez super_admin / admin_groupe, online par conception, un échec
/// réseau doit rester un échec visible plutôt qu'une promesse d'envoi différé.
bool _syncEnabled = false;
bool get isOfflineCapableDevice => _syncEnabled;

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

// ─── Travail local non synchronisé ──────────────────────────────────────────

/// Écritures locales en attente de remontée (`ps_crud`) + fichiers en attente.
/// Sert de VERROU : tant que ce n'est pas zéro, la base locale ne doit pas être
/// purgée, et l'utilisateur doit être averti avant de se déconnecter.
class PendingLocalWork {
  const PendingLocalWork({required this.writes, required this.files});
  final int writes;
  final int files;

  int get total => writes + files;
  bool get isEmpty => total == 0;
}

/// Compte ce qui n'est pas encore parti. Ne throw jamais (0 en cas de doute…
/// mais on préfère surestimer : voir le `catch` — on renvoie 1 si on ne sait
/// pas, pour ne JAMAIS purger sur une incertitude).
Future<PendingLocalWork> pendingLocalWork() async {
  try {
    final stats = await db.getUploadQueueStats();
    final row = await db.getOptional('SELECT COUNT(*) AS n FROM upload_outbox');
    return PendingLocalWork(
      writes: stats.count,
      files: (row?['n'] as int?) ?? 0,
    );
  } catch (_) {
    // Impossible de compter → on suppose qu'il reste du travail plutôt que de
    // risquer une purge destructrice sur une base qu'on n'arrive pas à lire.
    return const PendingLocalWork(writes: 1, files: 0);
  }
}

Future<bool> hasPendingLocalWork() async => !(await pendingLocalWork()).isEmpty;

// ─── Mémoire « dernier agent de cet appareil » ──────────────────────────────
// Hors de la base PowerSync EXPRÈS : elle doit survivre à `powersync_clear()`
// et à un redémarrage de l'app, sinon un appareil réattribué ne serait pas purgé.

const _kLastDeviceUserKey = 'epilote.last_device_user';

Future<String?> _readLastDeviceUser() async {
  try {
    return (await SharedPreferences.getInstance())
        .getString(_kLastDeviceUserKey);
  } catch (_) {
    return null;
  }
}

Future<void> _writeLastDeviceUser(String uid) async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kLastDeviceUserKey, uid);
  } catch (_) {/* fail-soft */}
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
      _syncEnabled = true;
      db.connect(connector: connector);
    }
  }

  // Vidange de la file d'attente de FICHIERS dès que le réseau revient.
  // PowerSync remonte les écritures SQL tout seul ; les fichiers, eux, n'ont
  // aucun mécanisme de reprise → c'est ici qu'on le leur donne.
  db.statusStream.listen((status) {
    if (status.connected && _syncEnabled) {
      unawaited(flushUploadOutbox(supabase));
    }
  });

  // Réagir aux changements de session. Les transitions connexion/déconnexion
  // sont SÉRIALISÉES (_enqueueAuth) : sur un poste partagé, la purge du compte
  // sortant se termine avant la synchro du compte entrant (zéro chevauchement).
  supabase.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
        _enqueueAuth(() async {
          // L'appareil change de main → purge de ce qui restait du précédent.
          // C'est ICI qu'on purge (et non à la déconnexion) : tant que le même
          // agent revient, son travail en attente doit le retrouver intact.
          final uid = supabase.auth.currentUser?.id;
          final previous = await _readLastDeviceUser();
          if (previous != null && uid != null && previous != uid) {
            await db.disconnectAndClear();
            await purgeUploadOutboxFiles();
          }
          if (uid != null) await _writeLastDeviceUser(uid);

          final role = await _resolveRole(supabase);
          if (_isStaffRole(role)) {
            _syncEnabled = true;
            db.connect(connector: connector);
          }
        });
      case AuthChangeEvent.signedOut:
        _enqueueAuth(() async {
          _cachedRole = null;
          _syncEnabled = false;

          // ⚠️ NE JAMAIS DÉTRUIRE DU TRAVAIL NON SYNCHRONISÉ.
          // `disconnectAndClear()` exécute `powersync_clear()` : il efface la
          // base locale ET la file d'écritures en attente (ps_crud). Une école
          // qui travaille hors-ligne et se déconnecte perdrait sa journée —
          // silencieusement. Or `signedOut` peut aussi être émis TOUT SEUL
          // (jeton de rafraîchissement invalidé après une longue coupure).
          // Donc : s'il reste quoi que ce soit à remonter, on se contente de
          // se déconnecter. Les données restent, et repartiront à la prochaine
          // ouverture de session du même agent. La purge multi-tenant, elle,
          // a lieu au signedIn d'un utilisateur DIFFÉRENT (ci-dessus).
          if (await hasPendingLocalWork()) {
            await db.disconnect();
            return;
          }
          await db.disconnectAndClear();
          await purgeUploadOutboxFiles();
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
