import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Codes d'erreur PostgreSQL non-récupérables (on abandonne la transaction).
final List<RegExp> _fatalResponseCodes = [
  RegExp(r'^22...$'), // Class 22 — Data Exception
  RegExp(r'^23...$'), // Class 23 — Integrity Constraint Violation
  RegExp(r'^42501$'), // INSUFFICIENT PRIVILEGE (RLS violation)
];

/// URL du service PowerSync Cloud E-PILOTE
const String _powerSyncUrl =
    'https://6a185941234fa2bf51a66757.powersync.journeyapps.com';

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
            await table.upsert({...op.opData ?? {}, 'id': op.id});
          case UpdateType.patch:
            await table.update(op.opData!).eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          _fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        // Erreur non-récupérable : abandonner pour ne pas bloquer la file.
        await transaction.complete();
      } else {
        // Erreur réseau ou serveur temporaire → sera retenté automatiquement
        rethrow;
      }
    }
  }
}
