import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PARCOURS D'UN ÉLÈVE — examens et stages, toutes années confondues.
//
//  Un élève ne passe pas « un » examen : il passe le BEPC, puis le BET, puis le
//  bac. C'est un parcours sur plusieurs années, et jusqu'ici le module ne savait
//  regarder que la session en cours — comme si chaque année était la première.
//
//  ── CE QUE ÇA DÉBLOQUE, ET QUI N'EST PAS COSMÉTIQUE ────────────────────────
//  Pour s'inscrire au bac, il faut le BET (ou BEPC/BEMG/BEP) LÉGALISÉ. Si
//  l'élève l'a passé chez nous, nous le SAVONS déjà : l'app peut afficher « BET
//  obtenu — session 2023, admis » et signaler d'elle-même celui qui n'y a pas
//  droit, sans attendre le rejet de la DEC au comptoir.
//
//  La photocopie légalisée reste due — c'est un objet physique. Mais
//  l'éligibilité, elle, se vérifie sans personne. C'est le chaînage réclamé :
//  un résultat ne repart pas dans le vide, il conditionne l'inscription suivante.
//
//  ── OFFLINE ────────────────────────────────────────────────────────────────
//  Aucune requête réseau : `exam_candidates` et `internships` arrivent par le
//  bucket `by_school`, `exam_sessions`/`national_exams` par `global_catalog`.
//  L'historique est donc consultable sans réseau — comme le reste.
// ════════════════════════════════════════════════════════════════════════════

/// Un examen passé (ou en cours) par l'élève.
class ExamHistoryEntry {
  const ExamHistoryEntry({
    required this.candidateId,
    required this.examCode,
    required this.examShortName,
    required this.yearLabel,
    required this.className,
    required this.result,
    required this.average,
    required this.mention,
    required this.candidateNumber,
    required this.decidedAt,
    required this.resultSource,
    required this.isRepeater,
  });

  final String candidateId;
  final String examCode;
  final String examShortName;
  final String? yearLabel;
  final String? className;
  final String? result;
  final double? average;
  final String? mention;
  final String? candidateNumber;

  /// Proclamation par la DEC — NULL si l'école ne l'a pas renseignée.
  final DateTime? decidedAt;

  /// `saisie_manuelle` | `import_csv` | `api_dec` — d'où vient le résultat.
  final String? resultSource;
  final bool isRepeater;

  bool get isPending => result == null || result == 'en_attente';
  bool get isAdmitted => result == 'admis';
}

/// Un stage effectué par l'élève.
class InternshipHistoryEntry {
  const InternshipHistoryEntry({
    required this.internshipId,
    required this.title,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.grade,
    required this.attestationIssuedAt,
    required this.yearLabel,
  });

  final String internshipId;
  final String? title;
  final String? companyName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final double? grade;

  /// La pièce qui compte : sans attestation, pas de dossier de bac.
  final DateTime? attestationIssuedAt;
  final String? yearLabel;

  bool get hasAttestation => attestationIssuedAt != null;
}

class StudentHistory {
  const StudentHistory({required this.exams, required this.internships});

  final List<ExamHistoryEntry> exams;
  final List<InternshipHistoryEntry> internships;

  bool get isEmpty => exams.isEmpty && internships.isEmpty;

  /// Les diplômes réellement obtenus — la base de l'éligibilité à la suite.
  List<ExamHistoryEntry> get diplomas =>
      exams.where((e) => e.isAdmitted).toList();

  /// L'élève a-t-il obtenu l'un de ces diplômes ? (ex. pour le bac :
  /// BEPC, BEMG, BET ou BEP). Renvoie l'entrée trouvée, ou `null`.
  ExamHistoryEntry? diplomaAmong(Set<String> codes) {
    for (final e in diplomas) {
      if (codes.contains(e.examCode)) return e;
    }
    return null;
  }

  bool get hasAttestation => internships.any((i) => i.hasAttestation);
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String);

final studentHistoryProvider =
    FutureProvider.autoDispose.family<StudentHistory, String>(
  (ref, studentId) async {
    // Antéchronologique : la dernière année d'abord — c'est celle qu'on cherche.
    final examRows = await db.getAll(
      '''
      SELECT c.id, c.result, c.average, c.mention, c.candidate_number,
             c.decided_at, c.result_source, c.is_repeater,
             s.year_label,
             e.code AS exam_code, e.short_name AS exam_short_name,
             cl.name AS class_name
        FROM exam_candidates c
        JOIN exam_sessions  s  ON s.id = c.session_id
        JOIN national_exams e  ON e.id = s.exam_id
        LEFT JOIN classes   cl ON cl.id = c.class_id
       WHERE c.student_id = ?
       ORDER BY s.year_label DESC, e.code
      ''',
      [studentId],
    );

    final stageRows = await db.getAll(
      '''
      SELECT i.id, i.title, i.start_date, i.end_date, i.status,
             i.evaluation_grade, i.attestation_issued_at,
             co.name AS company_name,
             y.label AS year_label
        FROM internships i
        LEFT JOIN internship_companies co ON co.id = i.company_id
        LEFT JOIN academic_years       y  ON y.id  = i.academic_year_id
       WHERE i.student_id = ?
       ORDER BY i.start_date DESC
      ''',
      [studentId],
    );

    return StudentHistory(
      exams: [
        for (final r in examRows)
          ExamHistoryEntry(
            candidateId: r['id'] as String,
            examCode: (r['exam_code'] as String?) ?? '—',
            examShortName: (r['exam_short_name'] as String?) ?? '—',
            yearLabel: r['year_label'] as String?,
            className: r['class_name'] as String?,
            result: r['result'] as String?,
            average: (r['average'] as num?)?.toDouble(),
            mention: r['mention'] as String?,
            candidateNumber: r['candidate_number'] as String?,
            decidedAt: _date(r['decided_at']),
            resultSource: r['result_source'] as String?,
            isRepeater: (r['is_repeater'] as int? ?? 0) == 1,
          ),
      ],
      internships: [
        for (final r in stageRows)
          InternshipHistoryEntry(
            internshipId: r['id'] as String,
            title: r['title'] as String?,
            companyName: r['company_name'] as String?,
            startDate: _date(r['start_date']),
            endDate: _date(r['end_date']),
            status: r['status'] as String?,
            grade: (r['evaluation_grade'] as num?)?.toDouble(),
            attestationIssuedAt: _date(r['attestation_issued_at']),
            yearLabel: r['year_label'] as String?,
          ),
      ],
    );
  },
);
