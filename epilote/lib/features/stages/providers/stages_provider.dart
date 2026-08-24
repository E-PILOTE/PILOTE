import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — espace école, 100 % offline.
//
//  La valeur du module n'est pas la liste des stages : c'est l'ALERTE. La note
//  METP exige une attestation de stage au dossier des baccalauréats techniques
//  et professionnels. Un élève de Terminale technique sans attestation a un
//  dossier IRRECEVABLE — et personne ne le voit avant la clôture. Ce provider
//  croise donc stages × classes d'examen pour le dire à l'avance.
// ════════════════════════════════════════════════════════════════════════════

/// Examens dont le dossier exige une attestation de stage (note METP 2025-2026 :
/// « les baccalauréats demandent […] une attestation de stage »).
///
/// `BAC` est le code courant depuis la mig. 0105 (un seul baccalauréat au
/// METP) ; `BAC_T`/`BAC_P` restent acceptés pour les bases pas encore migrées.
const kExamsRequiringInternship = {'BAC', 'BAC_T', 'BAC_P'};

enum InternshipStatus {
  prevu,
  enCours,
  termine,
  interrompu,
  valide;

  static InternshipStatus parse(String? v) => switch (v) {
        'en_cours' => InternshipStatus.enCours,
        'termine' => InternshipStatus.termine,
        'interrompu' => InternshipStatus.interrompu,
        'valide' => InternshipStatus.valide,
        _ => InternshipStatus.prevu,
      };

  String get label => switch (this) {
        InternshipStatus.prevu => 'Prévu',
        InternshipStatus.enCours => 'En cours',
        InternshipStatus.termine => 'Terminé',
        InternshipStatus.interrompu => 'Interrompu',
        InternshipStatus.valide => 'Validé',
      };
}

class InternshipRow {
  const InternshipRow({
    required this.id,
    required this.studentName,
    required this.className,
    required this.classId,
    required this.filiereLabel,
    required this.levelOrder,
    required this.companyName,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.hasAttestation,
    required this.conventionSigned,
  });

  final String id;
  final String studentName;
  final String? className;
  final String? classId;
  final String? filiereLabel;
  final int levelOrder;
  final String? companyName;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final InternshipStatus status;
  final bool hasAttestation;
  final bool conventionSigned;

  /// Stage achevé mais attestation jamais délivrée : le travail est fait, la
  /// pièce manque. C'est le cas le plus rageant, donc le plus utile à montrer.
  bool get attestationOverdue =>
      !hasAttestation &&
      (status == InternshipStatus.termine || status == InternshipStatus.valide);
}

/// Élève en classe de bac technique/pro dont le dossier d'examen est bloqué
/// faute d'attestation de stage.
class BlockedCandidate {
  const BlockedCandidate({
    required this.studentName,
    required this.className,
    required this.examShortName,
    required this.hasInternship,
  });

  final String studentName;
  final String? className;
  final String examShortName;

  /// Un stage existe mais sans attestation (≠ aucun stage du tout).
  final bool hasInternship;
}

class StagesOverview {
  const StagesOverview({required this.internships, required this.blocked});

  final List<InternshipRow> internships;
  final List<BlockedCandidate> blocked;

  int get ongoing =>
      internships.where((i) => i.status == InternshipStatus.enCours).length;

  int get attestations => internships.where((i) => i.hasAttestation).length;

  int get overdue => internships.where((i) => i.attestationOverdue).length;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

final stagesOverviewProvider =
    FutureProvider.autoDispose<StagesOverview>((ref) async {
  ref.keepAlive();

  // Le module vit dans l'année AFFICHÉE, comme le reste de l'espace école.
  // Sans ce filtre, les inscriptions ne changeant pas de statut au passage
  // d'année (elles restent `active` indéfiniment), la promotion 2025-2026
  // serait venue s'empiler sur celle de 2026-2027 : liste de stagiaires
  // mélangée et, plus grave, des élèves partis depuis un an comptés comme
  // « bloqués pour le bac ».
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) {
    return const StagesOverview(internships: [], blocked: []);
  }

  final rows = await db.getAll(
    'SELECT i.id, i.title, i.start_date, i.end_date, i.status, '
    '       i.attestation_issued_at, i.convention_signed_at, '
    '       s.first_name, s.last_name, c.name AS class_name, '
    '       c.id AS class_id, c.filiere_label, c.level_order, '
    '       co.name AS company_name '
    '  FROM internships i '
    '  LEFT JOIN students s ON s.id = i.student_id '
    '  LEFT JOIN classes c ON c.id = i.class_id '
    '  LEFT JOIN internship_companies co ON co.id = i.company_id '
    ' WHERE i.academic_year_id = ? '
    ' ORDER BY i.start_date DESC',
    [yearId],
  );

  // Le croisement qui fait le module : élèves en classe de bac technique/pro
  // SANS attestation de stage délivrée.
  //
  // L'inscription est scopée à l'année (qui est en classe d'examen CETTE
  // année) ; le `NOT EXISTS` sur l'attestation ne l'est délibérément PAS : une
  // attestation délivrée l'an dernier reste acquise, la redemander serait une
  // erreur administrative.
  final ph = List.filled(kExamsRequiringInternship.length, '?').join(',');
  final blockedRows = await db.getAll(
    'SELECT s.first_name, s.last_name, c.name AS class_name, e.short_name, '
    '       (SELECT COUNT(*) FROM internships i WHERE i.student_id = s.id) AS n_stages '
    '  FROM class_enrollments ce '
    '  JOIN students s ON s.id = ce.student_id '
    '  JOIN classes c ON c.id = ce.class_id '
    '  JOIN national_exams e ON e.id = COALESCE(c.exam_override_id, c.exam_id) '
    ' WHERE ce.status = ? AND ce.academic_year_id = ? '
    '   AND c.exam_status = ? AND e.code IN ($ph) '
    '   AND NOT EXISTS ( '
    '     SELECT 1 FROM internships i '
    '      WHERE i.student_id = s.id AND i.attestation_issued_at IS NOT NULL '
    '        AND i.status IN (?, ?) ) '
    ' ORDER BY c.name, s.last_name',
    ['active', yearId, 'examen', ...kExamsRequiringInternship, 'termine',
     'valide'],
  );

  return StagesOverview(
    internships: [
      for (final r in rows)
        InternshipRow(
          id: r['id'] as String,
          studentName:
              '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
          className: r['class_name'] as String?,
          classId: r['class_id'] as String?,
          filiereLabel: r['filiere_label'] as String?,
          levelOrder: (r['level_order'] as int?) ?? 999,
          companyName: r['company_name'] as String?,
          title: r['title'] as String?,
          startDate: _date(r['start_date']),
          endDate: _date(r['end_date']),
          status: InternshipStatus.parse(r['status'] as String?),
          hasAttestation: r['attestation_issued_at'] != null,
          conventionSigned: r['convention_signed_at'] != null,
        ),
    ],
    blocked: [
      for (final r in blockedRows)
        BlockedCandidate(
          studentName:
              '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
          className: r['class_name'] as String?,
          examShortName: r['short_name'] as String? ?? '',
          hasInternship: ((r['n_stages'] as int?) ?? 0) > 0,
        ),
    ],
  );
});
