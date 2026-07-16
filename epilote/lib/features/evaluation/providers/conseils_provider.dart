import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../services/powersync/powersync_service.dart';
import 'bulletins_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CONSEIL DE CLASSE — la délibération de fin de trimestre. Le conseil examine
//  les bulletins calculés (page Bulletins) et y inscrit, par élève, une
//  DISTINCTION (félicitations, encouragements, avertissement…) + une
//  APPRÉCIATION du conseil, puis une SYNTHÈSE générale de classe. Ces décisions
//  sont portées par la table `bulletins` (colonnes `decision`, `teacher_comment`,
//  `director_comment`) — aucune table dédiée, donc 100% offline-first et sans
//  déploiement de sync-rules. Le conseil VALIDE les bulletins (statut →
//  `validated`) ; la publication aux familles reste sur la page Bulletins.
// ════════════════════════════════════════════════════════════════════════════

/// Distinction décernée par le conseil. `code` est stocké dans `bulletins.decision`.
class CouncilAward {
  const CouncilAward(this.code, this.label, this.color, this.icon, this.positive);
  final String code, label;
  final Color color;
  final IconData icon;
  final bool positive; // valorisante (félicitations…) vs sanction (avertissement…)
}

const kNoAwardColor = Color(0xFF94A3B8);
const _blue = Color(0xFF0EA5E9);
const _purple = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);

/// Catalogue ordonné des distinctions (système congolais / secondaire).
List<CouncilAward> get councilAwards => [
  CouncilAward('felicitations', 'Félicitations', kGreen, Icons.workspace_premium_rounded, true),
  const CouncilAward('encouragements', 'Encouragements', _blue, Icons.thumb_up_rounded, true),
  const CouncilAward('tableau_honneur', 'Tableau d\'honneur', _purple, Icons.emoji_events_rounded, true),
  const CouncilAward('avertissement_travail', 'Avertissement (travail)', _amber, Icons.warning_amber_rounded, false),
  CouncilAward('avertissement_conduite', 'Avertissement (conduite)', kAccent, Icons.report_problem_rounded, false),
  CouncilAward('blame', 'Blâme', kRed, Icons.gavel_rounded, false),
];

CouncilAward? awardFor(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final a in councilAwards) {
    if (a.code == code) return a;
  }
  return null;
}

/// Distinction proposée automatiquement d'après la moyenne /20 (éditable).
String? suggestedAward(double? avg) {
  if (avg == null) return null;
  if (avg >= 16) return 'felicitations';
  if (avg >= 14) return 'encouragements';
  if (avg >= 12) return 'tableau_honneur';
  if (avg < 8) return 'avertissement_travail';
  return null;
}

/// Une ligne du conseil = un élève + sa moyenne + sa distinction/appréciation.
class CouncilEntry {
  const CouncilEntry({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.average,
    required this.rank,
    required this.totalStudents,
    required this.mention,
    required this.bulletinExists,
    required this.status,
    required this.award,
    required this.appreciation,
  });
  final String enrollmentId, studentId, studentName;
  final String? matricule;
  final double? average;
  final int rank, totalStudents;
  final String mention, status;
  final bool bulletinExists; // un bulletin a été généré pour cet élève
  final String? award; // distinction persistée (code)
  final String? appreciation; // appréciation du conseil persistée
}

/// État global de la session de délibération d'une classe × trimestre.
class CouncilSession {
  const CouncilSession({
    required this.entries,
    required this.classAverage,
    required this.evaluationCount,
    required this.generatedCount,
    required this.deliberatedCount,
    required this.directorComment,
    required this.overallStatus,
  });
  final List<CouncilEntry> entries;
  final double? classAverage;
  final int evaluationCount, generatedCount, deliberatedCount;
  final String? directorComment; // synthèse de classe (partagée)
  final String overallStatus; // statut consolidé : none/draft/submitted/validated/published

  bool get bulletinsReady => generatedCount > 0;
}

typedef CouncilArgs = ({String classId, String? trimesterId});

