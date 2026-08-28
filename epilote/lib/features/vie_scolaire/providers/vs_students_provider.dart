import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Élèves actifs AVEC leur classe (via l'inscription de l'année active) — pour
//  les sélecteurs et les couvertures des modules vie scolaire. 100% offline.
//
//  ── ⚠️ CE PROVIDER PREND UN SLUG, ET CE N'EST PAS UN DÉTAIL ────────────────
//  C'est le sélecteur d'élève des formulaires Discipline, Infirmerie et
//  Bibliothèque. Tant qu'il interrogeait toute l'école, le `data_scope`
//  `own_classes` posé sur ces modules ne produisait AUCUN effet dans le
//  formulaire : un surveillant restreint à ses classes voyait le registre
//  complet — nom, matricule, classe de chaque enfant de l'établissement — et
//  pouvait ouvrir un incident disciplinaire ou un passage à l'infirmerie sur
//  n'importe lequel d'entre eux.
//
//  Le périmètre demandé est celui du module APPELANT (`slug`), jamais celui de
//  `classes` : un même agent peut être `own_classes` en discipline et
//  `own_school` en infirmerie. C'est la règle de `classesForModuleProvider`,
//  appliquée ici à la liste d'élèves.
// ════════════════════════════════════════════════════════════════════════════
class VsStudent {
  const VsStudent({
    required this.id,
    required this.name,
    required this.matricule,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
  });
  final String id, name;
  final String? matricule, classId, className, cycleCode, levelCode;
  final int levelOrder;

  String get classLabel => className ?? 'Sans classe';
}

final vsStudentsProvider =
    StreamProvider.autoDispose.family<List<VsStudent>, String>((ref, slug) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }

  // Fermé par défaut : tant que le profil d'accès n'est pas lu, `AND 0 = 1`.
  // Un sélecteur vide une demi-seconde vaut mieux qu'une école entière servie
  // à quelqu'un qui n'y a pas droit — l'avoir affichée, c'est l'avoir divulguée.
  final scope = classScopeClause(ref, slug, column: 'c.id');

  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           c.id AS cid, c.name AS class_name, c.cycle_code AS cycle_code,
           c.level_code AS level_code, c.level_order AS level_order
    FROM students s
    LEFT JOIN class_enrollments ce
      ON ce.student_id = s.id
     AND ce.status = 'active'
     AND ce.academic_year_id = ?
    LEFT JOIN classes c ON c.id = ce.class_id
    WHERE s.school_id = ? AND COALESCE(s.is_active, 1) <> 0
    ${scope?.clause ?? ''}
    ORDER BY c.level_order, c.name, s.last_name, s.first_name
    ''',
    parameters: [yearId, schoolId, ...?scope?.params],
  ).map((rows) => [
        for (final r in rows)
          VsStudent(
            id: r['sid'] as String,
            name: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            classId: r['cid'] as String?,
            className: r['class_name'] as String?,
            cycleCode: r['cycle_code'] as String?,
            levelCode: r['level_code'] as String?,
            levelOrder: (r['level_order'] as int?) ?? 999,
          ),
      ]);
});
