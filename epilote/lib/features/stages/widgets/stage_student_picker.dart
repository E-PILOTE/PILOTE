import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/stages_provider.dart' show kExamsRequiringInternship;

// ════════════════════════════════════════════════════════════════════════════
//  CHOISIR LE STAGIAIRE.
//
//  Les élèves en classe de bac technique/professionnel remontent EN PREMIER, et
//  sont signalés : ce sont eux dont le dossier d'examen est irrecevable sans
//  attestation. L'agent qui ouvre ce formulaire cherche presque toujours l'un
//  d'eux — le faire défiler parmi 300 élèves serait le punir d'avoir raison.
//
//  Mais la liste n'est pas RESTREINTE à eux : un élève de 1re peut faire un
//  stage, et l'école a le droit de l'enregistrer. On trie, on n'interdit pas.
// ════════════════════════════════════════════════════════════════════════════

class StagiaireCandidate {
  const StagiaireCandidate({
    required this.studentId,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.academicYearId,
    required this.needsAttestation,
  });

  final String studentId;
  final String fullName;
  final String? classId;
  final String? className;
  final String? academicYearId;

  /// En classe de BAC_T/BAC_P : sans attestation, dossier irrecevable.
  final bool needsAttestation;
}

final stagiaireCandidatesProvider =
    FutureProvider.autoDispose<List<StagiaireCandidate>>((ref) async {
  // Même lentille que le reste de l'espace école : on ne propose comme
  // stagiaire que les élèves inscrits sur l'année AFFICHÉE. Les inscriptions
  // restent `active` d'une année sur l'autre — sans ce filtre, la liste
  // grossirait d'une promotion par rentrée.
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return const <StagiaireCandidate>[];

  final ph = List.filled(kExamsRequiringInternship.length, '?').join(',');
  final rows = await db.getAll(
    '''
    SELECT s.id, s.first_name, s.last_name,
           c.id AS class_id, c.name AS class_name,
           ce.academic_year_id,
           CASE WHEN e.code IN ($ph) AND c.exam_status = 'examen'
                THEN 1 ELSE 0 END AS needs
      FROM class_enrollments ce
      JOIN students s ON s.id = ce.student_id
      JOIN classes  c ON c.id = ce.class_id
      LEFT JOIN national_exams e
             ON e.id = COALESCE(c.exam_override_id, c.exam_id)
     WHERE ce.status = 'active' AND ce.academic_year_id = ?
     ORDER BY needs DESC, c.name, s.last_name, s.first_name
    ''',
    [...kExamsRequiringInternship, yearId],
  );

  return [
    for (final r in rows)
      StagiaireCandidate(
        studentId: r['id'] as String,
        fullName: '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
        classId: r['class_id'] as String?,
        className: r['class_name'] as String?,
        academicYearId: r['academic_year_id'] as String?,
        needsAttestation: (r['needs'] as int? ?? 0) == 1,
      ),
  ];
});

class StageStudentPicker extends ConsumerWidget {
  const StageStudentPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StagiaireCandidate? value;
  final ValueChanged<StagiaireCandidate?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stagiaireCandidatesProvider);

    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'Aucun élève inscrit — le stage se rattache à un élève.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: value?.studentId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Élève *',
            border: const OutlineInputBorder(),
            isDense: true,
            labelStyle: TextStyle(color: kTextMuted),
          ),
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          items: [
            for (final s in list)
              DropdownMenuItem(
                value: s.studentId,
                child: Row(children: [
                  if (s.needsAttestation) ...[
                    Icon(Icons.priority_high_rounded, size: 14, color: kRed),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      '${s.fullName}${s.className != null ? ' · ${s.className}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
          ],
          onChanged: (id) => onChanged(
            id == null ? null : list.firstWhere((s) => s.studentId == id),
          ),
        );
      },
    );
  }
}