/// Construit la session du conseil : moyennes (réutilise le calcul des
/// bulletins) fusionnées avec les distinctions/appréciations déjà délibérées.
final councilSessionProvider = FutureProvider.autoDispose
    .family<CouncilSession, CouncilArgs>((ref, args) async {
  ref.keepAlive();
  final comp = await ref.watch(bulletinComputationProvider(
      (classId: args.classId, trimesterId: args.trimesterId)).future);

  final entries = [
    for (final s in comp.students)
      CouncilEntry(
        enrollmentId: s.enrollmentId,
        studentId: s.studentId,
        studentName: s.studentName,
        matricule: s.matricule,
        average: s.overallAverage,
        rank: s.rank,
        totalStudents: s.totalStudents,
        mention: s.mention,
        bulletinExists: s.persisted,
        status: s.status,
        award: s.decision,
        appreciation: s.councilAppreciation,
      ),
  ];

  final generated = entries.where((e) => e.bulletinExists).length;
  final deliberated = entries
      .where((e) => e.bulletinExists &&
          ((e.award != null && e.award!.isNotEmpty) ||
              (e.appreciation != null && e.appreciation!.trim().isNotEmpty)))
      .length;

  // Synthèse de classe : director_comment partagé (premier non vide).
  final director = comp.students
      .map((s) => s.directorComment)
      .firstWhere((c) => c != null && c.trim().isNotEmpty, orElse: () => null);

  // Statut consolidé = le moins avancé parmi les bulletins générés.
  const order = ['draft', 'submitted', 'validated', 'published'];
  String overall = 'none';
  if (generated > 0) {
    var minIdx = order.length - 1;
    for (final e in entries) {
      if (!e.bulletinExists) continue;
      final i = order.indexOf(e.status);
      if (i >= 0 && i < minIdx) minIdx = i;
    }
    overall = order[minIdx];
  }

  return CouncilSession(
    entries: entries,
    classAverage: comp.classAverage,
    evaluationCount: comp.evaluationCount,
    generatedCount: generated,
    deliberatedCount: deliberated,
    directorComment: director,
    overallStatus: overall,
  );
});

// ─── Écritures (offline-first, sur la table `bulletins`) ─────────────────────

/// Enregistre la distinction + l'appréciation du conseil d'un élève sur son
/// bulletin (qui doit avoir été généré). `award`/`appreciation` à null = effacé.
Future<void> saveCouncilDecision({
  required String enrollmentId,
  required String trimesterId,
  String? award,
  String? appreciation,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE bulletins SET decision = ?, teacher_comment = ?, updated_at = ? '
    'WHERE enrollment_id = ? AND trimester_id = ?',
    [
      (award == null || award.isEmpty) ? null : award,
      (appreciation == null || appreciation.trim().isEmpty)
          ? null
          : appreciation.trim(),
      now,
      enrollmentId,
      trimesterId,
    ],
  );
}

/// Pré-remplit les distinctions proposées (par moyenne) pour tous les bulletins
/// générés qui n'en ont pas encore. N'écrase jamais une distinction existante.
Future<int> autofillAwards({
  required String trimesterId,
  required List<CouncilEntry> entries,
}) async {
  var n = 0;
  final now = DateTime.now().toIso8601String();
  for (final e in entries) {
    if (!e.bulletinExists) continue;
    if (e.award != null && e.award!.isNotEmpty) continue;
    final s = suggestedAward(e.average);
    if (s == null) continue;
    await db.execute(
      'UPDATE bulletins SET decision = ?, updated_at = ? '
      'WHERE enrollment_id = ? AND trimester_id = ?',
      [s, now, e.enrollmentId, trimesterId],
    );
    n++;
  }
  return n;
}

/// Enregistre la synthèse générale du conseil sur tous les bulletins de la classe.
Future<void> saveCouncilSynthesis({
  required String classId,
  required String trimesterId,
  required String comment,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE bulletins SET director_comment = ?, updated_at = ? '
    'WHERE trimester_id = ? '
    'AND enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)',
    [comment.trim().isEmpty ? null : comment.trim(), now, trimesterId, classId],
  );
}
