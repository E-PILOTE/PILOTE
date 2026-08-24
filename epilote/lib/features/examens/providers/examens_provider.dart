import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EXAMENS D'ÉTAT — espace école, 100 % offline (db.watch / db.getAll).
//
//  La classe d'examen est DÉRIVÉE PAR LE SERVEUR (trigger + resolve_class_exam,
//  migrations 0044/0045) : ce provider LIT `classes.exam_id` / `exam_status`,
//  il ne rejoue AUCUNE règle. C'est délibéré — dupliquer la résolution en Dart
//  garantirait une divergence le jour d'une réforme.
//
//  Les sync-rules filtrent déjà par école : la base locale ne contient que les
//  données de CETTE école, aucun filtre school_id supplémentaire n'est requis.
// ════════════════════════════════════════════════════════════════════════════

/// Statut d'une classe au regard des examens d'État (miroir de `class_exam_status`).
enum ClassExamStatus {
  /// Classe d'examen : un diplôme d'État est préparé.
  examen,

  /// Classe de passage : aucun examen attendu. C'est normal, rien à faire.
  passage,

  /// Niveau terminal SANS règle résolue -> anomalie à traiter (règle manquante
  /// au référentiel, ou filière non saisie sur la classe).
  aQualifier;

  static ClassExamStatus parse(String? v) => switch (v) {
        'examen' => ClassExamStatus.examen,
        'a_qualifier' => ClassExamStatus.aQualifier,
        _ => ClassExamStatus.passage,
      };
}

class ExamClassRow {
  const ExamClassRow({
    required this.id,
    required this.name,
    required this.levelCode,
    required this.cycleCode,
    required this.filiereLabel,
    required this.status,
    required this.examCode,
    required this.examShortName,
    required this.examName,
    required this.isOverridden,
    required this.effectif,
    required this.candidates,
  });

  final String id;
  final String name;
  final String levelCode;
  final String cycleCode;
  final String? filiereLabel;
  final ClassExamStatus status;
  final String? examCode;
  final String? examShortName;
  final String? examName;

  /// L'examen provient d'une surcharge explicite, pas de la règle nationale.
  final bool isOverridden;
  final int effectif;
  final int candidates;

  /// Élèves de la classe pas encore inscrits à la session.
  int get missing => (effectif - candidates).clamp(0, effectif);
}

class ExamSessionRow {
  const ExamSessionRow({
    required this.id,
    required this.examCode,
    required this.examShortName,
    required this.yearLabel,
    required this.opensAt,
    required this.closesAt,
    required this.writtenFrom,
    required this.maxAge,
    required this.status,
  });

  final String id;
  final String examCode;
  final String examShortName;
  final String yearLabel;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? writtenFrom;
  final int? maxAge;
  final String status;

  bool get isOpen => status == 'open';

