import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

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

class MinistryExamsData {
  const MinistryExamsData({
    required this.schools,
    required this.byExam,
    required this.totalCandidates,
    required this.totalComplete,
    required this.totalSubmitted,
    required this.totalWithResult,
    required this.totalAdmitted,
    required this.sessionCount,
    required this.schoolsWithCandidates,
    required this.transmissionCount,
    required this.transmissionsAcknowledged,
    required this.yearLabel,
  });

  final List<MinistrySchoolExam> schools;
  final List<MinistryExamBar> byExam;
  final int totalCandidates;
  final int totalComplete;
  final int totalSubmitted;
  final int totalWithResult;
  final int totalAdmitted;
  final int sessionCount;
  final int schoolsWithCandidates;
  final int transmissionCount;
  final int transmissionsAcknowledged;
  final String? yearLabel;

  /// Écoles à risque : des candidats, rien de transmis.
  int get schoolsAtRisk =>
      schools.where((s) => s.hasCandidatesNotTransmitted).length;

  double? get successRate =>
      totalWithResult == 0 ? null : totalAdmitted / totalWithResult * 100;

  static const empty = MinistryExamsData(
    schools: [],
    byExam: [],
    totalCandidates: 0,
    totalComplete: 0,
    totalSubmitted: 0,
    totalWithResult: 0,
    totalAdmitted: 0,
    sessionCount: 0,
    schoolsWithCandidates: 0,
    transmissionCount: 0,
    transmissionsAcknowledged: 0,
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

  // Candidatures du réseau, jointes à l'examen et à l'école.
  final rows = await client
      .from('exam_candidates')
      .select('school_id, dossier_status, result, '
          'schools!inner(name), '
          'exam_sessions!inner(id, year_label, '
          'national_exams!inner(short_name, tutelle))')
      .eq('group_id', groupId);

  // Transmissions du réseau (dépôts opposables à la DEC).
  final trRows = await client
      .from('transmissions')
      .select('school_id, status, transmitted_at')
      .eq('group_id', groupId);

  final bySchool = <String, _SchoolAcc>{};
  final byExam = <String, _ExamAcc>{};
  final sessionIds = <String>{};
  String? year;

  for (final r in (rows as List)) {
    final schoolId = r['school_id'] as String? ?? '—';
    final schoolName = (r['schools']?['name'] as String?) ?? '—';
    final session = r['exam_sessions'] as Map<String, dynamic>?;
    final exam = session?['national_exams'] as Map<String, dynamic>?;
    final examName = (exam?['short_name'] as String?) ?? '—';
    final tutelle = exam?['tutelle'] as String?;
    year ??= session?['year_label'] as String?;
    if (session?['id'] != null) sessionIds.add(session!['id'] as String);

    final dossier = r['dossier_status'] as String?;
    final result = r['result'] as String?;
    final isComplete = dossier != null && dossier != 'incomplet';
    final isSubmitted = dossier == 'depose' || dossier == 'valide';
    final hasResult = result != null && result != 'en_attente';

    final s = bySchool.putIfAbsent(
        schoolId, () => _SchoolAcc(schoolId, schoolName));
    s.candidates++;
    if (isComplete) s.complete++;
    if (isSubmitted) s.submitted++;
    if (hasResult) s.withResult++;
    if (result == 'admis') s.admitted++;

    final e = byExam.putIfAbsent(examName, () => _ExamAcc(examName, tutelle));
    e.candidates++;
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
    totalCandidates: schools.fold(0, (s, e) => s + e.candidates),
    totalComplete: schools.fold(0, (s, e) => s + e.complete),
    totalSubmitted: schools.fold(0, (s, e) => s + e.submitted),
    totalWithResult: schools.fold(0, (s, e) => s + e.withResult),
    totalAdmitted: schools.fold(0, (s, e) => s + e.admitted),
    sessionCount: sessionIds.length,
    schoolsWithCandidates: schools.where((s) => s.candidates > 0).length,
    transmissionCount: (trRows).length,
    transmissionsAcknowledged: acknowledged,
    yearLabel: year,
  );
});

class _SchoolAcc {
  _SchoolAcc(this.schoolId, this.schoolName);
  final String schoolId;
  final String schoolName;
  int candidates = 0;
  int complete = 0;
  int submitted = 0;
  int withResult = 0;
  int admitted = 0;
  int transmissions = 0;
  DateTime? lastTransmittedAt;
}

class _ExamAcc {
  _ExamAcc(this.name, this.tutelle);
  final String name;
  final String? tutelle;
  int candidates = 0;
}
