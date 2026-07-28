import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../examens/models/exam_stats.dart';
import 'ministry_exam_rows.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COCKPIT EXAMENS DU MINISTÈRE — vue NATIONALE, online (admin_groupe).
//
//  ── POURQUOI ICI, ET PAS OFFLINE ───────────────────────────────────────────
//  Le ministère (porté par l'espace admin_groupe) pilote SES écoles depuis le
//  serveur : `supabase.from()` direct, jamais PowerSync. La RLS scope déjà à son
//  groupe (`exam_candidates_select = group_id = auth_group_id()`) — cet écran
//  agrège ce qu'une école ne voit pas : la couverture de TOUT le réseau.
//
//  ── CE QU'IL RÉVÈLE ─────────────────────────────────────────────────────────
//  Combien d'écoles ont inscrit, combien de candidats par examen, combien de
//  dossiers complets, et surtout QUI a déjà DÉPOSÉ à la DEC (transmissions).
//  Un candidat non déposé avant la clôture perd une année : c'est la seule
//  information irrattrapable, elle appartient au pilotage ministériel.
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'une école présente à UN examen — la ligne du détail d'établissement.
class SchoolExamLine {
  const SchoolExamLine({
    required this.examShortName,
    required this.candidates,
    required this.complete,
    required this.submitted,
    required this.withResult,
    required this.admitted,
  });

  final String examShortName;
  final int candidates;
  final int complete;
  final int submitted;
  final int withResult;
  final int admitted;

  /// `null` tant qu'aucun résultat n'est connu : 0 % dirait « tous recalés ».
  double? get successRate =>
      withResult == 0 ? null : admitted / withResult * 100;
}

/// Agrégat par école : la ligne du tableau.
class MinistrySchoolExam {
  const MinistrySchoolExam({
    required this.schoolId,
    required this.schoolName,
    required this.candidates,
    required this.complete,
    required this.submitted,
    required this.withResult,
    required this.admitted,
    required this.transmissions,
    required this.lastTransmittedAt,
    this.department,
    this.byExam = const [],
  });

  final String schoolId;
  final String schoolName;
  final int candidates;
  final int complete;
  final int submitted;
  final int withResult;
  final int admitted;
  final int transmissions;
  final DateTime? lastTransmittedAt;

  /// Département de rattachement — le ministère relance par territoire.
  final String? department;

  /// Détail par examen : une école présente rarement un seul concours, et
  /// « 12 candidats » ne dit pas lesquels sont en retard.
  final List<SchoolExamLine> byExam;

  int get incomplete => candidates - complete;
  int get pending => candidates - withResult;

  /// Une école qui a des candidats mais n'a rien transmis : le point chaud du
  /// pilotage. Le ministère la relance avant la clôture.
  bool get hasCandidatesNotTransmitted => candidates > 0 && transmissions == 0;

  double get completionRate => candidates == 0 ? 0 : complete / candidates;
}

class MinistryExamsData {
  const MinistryExamsData({
    required this.rows,
    required this.transmissions,
    required this.selectedExamCode,
    required this.examOptions,
    required this.schools,
    required this.byFiliere,
    required this.byDepartment,
    required this.totalCandidates,
    required this.totalComplete,
    required this.totalSubmitted,
    required this.totalWithResult,
    required this.totalAdmitted,
    required this.sessionCount,
    required this.schoolsWithCandidates,
    required this.transmissionCount,
    required this.transmissionsAcknowledged,
    required this.transmittedSchoolIds,
    required this.internshipsTotal,
    required this.attestationsTotal,
    required this.bacBlocked,
    required this.yearLabel,
  });

  /// Les lignes BRUTES du réseau, tous examens confondus. Elles restent en
  /// mémoire pour que [forExam] recompose sans rien redemander au serveur, et
  /// pour que les vues (entonnoir, drill-down) travaillent sur la même source.
  final List<MinistryCandidateRow> rows;
  final List<MinistryTransmissionRow> transmissions;

  /// Examen du périmètre courant — `null` = tous.
  final String? selectedExamCode;

  /// Les examens proposés par la barre de puces, calculés sur TOUT le réseau.
  final List<ExamOption> examOptions;

  final List<MinistrySchoolExam> schools;

  /// Réussite ventilée par FILIÈRE technique et par DÉPARTEMENT — les deux
  /// axes de pilotage propres au ministère. Taux `null` tant que non proclamé.
  final List<ExamStatLine> byFiliere;
  final List<ExamStatLine> byDepartment;

