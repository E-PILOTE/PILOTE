import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  TRANSFERTS (table `student_transfers`) — registre formel des départs d'élèves
//  vers un autre établissement. Cycle de vie : pending → approved/rejected →
//  completed. 100% offline (db.watch/db.execute). À l'APPROBATION, l'inscription
//  de l'élève bascule en `transferred` (réconciliation avec la fiche élève).
// ════════════════════════════════════════════════════════════════════════════

class TransferRow {
  const TransferRow({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.gender,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.enrollmentId,
    required this.toSchoolName,
    required this.transferDate,
    required this.reason,
    required this.status,
    required this.approvedAt,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String firstName, lastName, matricule;
  final String? gender;
  final String? className, cycleCode, levelCode;
  final int levelOrder;
  final String? enrollmentId;
  final String? toSchoolName;
  final DateTime? transferDate;
  final String? reason;
  final String status; // pending | approved | rejected | completed
  final DateTime? approvedAt;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  String get statusLabel => switch (status) {
        'pending' => 'En attente',
        'approved' => 'Approuvé',
        'rejected' => 'Rejeté',
        'completed' => 'Terminé',
        _ => status,
      };
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Transferts de l'école (année active ou pérennes). Réactif, local.
final transfersProvider = StreamProvider.autoDispose<List<TransferRow>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);

  return db
      .watch(
        '''
        SELECT t.*,
               s.first_name  AS first_name,
               s.last_name   AS last_name,
               s.matricule   AS matricule,
               s.gender      AS gender,
               ce.id         AS enrollment_id,
               c.name        AS class_name,
               c.cycle_code  AS cycle_code,
               c.level_code  AS level_code,
               c.level_order AS level_order
        FROM   student_transfers t
        JOIN   students s ON s.id = t.student_id
        LEFT JOIN class_enrollments ce
               ON ce.student_id = t.student_id
              AND ce.academic_year_id = ?
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  t.from_school_id = ?
          AND  (t.academic_year_id = ? OR t.academic_year_id IS NULL)
        ORDER  BY t.transfer_date DESC, t.created_at DESC
        ''',
        parameters: [yearId ?? '', schoolId, yearId],
      )
      .map((rows) => [
            for (final r in rows)
              TransferRow(
                id: r['id'] as String,
                studentId: r['student_id'] as String,
                firstName: (r['first_name'] as String?) ?? '',
                lastName: (r['last_name'] as String?) ?? '',
                matricule: (r['matricule'] as String?) ?? '',
                gender: r['gender'] as String?,
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                enrollmentId: r['enrollment_id'] as String?,
                toSchoolName: r['to_school_name'] as String?,
                transferDate: _d(r['transfer_date']),
                reason: r['reason'] as String?,
                status: (r['status'] as String?) ?? 'pending',
                approvedAt: _d(r['approved_at']),
                createdAt: _d(r['created_at']),
              ),
          ]);
});

// ─── Agrégations (KPI) ───────────────────────────────────────────────────────
class TransferStats {
  const TransferStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.completed,
  });
  final int total, pending, approved, rejected, completed;
}

final transferStatsProvider = Provider.autoDispose<TransferStats>((ref) {
  final rows = ref.watch(transfersProvider).valueOrNull ?? const [];
  var p = 0, a = 0, r = 0, c = 0;
  for (final t in rows) {
    switch (t.status) {
      case 'pending':
        p++;
      case 'approved':
        a++;
      case 'rejected':
        r++;
      case 'completed':
        c++;
    }
  }
  return TransferStats(
      total: rows.length, pending: p, approved: a, rejected: r, completed: c);
});

// ─── Candidats au transfert : élèves actifs sans transfert ouvert ────────────
class TransferCandidate {
  const TransferCandidate({
    required this.studentId,
    required this.fullName,
    required this.matricule,
    required this.className,
  });
  final String studentId, fullName, matricule;
  final String? className;
}

