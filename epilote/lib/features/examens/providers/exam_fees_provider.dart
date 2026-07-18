import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../models/exam_fee.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECOUVREMENT DES FRAIS D'UNE SESSION — pour UNE école.
//
//  Le barème vit dans `fee_structures` (type `frais_examens`, rattaché à la
//  session par la migration 0058) ; les encaissements dans `student_payments`.
//  Ces deux tables alimentent déjà le revenu de l'école puis du groupe : rien
//  à recâbler, les frais d'examen entrent dans la même chaîne que le reste.
//
//  ⚠️ `student_payments.enrollment_id` est NOT NULL en base. Écrire un paiement
//  sans inscription résolue ferait REJETER la ligne par le serveur, ce qui
//  abandonne le lot PowerSync ENTIER — silencieusement. D'où la résolution
//  explicite de l'inscription avant toute écriture, et le refus net si elle
//  manque : mieux vaut une erreur affichée qu'un travail perdu sans bruit.
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();

class ExamFeeData {
  const ExamFeeData({
    required this.summary,
    required this.paidByStudent,
    required this.feeStructureId,
    required this.amountPerCandidate,
    required this.isSchoolScale,
  });

  final ExamFeeSummary summary;

  /// Total confirmé encaissé par élève (XAF).
  final Map<String, int> paidByStudent;

  /// `null` tant que l'école n'a pas de barème pour cette session.
  final String? feeStructureId;

  final int amountPerCandidate;

  /// Vrai si le montant vient du barème de l'ÉCOLE ; faux s'il est repris du
  /// montant national de la session (aucun barème local encore créé).
  final bool isSchoolScale;

  int paidFor(String studentId) => paidByStudent[studentId] ?? 0;

  FeePaymentState stateFor(String studentId) =>
      feeStateFor(due: amountPerCandidate, paid: paidFor(studentId));
}

/// Le recouvrement de la session, dérivé de l'état réel.
final examFeesProvider =
    FutureProvider.autoDispose.family<ExamFeeData, String>((ref, sessionId) async {
  // Le montant de référence : celui du barème de l'école s'il existe, sinon
  // celui fixé nationalement pour la session. Afficher « 0 attendu » alors que
  // le ministère a fixé des frais tromperait l'école sur ce qu'elle doit lever.
  final fee = await db.getOptional(
    'SELECT id, amount_xaf FROM fee_structures '
    'WHERE exam_session_id = ? AND is_active = 1 LIMIT 1',
    [sessionId],
  );
  final session = await db.getOptional(
    'SELECT fee_amount FROM exam_sessions WHERE id = ?',
    [sessionId],
  );

  final feeStructureId = fee?['id'] as String?;
  final schoolAmount = (fee?['amount_xaf'] as num?)?.round();
  final nationalAmount = (session?['fee_amount'] as num?)?.round() ?? 0;
  final amount = schoolAmount ?? nationalAmount;

  final countRow = await db.getOptional(
    'SELECT COUNT(*) AS n FROM exam_candidates WHERE session_id = ?',
    [sessionId],
  );
  final candidates = (countRow?['n'] as num?)?.toInt() ?? 0;

  // Seuls les paiements CONFIRMÉS comptent : un paiement annulé ou remboursé
  // n'est pas un revenu.
  final paid = <String, int>{};
  if (feeStructureId != null) {
    final rows = await db.getAll(
      'SELECT student_id, SUM(amount_xaf) AS total FROM student_payments '
      'WHERE fee_structure_id = ? AND status = ? GROUP BY student_id',
      [feeStructureId, 'confirmed'],
    );
    for (final r in rows) {
      paid[r['student_id'] as String] = (r['total'] as num?)?.round() ?? 0;
    }
  }

  return ExamFeeData(
    summary: summarizeExamFees(
      amountPerCandidate: amount,
      candidates: candidates,
      payments: paid.values,
    ),
    paidByStudent: paid,
    feeStructureId: feeStructureId,
    amountPerCandidate: amount,
    isSchoolScale: schoolAmount != null,
  );
});

/// Crée le barème de l'école pour cette session s'il n'existe pas, et renvoie
/// son identifiant. Idempotent : l'index unique (school_id, exam_session_id)
/// garantit qu'il n'y en aura jamais deux — deux barèmes concurrents feraient
/// diverger l'attendu et le recouvrement.
Future<String> ensureExamFeeStructure({
  required String sessionId,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required int amountXaf,
  required String label,
}) async {
  final existing = await db.getOptional(
    'SELECT id FROM fee_structures WHERE exam_session_id = ? LIMIT 1',
    [sessionId],
  );
  if (existing != null) return existing['id'] as String;

  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO fee_structures
      (id, group_id, school_id, academic_year_id, name, fee_type, amount_xaf,
       exam_session_id, is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, groupId, schoolId, academicYearId, label, 'frais_examens', amountXaf,
      sessionId, now, now],
  );
  return id;
}

/// Met à jour le montant du barème (exonération globale, révision ministérielle).
Future<void> setExamFeeAmount(String feeStructureId, int amountXaf) => db.execute(
      'UPDATE fee_structures SET amount_xaf = ?, updated_at = ? WHERE id = ?',
      [amountXaf, DateTime.now().toIso8601String(), feeStructureId],
    );

/// L'inscription ACTIVE de l'élève pour l'année — obligatoire pour écrire un
/// paiement (`enrollment_id` est NOT NULL). `null` si l'élève n'en a aucune.
Future<String?> resolveEnrollmentId({
  required String studentId,
  required String academicYearId,
}) async {
  final r = await db.getOptional(
    'SELECT id FROM class_enrollments '
    'WHERE student_id = ? AND academic_year_id = ? '
    'ORDER BY CASE WHEN status = ? THEN 0 ELSE 1 END, enrollment_date DESC '
    'LIMIT 1',
    [studentId, academicYearId, 'active'],
  );
  return r?['id'] as String?;
}

/// Levée quand l'élève n'a pas d'inscription pour l'année : sans elle, le
/// serveur rejetterait le paiement et le lot PowerSync entier serait perdu.
class MissingEnrollmentException implements Exception {
  const MissingEnrollmentException(this.studentName);
  final String studentName;
  @override
  String toString() =>
      '$studentName n\'a pas d\'inscription pour l\'année en cours : '
      'le paiement ne peut pas être rattaché. Inscrivez l\'élève d\'abord.';
}