  final int totalCandidates;
  final int totalComplete;
  final int totalSubmitted;
  final int totalWithResult;
  final int totalAdmitted;
  final int sessionCount;
  final int schoolsWithCandidates;
  final int transmissionCount;
  final int transmissionsAcknowledged;

  /// Écoles ayant déposé au moins une fois — sert au drill-down par axe, qui
  /// signale celles dont rien n'est parti.
  final Set<String> transmittedSchoolIds;

  /// Module Stages, agrégé sur le réseau — le ministère pilote les 2 modules.
  /// Volontairement NON filtré par examen : c'est un compteur de réseau.
  final int internshipsTotal;
  final int attestationsTotal;

  /// Candidats de bac technique/pro SANS attestation de stage : dossier
  /// irrecevable. L'alerte réseau la plus coûteuse (une année perdue).
  final int bacBlocked;
  final String? yearLabel;

  /// Écoles à risque : des candidats, rien de transmis.
  int get schoolsAtRisk =>
      schools.where((s) => s.hasCandidatesNotTransmitted).length;

  double? get successRate =>
      totalWithResult == 0 ? null : totalAdmitted / totalWithResult * 100;

  /// Le stage ne conditionne que les bacs technique et professionnel. Sur un
  /// autre examen, afficher « Stages du réseau » et « Bacs bloqués » promène
  /// une alerte hors de son périmètre — et une alerte qu'on apprend à ignorer
  /// ne protège plus de rien.
  bool get showsInternshipKpis =>
      selectedExamCode == null ||
      kBacProInternship.contains(selectedExamCode);

  /// Recompose la vue pour un autre examen. Pure : aucune requête.
  MinistryExamsData forExam(String? code) => buildMinistryExamsData(
        rows: rows,
        transmissions: transmissions,
        internshipsTotal: internshipsTotal,
        attestationsTotal: attestationsTotal,
        yearLabel: yearLabel,
        examCode: code,
      );

  static const empty = MinistryExamsData(
    rows: [],
    transmissions: [],
    selectedExamCode: null,
    examOptions: [],
    schools: [],
    byFiliere: [],
    byDepartment: [],
    totalCandidates: 0,
    totalComplete: 0,
    totalSubmitted: 0,
    totalWithResult: 0,
    totalAdmitted: 0,
    sessionCount: 0,
    schoolsWithCandidates: 0,
    transmissionCount: 0,
    transmissionsAcknowledged: 0,
    transmittedSchoolIds: {},
    internshipsTotal: 0,
    attestationsTotal: 0,
    bacBlocked: 0,
    yearLabel: null,
  );
}

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v as String);

final adminExamsProvider =
    FutureProvider.autoDispose<MinistryExamsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  if (groupId == null) return MinistryExamsData.empty;

  // Candidatures du réseau, jointes à l'examen, à l'école (+ département) et à
  // la classe (+ filière) : ce sont les deux axes que le ministère pilote.
  final rows = await client
      .from('exam_candidates')
      .select('school_id, student_id, dossier_status, result, '
          'schools!inner(name, department), '
          'classes(filiere_label), '
          'exam_sessions!inner(id, year_label, '
          'national_exams!inner(code, short_name, tutelle))')
      .eq('group_id', groupId);

  // Transmissions du réseau (dépôts opposables à la DEC).
  final trRows = await client
      .from('transmissions')
      .select('school_id, status, transmitted_at')
      .eq('group_id', groupId);

  // Module STAGES agrégé : le ministère pilote les deux modules.
  final internRows = await client
      .from('internships')
      .select('student_id, attestation_issued_at')
      .eq('group_id', groupId);
  final internshipsTotal = (internRows as List).length;
  var attestationsTotal = 0;
  final studentsWithAttestation = <String>{};
  for (final i in internRows) {
    if (i['attestation_issued_at'] != null) {
      attestationsTotal++;
      final sid = i['student_id'] as String?;
      if (sid != null) studentsWithAttestation.add(sid);
    }
  }

  // L'agrégation vit dans `ministry_exam_rows.dart`, en fonctions PURES : le
  // provider ne fait plus que traduire les lignes SQL en lignes de domaine.
  // C'est ce qui permet au filtre examen de recomposer toute la page sans
  // aucun aller-retour serveur — et à chaque règle de calcul d'être vérifiée
  // sans base.
  final candidates = <MinistryCandidateRow>[];
  String? year;

  for (final raw in (rows as List)) {
    final r = raw as Map<String, dynamic>;
    final session = r['exam_sessions'] as Map<String, dynamic>?;
    final exam = session?['national_exams'] as Map<String, dynamic>?;
    year ??= session?['year_label'] as String?;
    final studentId = r['student_id'] as String?;

    candidates.add(MinistryCandidateRow(
      schoolId: r['school_id'] as String? ?? '—',
      schoolName: (r['schools']?['name'] as String?) ?? '—',
      department: r['schools']?['department'] as String?,
      examCode: (exam?['code'] as String?) ?? '—',
      examShortName: (exam?['short_name'] as String?) ?? '—',
      tutelle: exam?['tutelle'] as String?,
      sessionId: session?['id'] as String?,
      filiereLabel: r['classes']?['filiere_label'] as String?,
      dossierStatus: r['dossier_status'] as String?,
      result: (r['result'] as String?) ?? 'en_attente',
      hasAttestation:
          studentId != null && studentsWithAttestation.contains(studentId),
    ));
  }

  final transmissions = [
    for (final t in (trRows as List))
      MinistryTransmissionRow(
        schoolId: t['school_id'] as String?,
        status: t['status'] as String?,
        transmittedAt: _d(t['transmitted_at']),
      ),
  ];

  return buildMinistryExamsData(
    rows: candidates,
    transmissions: transmissions,
    internshipsTotal: internshipsTotal,
    attestationsTotal: attestationsTotal,
    yearLabel: year,
  );
});