final transferCandidatesProvider =
    StreamProvider.autoDispose<List<TransferCandidate>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);

  return db
      .watch(
        '''
        SELECT s.id, s.first_name, s.last_name, s.matricule, c.name AS class_name
        FROM   students s
        JOIN   class_enrollments ce
               ON ce.student_id = s.id
              AND ce.academic_year_id = ?
              AND ce.status = 'active'
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  s.school_id = ? AND s.is_active = 1
          AND  NOT EXISTS (
                 SELECT 1 FROM student_transfers t
                 WHERE  t.student_id = s.id
                   AND  t.status IN ('pending','approved')
               )
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [yearId ?? '', schoolId],
      )
      .map((rows) => [
            for (final r in rows)
              TransferCandidate(
                studentId: r['id'] as String,
                fullName:
                    '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
                matricule: (r['matricule'] as String?) ?? '',
                className: r['class_name'] as String?,
              ),
          ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────

/// Crée un transfert. [initialStatus] = `pending` par défaut (saisie depuis la
/// page Transferts) ; la fiche élève l'appelle avec `completed` car l'élève est
/// déjà sorti de l'effectif au même moment (réconciliation).
Future<String> createTransfer({
  required String groupId,
  required String fromSchoolId,
  required String studentId,
  required String toSchoolName,
  required DateTime transferDate,
  String? reason,
  String? academicYearId,
  String initialStatus = 'pending',
  String? approvedBy,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  final approvedAt = initialStatus == 'pending' ? null : now;
  await db.execute(
    '''
    INSERT INTO student_transfers (
      id, group_id, student_id, from_school_id, to_school_name,
      transfer_date, reason, status, approved_by, approved_at,
      academic_year_id, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [id, groupId, studentId, fromSchoolId, toSchoolName.trim(),
     transferDate.toIso8601String().substring(0, 10), reason?.trim(),
     initialStatus, initialStatus == 'pending' ? null : approvedBy, approvedAt,
     academicYearId, now, now],
  );
  return id;
}

/// Approuve un transfert ET sort l'élève de l'effectif (`transferred`) →
/// réconciliation avec la fiche élève. [enrollmentId] peut être null (élève déjà
/// sorti) : on met alors juste à jour le transfert.
Future<void> approveTransfer({
  required String transferId,
  String? enrollmentId,
  String? approvedBy,
  String? reason,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE student_transfers
    SET    status = 'approved', approved_by = ?, approved_at = ?, updated_at = ?
    WHERE  id = ?
    ''',
    [approvedBy, now, now, transferId],
  );
  if (enrollmentId != null && enrollmentId.isNotEmpty) {
    await db.execute(
      '''
      UPDATE class_enrollments
      SET    status = 'transferred', withdrawal_date = ?,
             withdrawal_reason = ?, updated_at = ?
      WHERE  id = ?
      ''',
      [now.substring(0, 10),
       (reason?.trim().isNotEmpty ?? false) ? reason!.trim() : 'Transfert',
       now, enrollmentId],
    );
  }
}

Future<void> rejectTransfer({
  required String transferId,
  String? approvedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE student_transfers
    SET    status = 'rejected', approved_by = ?, approved_at = ?, updated_at = ?
    WHERE  id = ?
    ''',
    [approvedBy, now, now, transferId],
  );
}

Future<void> completeTransfer(String transferId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    "UPDATE student_transfers SET status = 'completed', updated_at = ? WHERE id = ?",
    [now, transferId],
  );
}

Future<void> deleteTransfer(String transferId) async {
  await db.execute('DELETE FROM student_transfers WHERE id = ?', [transferId]);
}

/// Export CSV (séparateur `;`, BOM UTF-8). Retourne le chemin.
Future<String> exportTransfersCsv(List<TransferRow> rows) async {
  String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
  String date(DateTime? d) =>
      d == null ? '' : d.toIso8601String().substring(0, 10);
  final b = StringBuffer();
  b.writeln(['Élève', 'Matricule', 'Classe', 'École destination', 'Date',
    'Motif', 'Statut']
      .map(cell)
      .join(';'));
  for (final r in rows) {
    b.writeln([
      r.lastFirst,
      r.matricule,
      r.className ?? '',
      r.toSchoolName ?? '',
      date(r.transferDate),
      (r.reason ?? '').replaceAll('\n', ' '),
      r.statusLabel,
    ].map(cell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/transferts_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
