import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'exam_candidates_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  TRANSMISSION À LA DEC — le geste ENGAGEANT du module (migration 0054).
//
//  ── CE QUE ÇA PROUVE ────────────────────────────────────────────────────────
//  Le dépôt engage l'établissement : c'est daté, opposable, et un candidat
//  oublié perd une année. Une transmission fige la liste TELLE QUE DÉPOSÉE — elle
//  sert à la fois de feuille de frappe (saisie manuelle DEC) et de bordereau
//  (dossiers papier). Les deux coïncident par construction.
//
//  ── POURQUOI UN SNAPSHOT FIGÉ ───────────────────────────────────────────────
//  Un export recalculé depuis les données VIVANTES ne correspondrait plus, en
//  juin, à ce qui a été déposé en février (un élève parti, un ajout tardif).
//  On ne recalcule jamais : le `snapshot` est la liste littérale, gelée.
//
//  ── ÉCRITURE OFFLINE, ZÉRO REJET ────────────────────────────────────────────
//  Écrit par le personnel scolaire via db.execute (offline-first). La référence
//  est un libellé HUMAIN sans contrainte d'unicité serveur (cf. 0054) : une
//  collision de séquence entre deux postes est cosmétique, jamais une perte.
// ════════════════════════════════════════════════════════════════════════════

