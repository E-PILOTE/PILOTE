import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Codes d'erreur PostgreSQL non-récupérables (on abandonne la transaction).
final List<RegExp> _fatalResponseCodes = [
  RegExp(r'^22...$'), // Class 22 — Data Exception
  RegExp(r'^23...$'), // Class 23 — Integrity Constraint Violation
  RegExp(r'^42501$'), // INSUFFICIENT PRIVILEGE (RLS violation)
];

/// Détail d'une transaction locale rejetée DÉFINITIVEMENT par le serveur
/// (contrainte d'intégrité, RLS, données invalides) puis abandonnée.
class UploadDropInfo {
  UploadDropInfo({
    required this.at,
    required this.code,
    required this.message,
    required this.ops,
  });
  final DateTime at;
  final String code;
  final String message;
  final List<String> ops; // ex. "patch academic_years#<id>"
}

/// Dernière transaction abandonnée pour erreur non-récupérable.
/// ⚠️ Une transaction abandonnée = écritures locales DÉFINITIVEMENT perdues
/// (on ne peut pas retenter une violation de contrainte sans bloquer la file).
/// Exposé pour que cette perte soit OBSERVABLE (diagnostic + futur indicateur
/// « santé de synchro ») au lieu d'être silencieuse.
final ValueNotifier<UploadDropInfo?> lastFatalUploadError =
    ValueNotifier<UploadDropInfo?>(null);

/// URL du service PowerSync Cloud E-PILOTE
const String _powerSyncUrl =
    'https://6a185941234fa2bf51a66757.powersync.journeyapps.com';

/// Colonnes Postgres `jsonb` stockées en TEXT dans SQLite : elles doivent être
/// décodées avant l'upsert, sinon la colonne jsonb reçoit une CHAÎNE JSON au
/// lieu de la structure (et les lecteurs en ligne ne la parsent plus).
const Map<String, Set<String>> _jsonbColumns = {
  'messages':                {'attachments'},
  'announcements':           {'attachments'},
  'events':                  {'attachments'},
  'notifications':           {'data'},
  'support_tickets':         {'attachments'},
  'support_ticket_messages': {'attachments'},
};

Map<String, dynamic> _decodeJsonbColumns(String table, Map<String, dynamic> data) {
  final cols = _jsonbColumns[table];
  if (cols == null) return data;
  final out = Map<String, dynamic>.from(data);
  for (final c in cols) {
    final v = out[c];
    if (v is String && v.isNotEmpty) {
      try {
        out[c] = jsonDecode(v);
      } catch (_) {/* valeur non-JSON : on laisse telle quelle */}
    }
  }
  return out;
}

/// Connecteur PowerSync ↔ Supabase.
/// Gère l'authentification JWT et l'upload des mutations locales.
class SupabasePowerSyncConnector extends PowerSyncBackendConnector {
  SupabasePowerSyncConnector(this._supabase);

  final SupabaseClient _supabase;
  Future<void>? _refreshFuture;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    await _refreshFuture;

    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    if (session.isExpired) {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session == null) return null;
    }

    final current = _supabase.auth.currentSession!;
    return PowerSyncCredentials(
      endpoint: _powerSyncUrl,
      token: current.accessToken,
      userId: current.user.id,
      expiresAt: current.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(current.expiresAt! * 1000),
    );
  }

  @override
  void invalidateCredentials() {
    // Déclenche un refresh de session quand PowerSync reçoit une erreur d'auth.
    // Utile après une longue période offline où le JWT a expiré.
    _refreshFuture = _supabase.auth
        .refreshSession()
        .timeout(const Duration(seconds: 5))
        .then((_) => null, onError: (_) => null);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (final op in transaction.crud) {
        final table = _supabase.from(op.table);

        switch (op.op) {
          case UpdateType.put:
            await table.upsert(_decodeJsonbColumns(
                op.table, {...op.opData ?? {}, 'id': op.id}));
          case UpdateType.patch:
            await table
                .update(_decodeJsonbColumns(op.table, op.opData!))
                .eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          _fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        // Erreur non-récupérable (contrainte/RLS/données) : on ne peut pas
        // retenter sans bloquer la file → on abandonne la transaction. Mais
        // JAMAIS en silence : on journalise les opérations rejetées pour que la
        // perte éventuelle soit observable (diagnostic + futur écran santé).
        final ops = transaction.crud
            .map((o) => '${o.op.name} ${o.table}#${o.id}')
            .toList();
        lastFatalUploadError.value = UploadDropInfo(
          at: DateTime.now(),
          code: e.code ?? '?',
          message: e.message,
          ops: ops,
        );
        debugPrint(
          '⚠️ PowerSync — transaction ABANDONNÉE (code ${e.code}). '
          'Écritures locales perdues : ${ops.join(", ")}. ${e.message}',
        );
        await transaction.complete();
      } else {
        // Erreur réseau ou serveur temporaire → sera retenté automatiquement
        rethrow;
      }
    }
  }
}
