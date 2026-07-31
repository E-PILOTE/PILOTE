import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'INSCRIPTION D'UN CANDIDAT — tout ce qu'on doit pouvoir relire.
//
//  Une candidature se lit aujourd'hui en trois endroits : la ligne de la liste,
//  le dossier, le résultat. Personne ne voit la candidature ENTIÈRE, alors que
//  c'est précisément ce qu'on présente au comptoir de la DEC et ce qu'on relit
//  quand un parent conteste.
//
//  Les champs d'identité viennent de `students` : ce sont eux qui figurent sur
//  la liste officielle, et une faute (nom, date de naissance) s'y répare AVANT
//  le dépôt — après, elle voyage jusqu'au diplôme.
// ════════════════════════════════════════════════════════════════════════════

class CandidateFile {
  const CandidateFile({
    required this.candidateId,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.gender,
    required this.nationality,
    required this.photoUrl,
    required this.className,
    required this.filiereLabel,
    required this.levelName,
    required this.candidateNumber,
    required this.isRepeater,
    required this.dossierStatus,
    required this.registeredAt,
    required this.submittedAt,
    required this.examName,
    required this.examShortName,
    required this.tutelle,
    required this.yearLabel,
    required this.writtenFrom,
    required this.result,
    required this.average,
    required this.mention,
    required this.decidedAt,
    required this.resultSource,
    required this.notes,
  });

  final String candidateId, studentId;
  final String firstName, lastName;
  final String? matricule, placeOfBirth, gender, nationality, photoUrl;
  final DateTime? dateOfBirth;
  final String? className, filiereLabel, levelName;
  final String? candidateNumber, dossierStatus;
  final bool isRepeater;
  final DateTime? registeredAt, submittedAt, decidedAt;
  final String? examName, examShortName, tutelle, yearLabel;
  final DateTime? writtenFrom;
  final String? result, mention, resultSource, notes;
  final double? average;

  String get fullName => '$firstName $lastName'.trim();

  /// L'âge à la date de référence de la session — la seule qui fasse foi pour
  /// une condition d'âge. `null` sans date de naissance : on ne devine pas.
  int? ageAt(DateTime? reference) {
    final dob = dateOfBirth;
    if (dob == null || reference == null) return null;
    var age = reference.year - dob.year;
    if (reference.month < dob.month ||
        (reference.month == dob.month && reference.day < dob.day)) {
      age--;
    }
    return age;
  }
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String);

final candidateFileProvider =
    FutureProvider.autoDispose.family<CandidateFile?, String>(
  (ref, candidateId) async {
    final rows = await db.getAll(
      '''
      SELECT c.id, c.student_id, c.candidate_number, c.is_repeater,
             c.dossier_status, c.registered_at, c.submitted_at,
             c.result, c.average, c.mention, c.decided_at, c.result_source,
             c.notes,
             st.first_name, st.last_name, st.matricule, st.date_of_birth,
             st.place_of_birth, st.gender, st.nationality, st.photo_url,
             cl.name AS class_name, cl.filiere_label,
             cl.level_code AS level_name,
             s.year_label, s.written_from,
             e.name AS exam_name, e.short_name AS exam_short_name, e.tutelle
        FROM exam_candidates c
        JOIN students       st  ON st.id  = c.student_id
        JOIN exam_sessions  s   ON s.id   = c.session_id
        JOIN national_exams e   ON e.id   = s.exam_id
        LEFT JOIN classes   cl  ON cl.id  = c.class_id
       WHERE c.id = ?
      ''',
      [candidateId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;

    return CandidateFile(
      candidateId: r['id'] as String,
      studentId: r['student_id'] as String,
      firstName: r['first_name'] as String? ?? '',
      lastName: r['last_name'] as String? ?? '',
      matricule: r['matricule'] as String?,
      dateOfBirth: _date(r['date_of_birth']),
      placeOfBirth: r['place_of_birth'] as String?,
      gender: r['gender'] as String?,
      nationality: r['nationality'] as String?,
      photoUrl: r['photo_url'] as String?,
      className: r['class_name'] as String?,
      filiereLabel: r['filiere_label'] as String?,
      levelName: r['level_name'] as String?,
      candidateNumber: r['candidate_number'] as String?,
      isRepeater: r['is_repeater'] == 1 || r['is_repeater'] == true,
      dossierStatus: r['dossier_status'] as String?,
      registeredAt: _date(r['registered_at']),
      submittedAt: _date(r['submitted_at']),
      examName: r['exam_name'] as String?,
      examShortName: r['exam_short_name'] as String?,
      tutelle: r['tutelle'] as String?,
      yearLabel: r['year_label'] as String?,
      writtenFrom: _date(r['written_from']),
      result: r['result'] as String?,
      average: (r['average'] as num?)?.toDouble(),
      mention: r['mention'] as String?,
      decidedAt: _date(r['decided_at']),
      resultSource: r['result_source'] as String?,
      notes: r['notes'] as String?,
    );
  },
);