class TransmissionRow {
  const TransmissionRow({
    required this.id,
    required this.reference,
    required this.kind,
    required this.status,
    required this.channel,
    required this.recipient,
    required this.itemCount,
    required this.transmittedAt,
    required this.acknowledgedAt,
    required this.correctsId,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String reference;
  final String kind;
  final String status;
  final String channel;
  final String? recipient;
  final int itemCount;
  final DateTime? transmittedAt;
  final DateTime? acknowledgedAt;
  final String? correctsId;
  final String? notes;
  final DateTime? createdAt;

  bool get isRectificatif => kind == 'rectificatif' || correctsId != null;
  bool get isAcknowledged => acknowledgedAt != null || status == 'accuse_reception';
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// Les transmissions d'une session, la plus récente d'abord.
final sessionTransmissionsProvider = StreamProvider.autoDispose
    .family<List<TransmissionRow>, String>((ref, sessionId) {
  ref.keepAlive();
  return db
      .watch(
        'SELECT id, reference, kind, status, channel, recipient, item_count, '
        '       transmitted_at, acknowledged_at, corrects_id, notes, created_at '
        '  FROM transmissions WHERE session_id = ? '
        ' ORDER BY created_at DESC',
        parameters: [sessionId],
      )
      .map((rows) => [
            for (final r in rows)
              TransmissionRow(
                id: r['id'] as String,
                reference: (r['reference'] as String?) ?? '',
                kind: (r['kind'] as String?) ?? 'liste_candidats',
                status: (r['status'] as String?) ?? 'transmis',
                channel: (r['channel'] as String?) ?? 'saisie_dec',
                recipient: r['recipient'] as String?,
                itemCount: (r['item_count'] as int?) ?? 0,
                transmittedAt: _date(r['transmitted_at']),
                acknowledgedAt: _date(r['acknowledged_at']),
                correctsId: r['corrects_id'] as String?,
                notes: r['notes'] as String?,
                createdAt: _date(r['created_at']),
              ),
          ]);
});

/// Numéro de lot d'un candidat dans une transmission. PURE et testable :
/// le lot (~50) est À L'INTÉRIEUR d'une classe (la filière est portée par la
/// classe). Chaque changement de classe ouvre un lot ; chaque tranche de 50
/// dans une même classe aussi. Retourne un lot 1-indexé par candidat, dans
/// l'ordre reçu (les candidats doivent déjà être triés par classe).
List<int> assignLotNumbers(List<String?> classIds, {int lotSize = 50}) {
  final lots = <int>[];
  var lot = 0;
  String? current;
  var inClass = 0;
  var started = false;
  for (final cid in classIds) {
    if (!started || cid != current) {
      current = cid;
      inClass = 0;
      lot++;
      started = true;
    } else if (inClass >= lotSize) {
      inClass = 0;
      lot++;
    }
    inClass++;
    lots.add(lot);
  }
  return lots;
}

/// Résultat d'une soumission : la référence générée, pour l'afficher.
class TransmissionResult {
  const TransmissionResult({required this.id, required this.reference, required this.count});
  final String id;
  final String reference;
  final int count;
}

/// Fige la liste de candidats fournie en une transmission opposable.
///
/// `candidates` est LE SOUS-ENSEMBLE affiché (on fige ce qu'on voit, comme
/// l'export). `kind`/`recipient`/`channel` ont des défauts sensés ; `correctsId`
/// non nul crée un RECTIFICATIF lié à une transmission antérieure.
Future<TransmissionResult?> createTransmission(
  WidgetRef ref, {
  required String sessionId,
  required String? tutelle,
  required String? yearLabel,
  required List<ExamCandidateRow> candidates,
  String kind = 'liste_candidats',
  String channel = 'saisie_dec',
  String? correctsId,
  String? notes,
}) async {
  if (candidates.isEmpty) return null;

  final profile = ref.read(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  final schoolId = profile?.schoolId;
  if (groupId == null || schoolId == null) return null;

  final author = ref.read(activeAgentIdProvider);

  // Référence lisible : EP-<code école>-<AAAA>-<seq>. Séquence LOCALE (compte
  // des transmissions de l'école pour l'année). Pas de garantie d'unicité
  // serveur — c'est voulu (cf. 0054), l'`id` UUID porte l'identité.
  final schoolRows = await db.getAll(
      'SELECT school_code FROM schools WHERE id = ? LIMIT 1', [schoolId]);
  final code = (schoolRows.isEmpty ? null : schoolRows.first['school_code'] as String?);
  final year = (yearLabel ?? '${DateTime.now().year}').split('-').first;
  final seqRows = await db.getAll(
      'SELECT COUNT(*) AS n FROM transmissions WHERE school_id = ? '
      'AND reference LIKE ?',
      [schoolId, 'EP-%-$year-%']);
  final seq = ((seqRows.first['n'] as int?) ?? 0) + 1;
  final reference =
      'EP-${code ?? 'ECOLE'}-$year-${seq.toString().padLeft(3, '0')}';

  final recipient = tutelle == 'mepsa' ? 'dec_mepsa' : 'dec_metp';
  final now = DateTime.now().toIso8601String();
  final transmissionId = _uuid.v4();

  // Snapshot littéral + items requêtables : les deux, pas l'un ou l'autre.
  final lots = assignLotNumbers([for (final c in candidates) c.classId]);
  final snapshot = <Map<String, dynamic>>[];
  final items = <Map<String, dynamic>>[];

  for (var i = 0; i < candidates.length; i++) {
    final c = candidates[i];
    final payload = {
      'candidate_id': c.id,
      'student_id': c.studentId,
      'full_name': c.fullName,
      'matricule': c.matricule,
      'date_of_birth': c.dateOfBirth?.toIso8601String(),
      'gender': c.gender,
      'class_name': c.className,
      'candidate_number': c.candidateNumber,
      'dossier_status': c.dossierStatus,
    };
    snapshot.add(payload);
    items.add({
      'id': _uuid.v4(),
      'candidate_id': c.id,
      'student_id': c.studentId,
      'lot_number': lots[i],
      'position': i + 1,
      'payload': jsonEncode(payload),
    });
  }

  await db.execute(
    'INSERT INTO transmissions ('
    ' id, group_id, school_id, kind, recipient, session_id, reference, status, '
    ' channel, snapshot, item_count, transmitted_at, transmitted_by, '
    ' corrects_id, notes, created_by, created_at, updated_at'
    ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      transmissionId, groupId, schoolId, kind, recipient, sessionId, reference,
      // « transmis » d'emblée : soumettre EST la transmission. La descente d'un
      // accusé (accuse_reception) viendra de la DEC, plus tard.
      'transmis', channel, jsonEncode(snapshot), items.length, now, author,
      correctsId, notes, author, now, now,
    ],
  );

  for (final it in items) {
    await db.execute(
      'INSERT INTO transmission_items ('
      ' id, transmission_id, group_id, school_id, candidate_id, student_id, '
      ' lot_number, position, payload, created_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        it['id'], transmissionId, groupId, schoolId, it['candidate_id'],
        it['student_id'], it['lot_number'], it['position'], it['payload'], now,
      ],
    );
  }

  return TransmissionResult(
      id: transmissionId, reference: reference, count: items.length);
}

/// Enregistre l'accusé de réception renvoyé par la DEC (saisi à la main tant que
/// l'API n'existe pas). Ne réécrit jamais le snapshot — on n'annote que l'état.
Future<void> acknowledgeTransmission(
  String transmissionId, {
  String? acknowledgmentRef,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE transmissions SET status = ?, acknowledged_at = ?, '
    ' acknowledgment_ref = ?, updated_at = ? WHERE id = ?',
    ['accuse_reception', now, acknowledgmentRef, now, transmissionId],
  );
}