  /// Jours restants avant la clôture des inscriptions (null si pas de date).
  int? get daysLeft {
    if (closesAt == null) return null;
    final now = DateTime.now();
    return closesAt!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class ExamOverview {
  const ExamOverview({
    required this.classes,
    required this.sessions,
  });

  final List<ExamClassRow> classes;
  final List<ExamSessionRow> sessions;

  List<ExamClassRow> get examClasses =>
      classes.where((c) => c.status == ClassExamStatus.examen).toList();

  List<ExamClassRow> get anomalies =>
      classes.where((c) => c.status == ClassExamStatus.aQualifier).toList();

  int get candidatesTotal =>
      examClasses.fold(0, (sum, c) => sum + c.candidates);

  int get studentsTotal => examClasses.fold(0, (sum, c) => sum + c.effectif);

  int get missingTotal => examClasses.fold(0, (sum, c) => sum + c.missing);

  /// Sessions concernant au moins une classe d'examen de l'école.
  List<ExamSessionRow> get relevantSessions {
    final codes = {for (final c in examClasses) c.examCode};
    return sessions.where((s) => codes.contains(s.examCode)).toList();
  }

  /// ── CE QUI SE JOUE MAINTENANT ────────────────────────────────────────────
  /// Le calendrier national est PARTAGÉ : l'école reçoit toutes les sessions
  /// de tous les examens qu'elle prépare, y compris celles des années
  /// précédentes (le référentiel remonte à 2021-2022). Les afficher toutes,
  /// à égalité, noyait la seule qui appelle une action — huit bandeaux morts
  /// avant celui de l'année en cours.
  ///
  /// Sont « vivantes » : la session de l'année scolaire courante, et toute
  /// session encore ouverte ou dont les épreuves se déroulent — une session
  /// d'une autre année qui reste ouverte concerne toujours l'école.
  List<ExamSessionRow> get liveSessions {
    final year = currentSchoolYearLabel();
    final live = relevantSessions
        .where((s) =>
            s.yearLabel == year || s.status == 'open' || s.status == 'running')
        .toList();
    live.sort(_byUrgency);
    return live;
  }

  /// L'histoire, pas l'actualité. Reste accessible, mais repliée.
  List<ExamSessionRow> get pastSessions {
    final liveIds = {for (final s in liveSessions) s.id};
    final past =
        relevantSessions.where((s) => !liveIds.contains(s.id)).toList();
    // La plus récente d'abord : on remonte le temps, on ne le descend pas.
    past.sort((a, b) => b.yearLabel.compareTo(a.yearLabel));
    return past;
  }

  /// L'échéance la plus proche en tête : c'est l'ordre de ce qu'il faut
  /// traiter. Une session sans date de clôture ne peut pas être urgente, elle
  /// passe donc après celles qui en ont une.
  static int _byUrgency(ExamSessionRow a, ExamSessionRow b) {
    int rank(ExamSessionRow s) => switch (s.status) {
          'open' => 0,
          'running' => 1,
          'closed' => 2,
          'published' => 3,
          _ => 4,
        };
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final da = a.closesAt, db = b.closesAt;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    return b.yearLabel.compareTo(a.yearLabel);
  }
}

/// Année scolaire courante au format du référentiel (« 2025-2026 »).
/// L'année scolaire congolaise court de septembre à juin.
String currentSchoolYearLabel([DateTime? now]) {
  final d = now ?? DateTime.now();
  final start = d.month >= 9 ? d.year : d.year - 1;
  return '$start-${start + 1}';
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String);

final examOverviewProvider =
    FutureProvider.autoDispose<ExamOverview>((ref) async {
  ref.keepAlive();
  final yearId = ref.watch(activeYearIdProvider);

  // Classes porteuses d'un enjeu d'examen. Les classes de passage sont
  // volontairement exclues : les afficher noierait le signal.
  //
  // ⚠️ Le filtre sur l'ANNÉE ACTIVE n'est pas décoratif. Dès que l'année
  // suivante est ouverte — ce que fait la reconduction des classes — ses
  // Terminales existent déjà, vides. Sans ce filtre, l'écran comptait deux fois
  // ses classes d'examen et affichait des lignes « 0 élève » à côté des vraies :
  // un chef d'établissement y lisait une couverture d'inscription fausse.
  final classRows = await db.getAll(
    'SELECT c.id, c.name, c.level_code, c.cycle_code, c.filiere_label, '
    '       c.exam_status, c.exam_override_id, '
    '       e.code AS exam_code, e.short_name, e.name AS exam_name, '
    '       (SELECT COUNT(*) FROM class_enrollments ce '
    '         WHERE ce.class_id = c.id AND ce.status = ?) AS effectif, '
    '       (SELECT COUNT(*) FROM exam_candidates ec '
    '         WHERE ec.class_id = c.id) AS candidates '
    '  FROM classes c '
    '  LEFT JOIN national_exams e '
    '    ON e.id = COALESCE(c.exam_override_id, c.exam_id) '
    ' WHERE COALESCE(c.is_active, 1) <> 0 AND c.exam_status IN (?, ?) '
    '   AND c.academic_year_id = ? '
    ' ORDER BY c.cycle_code, c.level_code, c.name',
    ['active', 'examen', 'a_qualifier', yearId ?? ''],
  );

  final sessionRows = await db.getAll(
    'SELECT s.id, s.year_label, s.registration_opens_at, s.registration_closes_at, '
    '       s.written_from, s.max_age, s.status, e.code AS exam_code, e.short_name '
    '  FROM exam_sessions s '
    '  JOIN national_exams e ON e.id = s.exam_id '
    ' WHERE s.status <> ? '
    ' ORDER BY s.registration_closes_at',
    ['cancelled'],
  );

  return ExamOverview(
    classes: [
      for (final r in classRows)
        ExamClassRow(
          id: r['id'] as String,
          name: r['name'] as String? ?? '',
          levelCode: r['level_code'] as String? ?? '',
          cycleCode: r['cycle_code'] as String? ?? '',
          filiereLabel: r['filiere_label'] as String?,
          status: ClassExamStatus.parse(r['exam_status'] as String?),
          examCode: r['exam_code'] as String?,
          examShortName: r['short_name'] as String?,
          examName: r['exam_name'] as String?,
          isOverridden: r['exam_override_id'] != null,
          effectif: (r['effectif'] as int?) ?? 0,
          candidates: (r['candidates'] as int?) ?? 0,
        ),
    ],
    sessions: [
      for (final r in sessionRows)
        ExamSessionRow(
          id: r['id'] as String,
          examCode: r['exam_code'] as String? ?? '',
          examShortName: r['short_name'] as String? ?? '',
          yearLabel: r['year_label'] as String? ?? '',
          opensAt: _date(r['registration_opens_at']),
          closesAt: _date(r['registration_closes_at']),
          writtenFrom: _date(r['written_from']),
          maxAge: r['max_age'] as int?,
          status: r['status'] as String? ?? 'draft',
        ),
    ],
  );
});
