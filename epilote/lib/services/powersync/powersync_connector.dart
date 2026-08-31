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

/// ════════════════════════════════════════════════════════════════════════════
///  LES ERREURS QUE RETENTER NE RÉSOUDRA JAMAIS
///
///  Une colonne ou une table que le serveur ne connaît pas : le poste tourne
///  sur un build antérieur au schéma. PowerSync rejoue alors le lot à l'infini
///  — c'est le comportement CORRECT (rien n'est perdu) mais il est MUET :
///  l'école continue de travailler, tout paraît normal, et plus une seule
///  inscription ne remonte. Jamais.
///
///  ⚠️ On ne les rend PAS fatales. Les rendre fatales jetterait les écritures
///  de l'école pour lui épargner un bandeau — le remède serait pire.
///  On garde le rejeu, et on rend le blocage VISIBLE.
///
///  C'est aussi ce qui tient la migration 0146 en otage : on ne retire pas une
///  colonne tant qu'un poste resté en arrière se bloquerait sans le dire.
/// ════════════════════════════════════════════════════════════════════════════
final List<RegExp> _schemaMismatchCodes = [
  RegExp(r'^42703$'), // undefined_column   — colonne retirée du serveur
  RegExp(r'^42P01$'), // undefined_table    — table renommée ou retirée
  RegExp(r'^42804$'), // datatype_mismatch  — type changé
  RegExp(r'^42883$'), // undefined_function — RPC disparue
  RegExp(r'^42P10$'), // invalid_column_reference (ON CONFLICT)
];

/// Ce code désigne-t-il un désaccord entre le schéma du poste et celui du
/// serveur ? Public pour être vérifiable : la règle vaut d'être testée seule,
/// et `test/sync_blocage_test.dart` s'assure notamment qu'aucun de ces codes
/// n'a été glissé dans `_fatalResponseCodes` — ce qui, au lieu de bloquer,
/// JETTERAIT les écritures de l'école.
bool estDesaccordDeSchema(String? code) =>
    code != null && _schemaMismatchCodes.any((re) => re.hasMatch(code));

/// Ce code fait-il abandonner la transaction (écritures perdues) ?
bool estRefusDefinitif(String? code) =>
    code != null && _fatalResponseCodes.any((re) => re.hasMatch(code));

/// Nombre d'échecs consécutifs d'un MÊME code, hors désaccord de schéma, avant
/// de considérer la file comme bloquée. Un `40001` (sérialisation) ou un
/// `53300` (trop de connexions) se résout tout seul ; cinq fois de suite, non.
const int _kSeuilBlocage = 5;

int _echecsConsecutifs = 0;
String? _dernierCodeRejoue;

/// ⚠️ Vrai AU DÉMARRAGE, délibérément. Le drapeau mémoire repart à faux à
/// chaque lancement, mais la ligne de blocage, elle, survit dans SQLite. Sans
/// cette valeur initiale, la première transaction réussie sauterait l'effacement
/// et le bandeau resterait affiché pour toujours sur un poste réparé — un
/// indicateur qui ment dans ce sens-là ne sera plus jamais cru dans l'autre.
bool _blocagePeutEtreEnBase = true;

/// Vrai tant que la file d'envoi de CE poste est bloquée.
///
/// ⚠️ Se remet à `false` toute seule dès qu'une transaction passe : c'est un
/// état, pas une notification. Un indicateur de blocage qu'il faut acquitter à
/// la main finit acquitté une fois pour toutes, et le blocage redevient muet.
final ValueNotifier<bool> syncQueueBlocked = ValueNotifier<bool>(false);

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

