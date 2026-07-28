import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../examens/models/exam_stats.dart';

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

/// Barre du graphique : candidats par examen.
class MinistryExamBar {
  const MinistryExamBar(this.examShortName, this.tutelle, this.candidates);
  final String examShortName;
  final String? tutelle;
  final int candidates;
}

/// Examens dont le dossier exige une attestation de stage (note METP).
const _kBacProInternship = {'BAC_T', 'BAC_P'};

class MinistryExamsData {
  const MinistryExamsData({
    required this.schools,
    required this.byExam,
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
    required this.internshipsTotal,
    required this.attestationsTotal,
    required this.bacBlocked,
    required this.yearLabel,
  });

  final List<MinistrySchoolExam> schools;
  final List<MinistryExamBar> byExam;

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

  /// Module Stages, agrégé sur le réseau — le ministère pilote les 2 modules.
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

  static const empty = MinistryExamsData(
    schools: [],
    byExam: [],
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

  final bySchool = <String, _SchoolAcc>{};
  final byExam = <String, _ExamAcc>{};
  final statInputs = <ExamStatInput>[];   // pour la ventilation filière/département
  final sessionIds = <String>{};
  var bacBlocked = 0;
  String? year;

  for (final r in (rows as List)) {
    final schoolId = r['school_id'] as String? ?? '—';
    final schoolName = (r['schools']?['name'] as String?) ?? '—';
    final session = r['exam_sessions'] as Map<String, dynamic>?;
    final exam = session?['national_exams'] as Map<String, dynamic>?;
    final examName = (exam?['short_name'] as String?) ?? '—';
    final examCode = exam?['code'] as String?;
    final tutelle = exam?['tutelle'] as String?;
    year ??= session?['year_label'] as String?;
    if (session?['id'] != null) sessionIds.add(session!['id'] as String);

    // Bac technique/pro sans attestation de stage = dossier irrecevable.
    final studentId = r['student_id'] as String?;
    if (_kBacProInternship.contains(examCode) &&
        (studentId == null || !studentsWithAttestation.contains(studentId))) {
      bacBlocked++;
    }

    final dossier = r['dossier_status'] as String?;
    final result = r['result'] as String?;
    final isComplete = dossier != null && dossier != 'incomplet';
    final isSubmitted = dossier == 'depose' || dossier == 'valide';
    final hasResult = result != null && result != 'en_attente';

    final department = r['schools']?['department'] as String?;
    final s = bySchool.putIfAbsent(
        schoolId, () => _SchoolAcc(schoolId, schoolName, department));
    s.candidates++;
    if (isComplete) s.complete++;
    if (isSubmitted) s.submitted++;
    if (hasResult) s.withResult++;
    if (result == 'admis') s.admitted++;

    final se = s.byExam.putIfAbsent(examName, () => _ExamAcc(examName, tutelle));
    se.candidates++;
    if (isComplete) se.complete++;
    if (isSubmitted) se.submitted++;
    if (hasResult) se.withResult++;
    if (result == 'admis') se.admitted++;

    final e = byExam.putIfAbsent(examName, () => _ExamAcc(examName, tutelle));
    e.candidates++;

    statInputs.add(ExamStatInput(
      result: result ?? 'en_attente',
      filiereLabel: r['classes']?['filiere_label'] as String?,
      department: r['schools']?['department'] as String?,
    ));
  }

  var acknowledged = 0;
  for (final t in (trRows as List)) {
    final schoolId = t['school_id'] as String?;
    if (schoolId == null) continue;
    final s = bySchool[schoolId];
    if (s != null) {
      s.transmissions++;
      final at = _d(t['transmitted_at']);
      if (at != null &&
          (s.lastTransmittedAt == null || at.isAfter(s.lastTransmittedAt!))) {
        s.lastTransmittedAt = at;
      }
    }
    if (t['status'] == 'accuse_reception' || t['status'] == 'traite') {
      acknowledged++;
    }
  }

  final schools = bySchool.values
      .map((a) => MinistrySchoolExam(
            schoolId: a.schoolId,
            schoolName: a.schoolName,
            candidates: a.candidates,
            complete: a.complete,
            submitted: a.submitted,
            withResult: a.withResult,
            admitted: a.admitted,
            transmissions: a.transmissions,
            lastTransmittedAt: a.lastTransmittedAt,
            department: a.department,
            byExam: (a.byExam.values.toList()
                  ..sort((x, y) => y.candidates.compareTo(x.candidates)))
                .map((e) => SchoolExamLine(
                      examShortName: e.name,
                      candidates: e.candidates,
                      complete: e.complete,
                      submitted: e.submitted,
                      withResult: e.withResult,
                      admitted: e.admitted,
                    ))
                .toList(),
          ))
      .toList()
    ..sort((x, y) => y.candidates.compareTo(x.candidates));

  final bars = byExam.values
      .map((a) => MinistryExamBar(a.name, a.tutelle, a.candidates))
      .toList()
    ..sort((x, y) => y.candidates.compareTo(x.candidates));

  return MinistryExamsData(
    schools: schools,
    byExam: bars,
    byFiliere: groupExamLines(statInputs, (r) => r.filiereLabel),
    byDepartment: groupExamLines(statInputs, (r) => r.department),
    totalCandidates: schools.fold(0, (s, e) => s + e.candidates),
    totalComplete: schools.fold(0, (s, e) => s + e.complete),
    totalSubmitted: schools.fold(0, (s, e) => s + e.submitted),
    totalWithResult: schools.fold(0, (s, e) => s + e.withResult),
    totalAdmitted: schools.fold(0, (s, e) => s + e.admitted),
    sessionCount: sessionIds.length,
    schoolsWithCandidates: schools.where((s) => s.candidates > 0).length,
    transmissionCount: (trRows).length,
    transmissionsAcknowledged: acknowledged,
    internshipsTotal: internshipsTotal,
    attestationsTotal: attestationsTotal,
    bacBlocked: bacBlocked,
    yearLabel: year,
  );
});

class _SchoolAcc {
  _SchoolAcc(this.schoolId, this.schoolName, this.department);
  final String schoolId;
  final String schoolName;
  final String? department;
  int candidates = 0;
  int complete = 0;
  int submitted = 0;
  int withResult = 0;
  int admitted = 0;
  int transmissions = 0;
  DateTime? lastTransmittedAt;
  final Map<String, _ExamAcc> byExam = {};
}

class _ExamAcc {
  _ExamAcc(this.name, this.tutelle);
  final String name;
  final String? tutelle;
  int candidates = 0;
  int complete = 0;
  int submitted = 0;
  int withResult = 0;
  int admitted = 0;
}

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
        'body': '${school.candidates} candidat(s) déclaré(s) dans votre '
            'établissement n\'ont fait l\'objet d\'aucune transmission à la '
            'DEC. Un dossier non déposé avant la clôture ne se rattrape pas.',
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
