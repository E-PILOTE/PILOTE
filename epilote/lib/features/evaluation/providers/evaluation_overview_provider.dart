import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VUE D'ENSEMBLE ÉVALUATION (école × trimestre) — couverture par CLASSE,
//  agrégée pour alimenter le panneau Cycle ▸ Niveau ▸ Classe et les KPI hero des
//  pages Bulletins et Conseil de classe. Léger : ne calcule PAS les moyennes
//  depuis les notes (c'est le rôle de `bulletinComputationProvider` quand une
//  classe est ouverte) — il lit seulement l'état persisté des `bulletins`
//  (générés / publiés / délibérés) + la moyenne déjà stockée. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

/// Couverture d'évaluation d'une classe pour un trimestre.
class ClassCoverage {
  const ClassCoverage({
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.students,
    required this.generated,
    required this.published,
    required this.deliberated,
    required this.classAverage,
    required this.evaluations,
    required this.evaluationsComplete,
  });
  final String classId, className;
  final String? cycleCode, levelCode;
  final int levelOrder;
  final int students; // élèves actifs
  final int generated; // bulletins générés
  final int published; // bulletins publiés
  final int deliberated; // bulletins avec décision/appréciation du conseil
  final double? classAverage; // moyenne de classe (depuis les bulletins générés)
  final int evaluations; // évaluations saisies (trimestre)
  final int evaluationsComplete; // évaluations dont toutes les notes sont saisies

  bool get fullyGenerated => students > 0 && generated >= students;
  bool get fullyPublished => students > 0 && published >= students;
  bool get hasEvaluations => evaluations > 0;
}

/// Agrégat école pour un trimestre.
class EvaluationOverview {
  const EvaluationOverview({required this.classes, required this.schoolAverage});
  final List<ClassCoverage> classes;
  final double? schoolAverage;

  int _sum(int Function(ClassCoverage) f) =>
      classes.fold(0, (a, c) => a + f(c));
  int get students => _sum((c) => c.students);
  int get generated => _sum((c) => c.generated);
  int get published => _sum((c) => c.published);
  int get deliberated => _sum((c) => c.deliberated);
  int get evaluations => _sum((c) => c.evaluations);
  int get classesTotal => classes.length;
  int get classesGenerated => classes.where((c) => c.generated > 0).length;
  int get classesPublished => classes.where((c) => c.fullyPublished).length;
  int get classesDeliberated => classes.where((c) => c.deliberated > 0).length;
  int get classesEvaluated => classes.where((c) => c.hasEvaluations).length;
}

/// Couverture de toutes les classes (du périmètre) pour un trimestre.
/// ⚠️ La clé porte le SLUG de l'écran qui demande — Notes, Bulletins et
/// Conseils partagent cet aperçu, et chacun a son propre périmètre.
///
/// Il lisait `classesProvider`, en croyant — son commentaire le disait — que
/// « le périmètre est déjà appliqué ». Il l'est, mais c'est celui du module
/// `classes`, pas celui de l'appelant. Un profil dont Notes serait restreint
/// aux classes de l'enseignant, et `classes` ouvert à l'école, aurait vu
/// TOUTES les classes — le verrou posé dans l'administration n'aurait rien
/// changé, sans le moindre signal.
final evaluationOverviewProvider = FutureProvider.autoDispose
    .family<EvaluationOverview, ({String slug, String? trimesterId})>(
        (ref, cle) async {
  final trimesterId = cle.trimesterId;
  ref.keepAlive();
  final classes = ref.watch(classesForModuleProvider(cle.slug)).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const EvaluationOverview(classes: [], schoolAverage: null);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');
  final trimClause = trimesterId != null ? 'AND b.trimester_id = ?' : '';
  final params = <Object?>[...ids];
  if (trimesterId != null) params.add(trimesterId);

  final rows = await db.getAll(
    'SELECT ce.class_id AS cid, b.status AS status, b.decision AS decision, '
    'b.teacher_comment AS tc, b.overall_average AS avg '
    'FROM bulletins b JOIN class_enrollments ce ON ce.id = b.enrollment_id '
    'WHERE ce.class_id IN ($ph) $trimClause',
    params,
  );

  // Évaluations par classe (trimestre) + complétude (toutes les notes saisies).
  final etrimClause = trimesterId != null ? 'AND e.trimester_id = ?' : '';
  final eparams = <Object?>[...ids];
  if (trimesterId != null) eparams.add(trimesterId);
  final erows = await db.getAll(
    'SELECT e.class_id AS cid, '
    '(SELECT COUNT(*) FROM grades g WHERE g.evaluation_id = e.id) AS graded, '
    '(SELECT COUNT(*) FROM class_enrollments ce WHERE ce.class_id = e.class_id '
    "  AND ce.status = 'active') AS studs "
    'FROM evaluations e WHERE e.class_id IN ($ph) $etrimClause',
    eparams,
  );
  final evalCnt = <String, int>{};
  final evalDone = <String, int>{};
  for (final r in erows) {
    final cid = r['cid'] as String;
    evalCnt[cid] = (evalCnt[cid] ?? 0) + 1;
    final g = (r['graded'] as int?) ?? 0;
    final s = (r['studs'] as int?) ?? 0;
    if (s > 0 && g >= s) evalDone[cid] = (evalDone[cid] ?? 0) + 1;
  }

  final gen = <String, int>{};
  final pub = <String, int>{};
  final delib = <String, int>{};
  final sum = <String, double>{};
  final cnt = <String, int>{};
  final allAvg = <double>[];
  for (final r in rows) {
    final cid = r['cid'] as String;
    gen[cid] = (gen[cid] ?? 0) + 1;
    if ((r['status'] as String?) == 'published') {
      pub[cid] = (pub[cid] ?? 0) + 1;
    }
    final dec = r['decision'] as String?;
    final tc = r['tc'] as String?;
    if ((dec != null && dec.isNotEmpty) || (tc != null && tc.trim().isNotEmpty)) {
      delib[cid] = (delib[cid] ?? 0) + 1;
    }
    final a = (r['avg'] as num?)?.toDouble();
    if (a != null) {
      sum[cid] = (sum[cid] ?? 0) + a;
      cnt[cid] = (cnt[cid] ?? 0) + 1;
      allAvg.add(a);
    }
  }

  final coverage = [
    for (final c in classes)
      ClassCoverage(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        students: c.studentCount ?? 0,
        generated: gen[c.id] ?? 0,
        published: pub[c.id] ?? 0,
        deliberated: delib[c.id] ?? 0,
        classAverage:
            (cnt[c.id] ?? 0) > 0 ? sum[c.id]! / cnt[c.id]! : null,
        evaluations: evalCnt[c.id] ?? 0,
        evaluationsComplete: evalDone[c.id] ?? 0,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  final school =
      allAvg.isEmpty ? null : allAvg.reduce((a, b) => a + b) / allAvg.length;
  return EvaluationOverview(classes: coverage, schoolAverage: school);
});
