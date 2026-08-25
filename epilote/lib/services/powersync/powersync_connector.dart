import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

// ─── Instance PowerSync Cloud ───────────────────────────────────────────────
//
// ⚠️ Jusqu'au 2026-08-04, l'application pointait EN DUR sur l'instance
// « Development ». Mille écoles se seraient synchronisées, le 2 octobre, sur
// une instance de développement — pendant que l'instance « Production »,
// créée mais jamais provisionnée, restait éteinte. Aucune bascule n'aurait
// alors été possible sans republier tout le parc.
//
// Les deux instances répliquent la MÊME base Supabase : ce qui change est le
// service de synchro, pas les données. Un poste qui bascule d'une instance à
// l'autre retélécharge ses buckets — d'où l'intérêt de le faire maintenant,
// tant que le parc tient sur un poste de recette.
//
// Surchargeable au build, pour tester sans toucher au code :
//   flutter build linux --dart-define=POWERSYNC_URL=$kPowerSyncDevelopment
const String kPowerSyncProduction =
    'https://6a185943234fa2bf51a66759.powersync.journeyapps.com';
const String kPowerSyncDevelopment =
    'https://6a185941234fa2bf51a66757.powersync.journeyapps.com';

const String _powerSyncUrl = String.fromEnvironment(
  'POWERSYNC_URL',
  defaultValue: kPowerSyncProduction,
);

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

/// Libellés lisibles par table pour résumer un échec à l'utilisateur final
/// (« Inscription d'élève n'a pas pu être synchronisée »). Les tables liées
/// d'une même action partagent le même libellé pour ne pas le répéter.
const Map<String, String> _tableHumanLabel = {
  'students':          "Inscription d'élève",
  'class_enrollments': "Inscription d'élève",
  'student_tutors':    "Inscription d'élève",
  'student_documents': "Document d'élève",
  'student_payments':   'Paiement',
  'expenses':           'Dépense',
  'grades':             'Note',
  'evaluations':        'Évaluation',
  'attendance_records': 'Présence',
  'attendance_entries': 'Présence',
  'leave_requests':     'Congé',
  'staff_attendance':   'Présence du personnel',
  'messages':          'Message',
  'announcements':     'Annonce',
};

/// Résume les tables touchées par une transaction abandonnée en libellés
/// lisibles et dédupliqués (ex. « Inscription d'élève, Paiement »).
String _summarizeOps(Iterable<String> tables) {
  final labels = <String>{};
  for (final t in tables) {
    labels.add(_tableHumanLabel[t] ?? t);
  }
  return labels.join(', ');
}

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
        final summary =
            _summarizeOps(transaction.crud.map((o) => o.table));
        final at = DateTime.now();
        lastFatalUploadError.value = UploadDropInfo(
          at: at,
          code: e.code ?? '?',
          message: e.message,
          ops: ops,
        );
        // Journal LOCAL durable (table local-only) : la perte reste visible et
        // acquittable même après redémarrage ou si l'utilisateur n'était pas sur
        // l'écran concerné au moment de la synchro en arrière-plan.
        try {
          await database.execute(
            'INSERT INTO sync_failures '
            '(id, at, code, message, ops, summary, acknowledged) '
            'VALUES (?, ?, ?, ?, ?, ?, 0)',
            [
              const Uuid().v4(),
              at.toUtc().toIso8601String(),
              e.code ?? '?',
              e.message,
              jsonEncode(ops),
              summary,
            ],
          );
        } catch (logErr) {
          debugPrint('⚠️ PowerSync — écriture journal sync_failures échouée : $logErr');
        }
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
