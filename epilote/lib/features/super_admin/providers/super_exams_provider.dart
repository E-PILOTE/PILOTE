import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/paged_fetch.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ADOPTION EXAMENS & STAGES — vue PLATEFORME (super_admin), online.
//
//  Le super_admin n'est pas le ministère : il opère le SaaS. Ce qui l'intéresse
//  n'est pas la couverture d'un réseau mais l'ADOPTION du module à l'échelle
//  nationale — combien de groupes s'en servent, combien de candidats d'État
//  sont gérés dans l'outil, combien de dépôts DEC transitent. La RLS autorise
//  `is_super_admin()` en SELECT sur exam_candidates / transmissions / internships
//  (migs 0046/0048/0054), donc l'agrégat traverse tous les groupes.
//
//  Comme la section ministère, elle s'efface si personne n'utilise le module.
// ════════════════════════════════════════════════════════════════════════════

/// Barre du graphique : candidats par examen, toutes écoles confondues.
class PlatformExamBar {
  const PlatformExamBar(this.examShortName, this.tutelle, this.candidates);
  final String examShortName;
  final String? tutelle;
  final int candidates;
}

const _kBacProInternship = {'BAC_T', 'BAC_P'};

class PlatformExamsData {
  const PlatformExamsData({
    required this.groupsUsing,
    required this.schoolsWithCandidates,
    required this.totalCandidates,
    required this.totalComplete,
    required this.sessionCount,
    required this.transmissionCount,
    required this.internshipsTotal,
    required this.attestationsTotal,
    required this.bacBlocked,
    required this.byExam,
  });

  final int groupsUsing;
  final int schoolsWithCandidates;
  final int totalCandidates;
  final int totalComplete;
  final int sessionCount;
  final int transmissionCount;
  final int internshipsTotal;
  final int attestationsTotal;
  final int bacBlocked;
  final List<PlatformExamBar> byExam;

  bool get used =>
      totalCandidates > 0 || sessionCount > 0 || internshipsTotal > 0;

  static const empty = PlatformExamsData(
    groupsUsing: 0,
    schoolsWithCandidates: 0,
    totalCandidates: 0,
    totalComplete: 0,
    sessionCount: 0,
    transmissionCount: 0,
    internshipsTotal: 0,
    attestationsTotal: 0,
    bacBlocked: 0,
    byExam: [],
  );
}

final superExamsProvider =
    FutureProvider.autoDispose<PlatformExamsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // ⚠️ PAGINATION OBLIGATOIRE — voir `core/utils/paged_fetch.dart`.
  //  Ces trois lectures alimentent TOUS les chiffres de la page examens de la
  //  plateforme : candidats, sessions, ventilation par examen, blocages du
  //  baccalauréat. Sans pagination, PostgREST rend les 1 000 premières lignes
  //  et se tait — à l'échelle nationale, aucun de ces nombres n'aurait été
  //  celui du pays. Les ventilations exigent les lignes ; le seul compteur
  //  isolé, celui des transmissions, passe par un `count` serveur.
  final rows = await fetchAllRows(() => client.from('exam_candidates').select(
      'group_id, school_id, student_id, dossier_status, '
      'exam_sessions!inner(id, national_exams!inner(code, short_name, tutelle))'));

  final transmissionCount =
      await client.from('transmissions').count(CountOption.exact);

  final internRows = await fetchAllRows(() => client
      .from('internships')
      .select('student_id, attestation_issued_at'));
  final internshipsTotal = internRows.length;
  var attestationsTotal = 0;
  final studentsWithAttestation = <String>{};
  for (final i in internRows) {
    if (i['attestation_issued_at'] != null) {
      attestationsTotal++;
      final sid = i['student_id'] as String?;
      if (sid != null) studentsWithAttestation.add(sid);
    }
  }

  final groups = <String>{};
  final schools = <String>{};
  final sessions = <String>{};
  final byExam = <String, _ExamAcc>{};
  var totalCandidates = 0;
  var totalComplete = 0;
  var bacBlocked = 0;

  for (final r in (rows as List)) {
    totalCandidates++;
    final gid = r['group_id'] as String?;
    if (gid != null) groups.add(gid);
    final sid = r['school_id'] as String?;
    if (sid != null) schools.add(sid);

    final session = r['exam_sessions'] as Map<String, dynamic>?;
    final exam = session?['national_exams'] as Map<String, dynamic>?;
    final examName = (exam?['short_name'] as String?) ?? '—';
    final examCode = exam?['code'] as String?;
    final tutelle = exam?['tutelle'] as String?;
    if (session?['id'] != null) sessions.add(session!['id'] as String);

    final dossier = r['dossier_status'] as String?;
    if (dossier != null && dossier != 'incomplet') totalComplete++;

    final studentId = r['student_id'] as String?;
    if (_kBacProInternship.contains(examCode) &&
        (studentId == null || !studentsWithAttestation.contains(studentId))) {
      bacBlocked++;
    }

    byExam.putIfAbsent(examName, () => _ExamAcc(examName, tutelle)).candidates++;
  }

  final bars = byExam.values
      .map((a) => PlatformExamBar(a.name, a.tutelle, a.candidates))
      .toList()
    ..sort((x, y) => y.candidates.compareTo(x.candidates));

  return PlatformExamsData(
    groupsUsing: groups.length,
    schoolsWithCandidates: schools.length,
    totalCandidates: totalCandidates,
    totalComplete: totalComplete,
    sessionCount: sessions.length,
    transmissionCount: transmissionCount,
    internshipsTotal: internshipsTotal,
    attestationsTotal: attestationsTotal,
    bacBlocked: bacBlocked,
    byExam: bars,
  );
});

class _ExamAcc {
  _ExamAcc(this.name, this.tutelle);
  final String name;
  final String? tutelle;
  int candidates = 0;
}
