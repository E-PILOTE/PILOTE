import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../students/widgets/scope_drilldown_panel.dart' show ScopeUnit;

// ════════════════════════════════════════════════════════════════════════════
//  CANDIDATS — la donnée exportable/imprimable du module.
//
//  Deux besoins distincts, deux lectures :
//   • la LISTE (par session) -> le document déposé au centre d'examen ;
//   • la COUVERTURE (par Cycle ▸ Niveau ▸ Classe) -> le panneau de navigation
//     partagé du projet (ScopeDrilldownPanel), pour voir d'un coup d'œil quelle
//     branche de la structure n'est pas inscrite.
//
//  Un examen traverse la structure académique : le regroupement par diplôme ne
//  suffit pas, il faut pouvoir descendre cycle -> niveau -> classe.
// ════════════════════════════════════════════════════════════════════════════

class ExamCandidateRow {
  const ExamCandidateRow({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.matricule,
    required this.dateOfBirth,
    required this.gender,
    required this.className,
    required this.filiereLabel,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.classId,
    required this.candidateNumber,
    required this.dossierStatus,
    required this.missingCount,
    required this.submittedAt,
    required this.result,
    required this.average,
    required this.mention,
  });

  final String id;
  final String studentId;
  final String fullName;
  final String? matricule;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? className;
  final String? filiereLabel;
  final String? cycleCode;
  final String? levelCode;
  final int levelOrder;
  final String? classId;
  final String? candidateNumber;
  final String? dossierStatus;
  final int missingCount;
  final DateTime? submittedAt;
  final String? result;
  final double? average;
  final String? mention;

  bool get isSubmitted =>
      submittedAt != null || dossierStatus == 'depose' || dossierStatus == 'valide';

  bool get isComplete => dossierStatus != 'incomplet';

  bool get hasResult => result != null && result != 'en_attente';
}

class ExamSessionCandidates {
  const ExamSessionCandidates({
    required this.sessionId,
    required this.examCode,
    required this.examShortName,
    required this.examName,
    required this.yearLabel,
    required this.tutelle,
    required this.writtenFrom,
    required this.candidates,
  });

  final String sessionId;
  final String examCode;
  final String examShortName;
  final String examName;
  final String? yearLabel;
  final String? tutelle;
  final DateTime? writtenFrom;
  final List<ExamCandidateRow> candidates;

  int get complete => candidates.where((c) => c.isComplete).length;
  int get submitted => candidates.where((c) => c.isSubmitted).length;
  int get withResult => candidates.where((c) => c.hasResult).length;
  int get admitted => candidates.where((c) => c.result == 'admis').length;

  /// Taux de réussite sur les seuls résultats CONNUS. Diviser par l'effectif
  /// total afficherait 0 % tant que rien n'est saisi — un chiffre faux.
  double? get successRate =>
      withResult == 0 ? null : admitted / withResult * 100;

  /// Unités pour le panneau Cycle ▸ Niveau ▸ Classe : « ok » = dossier complet.
  List<ScopeUnit> get scopeUnits => [
        for (final c in candidates)
          ScopeUnit(
            cycleCode: c.cycleCode,
            levelCode: c.levelCode,
            levelOrder: c.levelOrder,
            classId: c.classId,
            className: c.className,
            ok: c.isComplete,
          ),
      ];
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// Candidats d'une session, enrichis de leur position dans la structure.
final sessionCandidatesProvider = FutureProvider.autoDispose
    .family<ExamSessionCandidates?, String>((ref, sessionId) async {
  ref.keepAlive();

  final head = await db.getAll(
    'SELECT s.id, s.year_label, s.written_from, '
    '       e.code, e.short_name, e.name, e.tutelle '
    '  FROM exam_sessions s JOIN national_exams e ON e.id = s.exam_id '
    ' WHERE s.id = ? LIMIT 1',
    [sessionId],
  );
  if (head.isEmpty) return null;
  final h = head.first;

  final rows = await db.getAll(
    'SELECT ec.id, ec.student_id, ec.candidate_number, ec.dossier_status, '
    '       ec.missing_documents, ec.submitted_at, ec.result, ec.average, ec.mention, '
    '       st.first_name, st.last_name, st.matricule, st.date_of_birth, st.gender, '
    '       c.id AS class_id, c.name AS class_name, c.filiere_label, '
    '       c.cycle_code, c.level_code, c.level_order '
    '  FROM exam_candidates ec '
    '  JOIN students st ON st.id = ec.student_id '
    '  LEFT JOIN classes c ON c.id = ec.class_id '
    ' WHERE ec.session_id = ? '
    ' ORDER BY c.level_order, c.name, st.last_name, st.first_name',
    [sessionId],
  );

  return ExamSessionCandidates(
    sessionId: sessionId,
    examCode: h['code'] as String? ?? '',
    examShortName: h['short_name'] as String? ?? '',
    examName: h['name'] as String? ?? '',
    yearLabel: h['year_label'] as String?,
    tutelle: h['tutelle'] as String?,
    writtenFrom: _date(h['written_from']),
    candidates: [
      for (final r in rows)
        ExamCandidateRow(
          id: r['id'] as String,
          studentId: r['student_id'] as String,
          fullName: '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
          matricule: r['matricule'] as String?,
          dateOfBirth: _date(r['date_of_birth']),
          gender: r['gender'] as String?,
          className: r['class_name'] as String?,
          filiereLabel: r['filiere_label'] as String?,
          cycleCode: r['cycle_code'] as String?,
          levelCode: r['level_code'] as String?,
          levelOrder: (r['level_order'] as int?) ?? 999,
          classId: r['class_id'] as String?,
          candidateNumber: r['candidate_number'] as String?,
          dossierStatus: r['dossier_status'] as String?,
          missingCount: _countMissing(r['missing_documents']),
          submittedAt: _date(r['submitted_at']),
          result: r['result'] as String?,
          average: (r['average'] as num?)?.toDouble(),
          mention: r['mention'] as String?,
        ),
    ],
  );
});

int _countMissing(Object? jsonb) {
  if (jsonb is! String || jsonb.isEmpty) return 0;
  // Comptage tolérant : un jsonb illisible ne doit pas faire planter la page.
  final matches = RegExp(r'"code"').allMatches(jsonb).length;
  return matches;
}
