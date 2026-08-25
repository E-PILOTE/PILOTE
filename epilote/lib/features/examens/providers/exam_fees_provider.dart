import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
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

class ExamFeeData {
  const ExamFeeData({
    required this.summary,
    required this.paidByStudent,
    required this.feeStructureId,
    required this.amountPerCandidate,
    required this.baremePublie,
  });

  final ExamFeeSummary summary;

  /// Total confirmé encaissé par élève (XAF).
  final Map<String, int> paidByStudent;

  /// `null` tant que le ministère n'a pas publié le barème de cette session.
  /// Sans lui, aucun encaissement n'est rattachable.
  final String? feeStructureId;

  final int amountPerCandidate;

  /// Vrai si le ministère a publié le barème de la session. Faux quand le
  /// montant affiché n'est que celui porté par la session nationale — la
  /// question n'est plus « l'école a-t-elle son propre tarif » (elle n'en a
  /// plus le droit) mais « les frais sont-ils ouverts ».
  final bool baremePublie;

  int paidFor(String studentId) => paidByStudent[studentId] ?? 0;

  FeePaymentState stateFor(String studentId) =>
      feeStateFor(due: amountPerCandidate, paid: paidFor(studentId));
}

/// Le recouvrement de la session, dérivé de l'état réel.
final examFeesProvider =
    FutureProvider.autoDispose.family<ExamFeeData, String>((ref, sessionId) async {
  // Le barème d'examen est posé par le MINISTÈRE pour la session. L'école ne le
  // crée pas : `ensureExamFeeStructure` a été retirée le 5 août 2026, elle
  // fabriquait une surcouche établissement par-dessus le tarif national —
  // c'est-à-dire la surfacturation, livrée comme une fonctionnalité.
  //
  // À défaut de barème publié, on affiche quand même le montant porté par la
  // session : dire « 0 attendu » alors que la DEC a fixé des frais tromperait
  // l'école sur ce qu'elle doit lever.
  //
  // ⚠️ `is_active = 1` rate les lignes écrites par l'application (vue
  // PowerSync) — cf. [[powersync-is-active-egalite-stricte]].
  // ── Le tarif se retrouve par l'EXAMEN, pas seulement par la session ────────
  //
  // Avant la migration 0103, seul `exam_session_id` reliait les deux — et sur
  // 35 sessions, 6 années et 7 groupes, il n'a JAMAIS été renseigné une seule
  // fois. La cause était dans l'ordre du travail : un ministère fixe ses frais
  // par arrêté PUIS ouvre les inscriptions ; exiger la session revenait à
  // demander de tarifer un examen dont l'instance n'existe pas encore.
  //
  // Le ministère vise donc l'examen (`applies_to_exam_id`), stable d'une année
  // sur l'autre, et le poste résout ici la session de SON année scolaire.
  // `exam_session_id` reste prioritaire : il sert à déroger sur une session
  // précise (un rattrapage au tarif différent).
  //
  // ⚠️ DÉPENDANCE DE SYNCHRO. Le rapprochement passe par `academic_years.label`,
  // et les sync-rules ne descendent l'année du groupe que si elle est PUBLIÉE
  // (`published_at IS NOT NULL`). Une année laissée en brouillon prive donc le
  // poste de la ligne, la jointure ne rend rien, et le tarif d'examen reste
  // introuvable — sans erreur. Si un barème publié n'arrive pas sur les postes,
  // vérifier d'abord que l'année scolaire est publiée.
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  final schoolId = profile?.schoolId;
  if (groupId == null) {
    return ExamFeeData(
      summary: summarizeExamFees(
          amountPerCandidate: 0, candidates: 0, payments: const []),
      paidByStudent: const {},
      feeStructureId: null,
      amountPerCandidate: 0,
      baremePublie: false,
    );
  }
  final fee = await db.getOptional(
    '''
    SELECT f.id, f.amount_xaf
      FROM fee_structures f
      JOIN exam_sessions es ON es.id = ?
      LEFT JOIN academic_years ay ON ay.id = f.academic_year_id
     WHERE COALESCE(f.is_active, 1) <> 0
       AND f.group_id = ?
       AND (f.school_id IS NULL OR f.school_id = ?)
       AND (
             f.exam_session_id = es.id
          OR (f.applies_to_exam_id = es.exam_id AND ay.label = es.year_label)
       )
     ORDER BY (f.exam_session_id IS NULL),   -- viser LA session l'emporte
              (f.school_id IS NULL),          -- puis le tarif de l'école
              f.amount_xaf,                   -- puis le moins cher
              f.id                            -- puis l'id : deux postes doivent
     LIMIT 1                                  -- retenir la MÊME ligne
    ''',
    [sessionId, groupId, schoolId ?? ''],
  );
  final session = await db.getOptional(
    'SELECT fee_amount FROM exam_sessions WHERE id = ?',
    [sessionId],
  );

  final feeStructureId = fee?['id'] as String?;
  final baremeAmount = (fee?['amount_xaf'] as num?)?.round();
  final nationalAmount = (session?['fee_amount'] as num?)?.round() ?? 0;
  final amount = baremeAmount ?? nationalAmount;

  final countRow = await db.getOptional(
    'SELECT COUNT(*) AS n FROM exam_candidates WHERE session_id = ?',
    [sessionId],
  );
  final candidates = (countRow?['n'] as num?)?.toInt() ?? 0;

  // Un paiement annulé n'est pas un revenu, et un paiement remboursé ne l'est
  // plus — mais un remboursement PARTIEL a laissé sa différence en caisse.
  final paid = <String, int>{};
  if (feeStructureId != null) {
    // Net encaissé : un remboursement partiel laisse la ligne `confirmed` mais
    // n'a plus rapporté que la différence ; un remboursement total passe en
    // `refunded` et ne rapporte rien (cf. `montantNet`).
    final rows = await db.getAll(
      'SELECT student_id, '
      'SUM(MAX(amount_xaf - COALESCE(refunded_amount_xaf, 0), 0)) AS total '
      'FROM student_payments '
      "WHERE fee_structure_id = ? AND status IN ('confirmed', 'refunded') "
      'GROUP BY student_id',
      [feeStructureId],
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
    baremePublie: feeStructureId != null,
  );
});

// ─── Aucune création de barème ici ───────────────────────────────────────────
//
// `ensureExamFeeStructure` et `setExamFeeAmount` ont été retirées le 5 août
// 2026. Elles laissaient l'ÉTABLISSEMENT fixer des frais que la DEC fixe
// nationalement : la surfacturation, livrée comme une fonctionnalité, et le
// défaut le plus net de l'audit du module Finance.
//
// Le barème d'une session est désormais publié par le ministère depuis son
// écran « Frais & tarifs », en portée groupe (`school_id IS NULL`).

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
