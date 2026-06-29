import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  CONGÉS & ABSENCES DU PERSONNEL (table `leave_requests`, staff_id ->
//  profiles.id). Workflow : pending → approved / rejected (enum leave_status).
//  100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kLeaveTypes = <(String, String)>[
  ('annuel', 'Congé annuel'),
  ('maladie', 'Congé maladie'),
  ('maternite', 'Congé maternité'),
  ('exceptionnel', 'Congé exceptionnel'),
  ('formation', 'Formation'),
  ('mission', 'Mission'),
  ('sans_solde', 'Sans solde'),
];

String leaveTypeLabel(String? t) =>
    kLeaveTypes.firstWhere((e) => e.$1 == t, orElse: () => ('', '—')).$2;

const kLeaveStatuses = <(String, String)>[
  ('pending', 'En attente'),
  ('approved', 'Approuvé'),
  ('rejected', 'Refusé'),
  ('cancelled', 'Annulé'),
];

String leaveStatusLabel(String? s) =>
    kLeaveStatuses.firstWhere((e) => e.$1 == s, orElse: () => ('', '—')).$2;

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.status,
    this.reason,
    this.rejectionReason,
  });
  final String id, staffId, staffName, leaveType, status;
  final String? startDate, endDate, reason, rejectionReason;
  final int daysCount;

  bool get isPending => status == 'pending';
}

final leaveRequestsProvider =
    StreamProvider.autoDispose<List<LeaveRequest>>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT lr.*, p.first_name, p.last_name
    FROM leave_requests lr
    LEFT JOIN profiles p ON p.id = lr.staff_id
    WHERE lr.school_id = ?
    ORDER BY (lr.status = 'pending') DESC, lr.start_date DESC
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          LeaveRequest(
            id: r['id'] as String,
            staffId: (r['staff_id'] as String?) ?? '',
            staffName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            leaveType: (r['leave_type'] as String?) ?? 'annuel',
            startDate: r['start_date'] as String?,
            endDate: r['end_date'] as String?,
            daysCount: (r['days_count'] as num?)?.round() ?? 0,
            status: (r['status'] as String?) ?? 'pending',
            reason: r['reason'] as String?,
            rejectionReason: r['rejection_reason'] as String?,
          ),
      ]);
});

int leaveDays(DateTime start, DateTime end) =>
    end.difference(start).inDays + 1;

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> saveLeaveRequest({
  String? id,
  required String groupId,
  required String schoolId,
  required String staffId,
  required String leaveType,
  required String startDate,
  required String endDate,
  required int daysCount,
  String? reason,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE leave_requests SET staff_id = ?, leave_type = ?, start_date = ?, '
      'end_date = ?, days_count = ?, reason = ?, updated_at = ? WHERE id = ?',
      [staffId, leaveType, startDate, endDate, daysCount, reason, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO leave_requests (
        id, group_id, school_id, staff_id, leave_type, start_date, end_date,
        days_count, reason, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, staffId, leaveType, startDate, endDate,
       daysCount, reason, now, now],
    );
  }
}

/// Décision direction : approuver / refuser (motif si refus).
Future<void> reviewLeaveRequest({
  required String id,
  required String status, // approved | rejected
  required String reviewedBy,
  String? rejectionReason,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE leave_requests SET status = ?, reviewed_by = ?, reviewed_at = ?, '
    'rejection_reason = ?, updated_at = ? WHERE id = ?',
    [status, reviewedBy, now, rejectionReason, now, id],
  );
}

Future<void> deleteLeaveRequest(String id) async {
  await db.execute('DELETE FROM leave_requests WHERE id = ?', [id]);
}

/// Action groupée : approuver toutes les demandes en attente fournies.
Future<void> approveLeaveBulk(List<String> ids, String reviewedBy) async {
  if (ids.isEmpty) return;
  final now = DateTime.now().toIso8601String();
  final ph = List.filled(ids.length, '?').join(',');
  await db.execute(
    "UPDATE leave_requests SET status = 'approved', reviewed_by = ?, "
    "reviewed_at = ?, updated_at = ? WHERE id IN ($ph) AND status = 'pending'",
    [reviewedBy, now, now, ...ids],
  );
}