// ════════════════════════════════════════════════════════════════════════════
//  RELANCE DES ÉCOLES EN RETARD.
//
//  Le cockpit savait NOMMER les écoles à risque — des candidats déclarés, rien
//  de transmis — sans rien permettre d'en faire. Or c'est la seule alerte
//  irrattrapable de la campagne : après la clôture, un candidat non déposé perd
//  son année. Constater sans pouvoir agir était le trou de cet écran.
//
//  La relance emprunte le même canal que l'avis de publication : une
//  notification au CHEF D'ÉTABLISSEMENT, seul décideur du dépôt. Prévenir tout
//  le personnel noierait l'information.
// ════════════════════════════════════════════════════════════════════════════
class MinistryExamActions {
  const MinistryExamActions(this._ref);
  final Ref _ref;

  /// Relance les chefs des écoles passées en argument. Renvoie le nombre
  /// d'avis réellement envoyés — zéro destinataire est une information, pas
  /// une erreur : une école sans chef enregistré ne peut pas être relancée.
  Future<int> remindSchools(List<MinistrySchoolExam> schools) async {
    if (schools.isEmpty) return 0;
    final client = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) return 0;

    final byId = {for (final s in schools) s.schoolId: s};
    final heads = await client
        .from('profiles')
        .select('id, school_id')
        .eq('group_id', groupId)
        .inFilter('school_id', byId.keys.toList())
        .inFilter('role', ['directeur', 'proviseur']);

    final rows = <Map<String, dynamic>>[];
    for (final h in heads as List) {
      final head = h as Map<String, dynamic>;
      final school = byId[head['school_id'] as String?];
      if (school == null) continue;
      rows.add({
        'group_id': groupId,
        'recipient_id': head['id'],
        'type': 'exam_transmission_reminder',
        'title': 'Dossiers d\'examen non transmis',
        // Le message porte le CHIFFRE de l'école : une relance générique se
        // classe sans suite, un « vos 12 candidats » se traite.
        // Le message porte le CHIFFRE de l'école, et le détail quand il
        // existe : une relance générique se classe, « dont 6 au dossier
        // incomplet » se traite — le chef sait par où commencer.
        'body': '${school.candidates} candidat(s) déclaré(s) dans votre '
            'établissement n\'ont fait l\'objet d\'aucune transmission à la '
            'DEC'
            '${school.incomplete > 0 ? ', dont ${school.incomplete} au dossier incomplet' : ''}'
            '. Un dossier non déposé avant la clôture ne se rattrape pas.',
        'data': {
          'school_id': school.schoolId,
          'candidates': school.candidates,
          'submitted': school.submitted,
        },
      });
    }
    if (rows.isEmpty) return 0;

    await client.from('notifications').insert(rows);
    return rows.length;
  }
}

final ministryExamActionsProvider =
    Provider.autoDispose<MinistryExamActions>(MinistryExamActions.new);

/// Examen sélectionné dans le cockpit — `null` = tous les examens.
///
/// Vit délibérément HORS du `FutureProvider` : changer de périmètre ne doit
/// rien redemander au serveur. Tout se recalcule sur les lignes déjà chargées,
/// par [MinistryExamsData.forExam].
final examFilterProvider = StateProvider.autoDispose<String?>((_) => null);