/// Consigne un rejeu, et signale le blocage quand il ne se résoudra pas.
///
/// ── DEUX RYTHMES, ET C'EST VOULU ───────────────────────────────────────────
/// Un désaccord de SCHÉMA (colonne inconnue, table disparue) est signalé DÈS
/// LA PREMIÈRE FOIS : il ne se résoudra jamais tout seul, attendre cinq tours
/// ne ferait que retarder la seule information utile.
/// Les autres codes attendent [_kSeuilBlocage] échecs identiques d'affilée :
/// une sérialisation ou une saturation passagère n'a pas à alarmer une école.
///
/// ⚠️ La transaction n'est PAS complétée par cette fonction : rien n'est perdu,
/// le lot reste en file et repartira dès que le poste sera à jour.
Future<void> _noterRejeu(
  PowerSyncDatabase database,
  PostgrestException e,
  CrudTransaction transaction,
) async {
  final code = e.code ?? '?';
  final schema = estDesaccordDeSchema(code);

  if (code == _dernierCodeRejoue) {
    _echecsConsecutifs++;
  } else {
    _dernierCodeRejoue = code;
    _echecsConsecutifs = 1;
  }

  if (!schema && _echecsConsecutifs < _kSeuilBlocage) return;

  syncQueueBlocked.value = true;
  _blocagePeutEtreEnBase = true;

  // Identifiant DÉTERMINISTE par code : le rejeu se répète toutes les quelques
  // secondes ; sans cela le journal se remplirait de milliers de lignes
  // identiques et deviendrait illisible — donc inutile.
  final ops =
      transaction.crud.map((o) => '${o.op.name} ${o.table}#${o.id}').toList();
  try {
    await database.execute(
      'INSERT OR REPLACE INTO sync_failures '
      '(id, at, code, message, ops, summary, kind, acknowledged) '
      "VALUES (?, ?, ?, ?, ?, ?, 'blocage', 0)",
      [
        'blocage:$code',
        DateTime.now().toUtc().toIso8601String(),
        code,
        e.message,
        jsonEncode(ops),
        _summarizeOps(transaction.crud.map((o) => o.table)),
      ],
    );
  } catch (logErr) {
    debugPrint('⚠️ PowerSync — journal de blocage non écrit : $logErr');
  }

  debugPrint(
    '⚠️ PowerSync — FILE BLOQUÉE (code $code, ${_echecsConsecutifs}e échec). '
    'Rien n\'est perdu, mais ce poste n\'envoie plus rien. ${e.message}',
  );
}

/// Efface l'état de blocage après une transaction réussie.
Future<void> _finBlocage(PowerSyncDatabase database) async {
  _echecsConsecutifs = 0;
  _dernierCodeRejoue = null;
  syncQueueBlocked.value = false;
  // Cas courant : rien à effacer, et on ne veut pas d'un DELETE à chaque
  // transaction réussie. Le premier passage après un lancement l'exécute
  // quand même — voir `_blocagePeutEtreEnBase`.
  if (!_blocagePeutEtreEnBase) return;
  try {
    await database.execute("DELETE FROM sync_failures WHERE kind = 'blocage'");
    _blocagePeutEtreEnBase = false;
  } catch (_) {/* le bandeau disparaîtra au prochain démarrage */}
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
      // Une transaction passée = la file n'est plus bloquée. On efface l'état
      // au lieu d'attendre un acquittement : le bandeau disparaît de lui-même
      // quand la synchro repart, ce qui est la seule preuve qui vaille.
      await _finBlocage(database);
    } on PostgrestException catch (e) {
      if (estRefusDefinitif(e.code)) {
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
            '(id, at, code, message, ops, summary, kind, acknowledged) '
            "VALUES (?, ?, ?, ?, ?, ?, 'abandon', 0)",
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
        _echecsConsecutifs = 0;
        _dernierCodeRejoue = null;
      } else {
        // Erreur non fatale → PowerSync retentera. C'est le bon comportement :
        // rien n'est perdu. Mais un rejeu qui ne réussira JAMAIS doit se voir.
        await _noterRejeu(database, e, transaction);
        rethrow;
      }
    }
  }
}
