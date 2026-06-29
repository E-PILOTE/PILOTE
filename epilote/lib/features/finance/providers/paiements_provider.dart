import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PAIEMENTS ÉLÈVES (table `student_payments`) — encaissements par élève (frais,
//  montant, méthode, statut). Recouvrement par classe + historique par élève.
//  100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kPaymentMethods = <(String, String)>[
  ('especes', 'Espèces'),
  ('mtn_money', 'MTN Money'),
  ('airtel_money', 'Airtel Money'),
  ('visa', 'Carte Visa'),
];

const kPaymentStatuses = <(String, String)>[
  ('confirmed', 'Confirmé'),
  ('pending', 'En attente'),
  ('cancelled', 'Annulé'),
  ('refunded', 'Remboursé'),
];

String paymentMethodLabel(String? m) => kPaymentMethods
    .firstWhere((e) => e.$1 == m, orElse: () => ('especes', 'Espèces'))
    .$2;
String paymentStatusLabel(String? s) => kPaymentStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('confirmed', 'Confirmé'))
    .$2;

class PaymentsOverview {
  const PaymentsOverview({
    required this.rows,
    required this.collected,
    required this.confirmedCount,
    required this.pendingCount,
    required this.payers,
    required this.students,
  });
  final List<VsCoverageRow> rows;
  final int collected, confirmedCount, pendingCount, payers, students;
  int get classesTotal => rows.length;
}

final paymentsOverviewProvider =
    FutureProvider.autoDispose<PaymentsOverview>((ref) async {
  ref.keepAlive();
  final classes = ref.watch(classesProvider).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const PaymentsOverview(
        rows: [], collected: 0, confirmedCount: 0, pendingCount: 0,
        payers: 0, students: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');

  final rows = await db.getAll(
    'SELECT ce.class_id AS cid, sp.student_id AS sid, sp.amount_xaf AS amt, '
    'sp.status AS st '
    'FROM student_payments sp '
    "JOIN class_enrollments ce ON ce.student_id = sp.student_id AND ce.status = 'active' "
    'WHERE ce.class_id IN ($ph)',
    ids,
  );
  final payersByClass = <String, Set<String>>{};
  final collectedByClass = <String, int>{};
  var collected = 0, confirmedCount = 0, pendingCount = 0;
  final allPayers = <String>{};
  for (final r in rows) {
    final st = r['st'] as String?;
    final cid = r['cid'] as String;
    final sid = r['sid'] as String;
    if (st == 'confirmed') {
      final amt = (r['amt'] as num?)?.round() ?? 0;
      collected += amt;
      collectedByClass[cid] = (collectedByClass[cid] ?? 0) + amt;
      confirmedCount++;
      (payersByClass[cid] ??= {}).add(sid);
      allPayers.add(sid);
    } else if (st == 'pending') {
      pendingCount++;
    }
  }

  final cov = [
    for (final c in classes)
      VsCoverageRow(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        total: c.studentCount ?? 0,
        ok: payersByClass[c.id]?.length ?? 0,
        note: collectedByClass[c.id] != null
            ? fmtCompact(collectedByClass[c.id]!)
            : null,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  return PaymentsOverview(
    rows: cov,
    collected: collected,
    confirmedCount: confirmedCount,
    pendingCount: pendingCount,
    payers: allPayers.length,
    students: cov.fold(0, (a, c) => a + c.total),
  );
});

/// Une ligne élève (agrégat de ses paiements).
class StudentPayRow {
  const StudentPayRow({
    required this.studentId,
    required this.enrollmentId,
    required this.studentName,
    required this.matricule,
    required this.paid,
    required this.count,
    required this.lastDate,
  });
  final String studentId, studentName;
  final String? enrollmentId, matricule, lastDate;
  final int paid, count;
  bool get hasPaid => paid > 0;
}

final classPaymentsProvider = StreamProvider.autoDispose
    .family<List<StudentPayRow>, String>((ref, classId) {
  return db.watch(
    '''
    SELECT s.id AS sid, ce.id AS enr, s.first_name, s.last_name, s.matricule,
      (SELECT COALESCE(SUM(amount_xaf),0) FROM student_payments p
        WHERE p.student_id = s.id AND p.status = 'confirmed') AS paid,
      (SELECT COUNT(*) FROM student_payments p WHERE p.student_id = s.id) AS cnt,
      (SELECT MAX(payment_date) FROM student_payments p
        WHERE p.student_id = s.id) AS last_d
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [classId],
  ).map((rows) => [
        for (final r in rows)
          StudentPayRow(
            studentId: r['sid'] as String,
            enrollmentId: r['enr'] as String?,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            paid: (r['paid'] as num?)?.round() ?? 0,
            count: (r['cnt'] as num?)?.round() ?? 0,
            lastDate: r['last_d'] as String?,
          ),
      ]);
});

class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    required this.feeName,
    required this.receipt,
  });
  final String id;
  final int amount;
  final String? date, method, status, feeName, receipt;
}

final studentPaymentsProvider = StreamProvider.autoDispose
    .family<List<PaymentRow>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT sp.*, f.name AS fee_name
    FROM student_payments sp
    LEFT JOIN fee_structures f ON f.id = sp.fee_structure_id
    WHERE sp.student_id = ?
    ORDER BY sp.payment_date DESC, sp.created_at DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          PaymentRow(
            id: r['id'] as String,
            amount: (r['amount_xaf'] as num?)?.round() ?? 0,
            date: r['payment_date'] as String?,
            method: r['payment_method'] as String?,
            status: r['status'] as String?,
            feeName: r['fee_name'] as String?,
            receipt: r['receipt_number'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> savePayment({
  String? id,
  required String groupId,
  required String schoolId,
  required String studentId,
  String? enrollmentId,
  String? feeStructureId,
  required int amount,
  required String date,
  required String method,
  required String status,
  String? notes,
  required String recordedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  final d = DateTime.tryParse(date) ?? DateTime.now();
  if (id != null) {
    await db.execute(
      'UPDATE student_payments SET fee_structure_id = ?, amount_xaf = ?, '
      'payment_date = ?, payment_method = ?, status = ?, notes = ?, '
      'period_month = ?, period_year = ?, updated_at = ? WHERE id = ?',
      [feeStructureId, amount, date, method, status, notes, d.month, d.year,
       now, id],
    );
  } else {
    final receipt = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await db.execute(
      '''
      INSERT INTO student_payments (
        id, group_id, school_id, student_id, enrollment_id, fee_structure_id,
        amount_xaf, payment_date, period_month, period_year, payment_method,
        receipt_number, recorded_by, status, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, studentId, enrollmentId, feeStructureId,
       amount, date, d.month, d.year, method, receipt, recordedBy, status,
       notes, now, now],
    );
  }
}

Future<void> deletePayment(String id) async {
  await db.execute('DELETE FROM student_payments WHERE id = ?', [id]);
}
