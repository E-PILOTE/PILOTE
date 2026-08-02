import '../../examens/models/exam_stats.dart';
import 'admin_exams_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA LIGNE CANDIDAT DU RÉSEAU — et tout ce qu'on en déduit.
//
//  ── POURQUOI CE FICHIER EXISTE ──────────────────────────────────────────────
//  Le cockpit agrégeait tout à l'intérieur de son `FutureProvider` : les huit
//  indicateurs, la ventilation par filière, celle par département, le tableau
//  des écoles. Deux conséquences.
//
//  D'abord, il mélangeait les examens. Un seul « taux de réussite » couvrant à
//  la fois le BET, le BEP, le BAC technique et le concours d'entrée en seconde
//  ne correspond à rien : la DEC elle-même proclame examen par examen — BET
//  77,59 %, BEP 74,29 %, BAC T/P 51,61 % — et n'a jamais publié de chiffre
//  agrégé. Le nôtre était donc un chiffre que personne ne pouvait recouper.
//
//  Ensuite, rien n'était testable : changer de périmètre aurait exigé une
//  requête, et vérifier une règle de calcul aurait exigé une base.
//
//  Ici l'agrégation est PURE. Le provider fait sa requête une fois, garde les
//  lignes, et `forExam()` recompose en mémoire. Le filtre examen ne coûte donc
//  aucun aller-retour serveur, et chaque règle se vérifie sans Supabase.
// ════════════════════════════════════════════════════════════════════════════

/// Examens dont le dossier exige une attestation de stage (note METP). Un
/// candidat au BET n'en a jamais eu besoin : l'alerte « bac bloqué » n'a de
/// sens que sur ce périmètre.
///
/// ⚠️ Les codes RÉELS sont `BAC_T` et `BAC_P` : la Direction des examens et
/// concours publie DEUX palmarès, « Baccalauréat technique » et « Baccalauréat
/// professionnel ». Le libellé « bac technique et professionnel » qu'emploie la
/// presse désigne la SESSION commune de juin, où les deux jurys siègent
/// ensemble — pas un diplôme unique. La migration 0065 en avait tiré une fusion
/// erronée, défaite par la 0079.
///
/// `BAC_TP` reste listé pour qu'un groupe pas encore migré ne perde pas son
/// alerte du jour au lendemain.
const kBacProInternship = {'BAC_T', 'BAC_P', 'BAC_TP'};

const _kUnsetDepartment = 'Non renseigné';

/// Une candidature du réseau, réduite à ce que le cockpit en agrège.
class MinistryCandidateRow {
  const MinistryCandidateRow({
    required this.schoolId,
    required this.schoolName,
    required this.department,
    required this.examCode,
    required this.examShortName,
    required this.tutelle,
    required this.sessionId,
    required this.filiereLabel,
    required this.dossierStatus,
    required this.result,
    required this.hasAttestation,
  });

  final String schoolId;
  final String schoolName;
  final String? department;
  final String examCode;
  final String examShortName;
  final String? tutelle;
  final String? sessionId;
  final String? filiereLabel;
  final String? dossierStatus;
  final String result;

  /// Le candidat dispose d'une attestation de stage. Ne concerne que les bacs
  /// technique et professionnel — ailleurs, la valeur ne sert à rien.
  final bool hasAttestation;

  bool get isComplete => dossierStatus != null && dossierStatus != 'incomplet';
  bool get isSubmitted =>
      dossierStatus == 'depose' || dossierStatus == 'valide';

  /// Règle UNIQUE du réseau, empruntée à `exam_stats.dart` : un absent ou un
  /// fraudeur a bien un résultat, il n'est simplement pas admis. Ne jamais
  /// réécrire `result != 'en_attente'` ici — la liste vit à un seul endroit.
  bool get hasKnownResult => isKnownExamResult(result);
  bool get isAdmitted => result == 'admis';

  /// Bac technique ou professionnel sans attestation : dossier irrecevable.
  bool get isBlockedBac =>
      kBacProInternship.contains(examCode) && !hasAttestation;

  String get departmentLabel {
    final d = department?.trim();
    return d == null || d.isEmpty ? _kUnsetDepartment : d;
  }
}

/// Un dépôt à la DEC, réduit à ce que le cockpit en lit.
class MinistryTransmissionRow {
  const MinistryTransmissionRow({
    required this.schoolId,
    required this.status,
    required this.transmittedAt,
  });

  final String? schoolId;
  final String? status;
  final DateTime? transmittedAt;

  bool get isAcknowledged =>
      status == 'accuse_reception' || status == 'traite';
}

/// Un examen proposé dans la barre de puces.
class ExamOption {
  const ExamOption({
    required this.code,
    required this.shortName,
    required this.tutelle,
    required this.candidates,
  });

  final String code;
  final String shortName;

  /// MEPSA (général) ou METP (technique/pro) — le tableau de bord colore la
  /// barre selon la tutelle.
  final String? tutelle;
  final int candidates;
}

/// Un groupe de l'entonnoir : ce qui a été déclaré, déposé, admis.
class ExamFunnelBar {
  const ExamFunnelBar({
    required this.label,
    required this.declared,
    required this.submitted,
    required this.admitted,
  });

  final String label;
  final int declared;
  final int submitted;
  final int admitted;
}

/// Une école sous l'angle d'un axe (une filière, un département).
class AxisSchoolLine {
  const AxisSchoolLine({
    required this.schoolId,
    required this.schoolName,
    required this.department,
    required this.candidates,
    required this.known,
    required this.admitted,
    required this.transmitted,
  });

  final String schoolId;
  final String schoolName;
  final String? department;
  final int candidates;

  /// Résultats proclamés — le dénominateur du taux.
  final int known;
  final int admitted;

  /// L'école a déposé au moins un dossier à la DEC.
  final bool transmitted;

  /// `null` tant qu'aucun résultat n'est proclamé. Zéro dirait « tous
  /// recalés » à une école qui attend simplement sa proclamation.
  double? get rate => known == 0 ? null : admitted / known;
}

enum ExamAxis {
  filiere,
  departement;

  String get label => this == ExamAxis.filiere ? 'filière' : 'département';
}

// ─── Agrégations pures ──────────────────────────────────────────────────────

/// Les lignes du périmètre demandé. `null` = tous les examens.
List<MinistryCandidateRow> scopeRows(
  List<MinistryCandidateRow> rows,
  String? examCode,
) =>
    examCode == null
        ? rows
        : rows.where((r) => r.examCode == examCode).toList();

/// Les examens du réseau, triés par effectif décroissant.
///
/// Toujours calculés sur l'ensemble des lignes, JAMAIS sur les lignes
/// filtrées : sélectionner le BET ne doit pas faire disparaître le BAC T de la
/// barre, sans quoi on ne pourrait plus en sortir.
List<ExamOption> buildExamOptions(List<MinistryCandidateRow> all) {
  final counts = <String, ({String shortName, String? tutelle, int n})>{};
  for (final r in all) {
    final prev = counts[r.examCode];
    counts[r.examCode] = (
      shortName: prev?.shortName ?? r.examShortName,
      tutelle: prev?.tutelle ?? r.tutelle,
      n: (prev?.n ?? 0) + 1,
    );
  }
  final out = [
    for (final e in counts.entries)
      ExamOption(
        code: e.key,
        shortName: e.value.shortName,
        tutelle: e.value.tutelle,
        candidates: e.value.n,
      ),
  ]..sort((a, b) => b.candidates.compareTo(a.candidates));
  return out;
}

/// L'entonnoir déclarés → déposés → admis, un groupe par examen.
List<ExamFunnelBar> funnelByExam(List<MinistryCandidateRow> rows) =>
    _funnel(rows, (r) => r.examShortName);

/// Le même entonnoir, un groupe par département — la lecture pertinente quand
/// un seul examen est sélectionné : une barre unique ne compare rien.
List<ExamFunnelBar> funnelByDepartment(List<MinistryCandidateRow> rows) =>
    _funnel(rows, (r) => r.departmentLabel);

List<ExamFunnelBar> _funnel(
  List<MinistryCandidateRow> rows,
  String Function(MinistryCandidateRow) keyOf,
) {
  final m = <String, _Funnel>{};
  for (final r in rows) {
    final a = m.putIfAbsent(keyOf(r), _Funnel.new);
    a.declared++;
    if (r.isSubmitted) a.submitted++;
    if (r.isAdmitted) a.admitted++;
  }
  final out = [
    for (final e in m.entries)
      ExamFunnelBar(
        label: e.key,
        declared: e.value.declared,
        submitted: e.value.submitted,
        admitted: e.value.admitted,
      ),
  ]..sort((a, b) => b.declared.compareTo(a.declared));
  return out;
}

/// Les écoles d'un axe (une filière, un département), classées.
///
/// L'ordre est le sujet : les taux CONNUS d'abord, du meilleur au pire, puis
/// les écoles dont rien n'est encore proclamé. Les mêler reviendrait à ranger
/// « on ne sait pas » avec « c'est mauvais » — et le ministère relancerait des
/// établissements irréprochables.
List<AxisSchoolLine> schoolsForAxis(
  List<MinistryCandidateRow> rows, {
  required ExamAxis axis,
  required String label,
  required Set<String> transmittedSchoolIds,
}) {
  final wanted = label.trim();
  final m = <String, _AxisAcc>{};
  for (final r in rows) {
    final key = switch (axis) {
      ExamAxis.filiere => _filiereLabel(r),
      ExamAxis.departement => r.departmentLabel,
    };
    if (key != wanted) continue;
    final a = m.putIfAbsent(
        r.schoolId, () => _AxisAcc(r.schoolName, r.department));
    a.candidates++;
    if (r.hasKnownResult) {
      a.known++;
      if (r.isAdmitted) a.admitted++;
    }
  }
  final out = [
    for (final e in m.entries)
      AxisSchoolLine(
        schoolId: e.key,
        schoolName: e.value.name,
        department: e.value.department,
        candidates: e.value.candidates,
        known: e.value.known,
        admitted: e.value.admitted,
        transmitted: transmittedSchoolIds.contains(e.key),
      ),
  ];
  out.sort((a, b) {
    final ra = a.rate, rb = b.rate;
    if (ra == null && rb == null) return b.candidates.compareTo(a.candidates);
    if (ra == null) return 1; // les inconnus en fin de liste
    if (rb == null) return -1;
    final byRate = rb.compareTo(ra);
    return byRate != 0 ? byRate : b.candidates.compareTo(a.candidates);
  });
  return out;
}

/// Étiquette de filière conforme à celle de `groupExamLines` : une filière
/// vide se range sous « Non renseigné » des deux côtés, sinon un clic sur la
/// ligne ouvrirait une modal vide.
String _filiereLabel(MinistryCandidateRow r) {
  final f = r.filiereLabel?.trim();
  return f == null || f.isEmpty ? _kUnsetDepartment : f;
}

/// Construit la vue du cockpit pour un périmètre d'examen donné.
///
/// `examCode == null` = tous les examens. Fonction pure : c'est elle que le
/// filtre appelle, et c'est pour cela que changer d'examen ne redemande rien
/// au serveur.
MinistryExamsData buildMinistryExamsData({
  required List<MinistryCandidateRow> rows,
  required List<MinistryTransmissionRow> transmissions,
  required int internshipsTotal,
  required int attestationsTotal,
  required String? yearLabel,
  String? examCode,
}) {
  final scoped = scopeRows(rows, examCode);

  final bySchool = <String, _SchoolAcc>{};
  final statInputs = <ExamStatInput>[];
  final sessionIds = <String>{};
  var bacBlocked = 0;

  for (final r in scoped) {
    if (r.sessionId != null) sessionIds.add(r.sessionId!);
    if (r.isBlockedBac) bacBlocked++;

    final s = bySchool.putIfAbsent(
        r.schoolId, () => _SchoolAcc(r.schoolId, r.schoolName, r.department));
    s.bump(r);
    s.byExam.putIfAbsent(r.examShortName, _ExamAcc.new).bump(r);

    statInputs.add(ExamStatInput(
      result: r.result,
      filiereLabel: r.filiereLabel,
      department: r.department,
    ));
  }

  var acknowledged = 0;
  final transmittedIds = <String>{};
  for (final t in transmissions) {
    final id = t.schoolId;
    if (t.isAcknowledged) acknowledged++;
    if (id == null) continue;
    transmittedIds.add(id);
    final s = bySchool[id];
    if (s == null) continue;
    s.transmissions++;
    final at = t.transmittedAt;
    if (at != null &&
        (s.lastTransmittedAt == null || at.isAfter(s.lastTransmittedAt!))) {
      s.lastTransmittedAt = at;
    }
  }

  final schools = bySchool.values.map((a) => a.build()).toList()
    ..sort((x, y) => y.candidates.compareTo(x.candidates));

  return MinistryExamsData(
    rows: rows,
    transmissions: transmissions,
    selectedExamCode: examCode,
    examOptions: buildExamOptions(rows),
    schools: schools,
    byFiliere: groupExamLines(statInputs, (r) => r.filiereLabel),
    byDepartment: groupExamLines(statInputs, (r) => r.department),
    totalCandidates: schools.fold(0, (s, e) => s + e.candidates),
    totalComplete: schools.fold(0, (s, e) => s + e.complete),
    totalSubmitted: schools.fold(0, (s, e) => s + e.submitted),
    totalWithResult: schools.fold(0, (s, e) => s + e.withResult),
    totalAdmitted: schools.fold(0, (s, e) => s + e.admitted),
    sessionCount: sessionIds.length,
    schoolsWithCandidates: schools.where((s) => s.candidates > 0).length,
    transmissionCount: transmissions.length,
    transmissionsAcknowledged: acknowledged,
    transmittedSchoolIds: transmittedIds,
    internshipsTotal: internshipsTotal,
    attestationsTotal: attestationsTotal,
    bacBlocked: bacBlocked,
    yearLabel: yearLabel,
  );
}

// ─── Accumulateurs privés ───────────────────────────────────────────────────

class _Funnel {
  int declared = 0, submitted = 0, admitted = 0;
}

class _AxisAcc {
  _AxisAcc(this.name, this.department);
  final String name;
  final String? department;
  int candidates = 0, known = 0, admitted = 0;
}

class _Counters {
  int candidates = 0, complete = 0, submitted = 0, withResult = 0, admitted = 0;

  void bump(MinistryCandidateRow r) {
    candidates++;
    if (r.isComplete) complete++;
    if (r.isSubmitted) submitted++;
    if (r.hasKnownResult) withResult++;
    if (r.isAdmitted) admitted++;
  }
}

class _ExamAcc extends _Counters {}

class _SchoolAcc extends _Counters {
  _SchoolAcc(this.schoolId, this.schoolName, this.department);
  final String schoolId;
  final String schoolName;
  final String? department;
  int transmissions = 0;
  DateTime? lastTransmittedAt;
  final Map<String, _ExamAcc> byExam = {};

  MinistrySchoolExam build() => MinistrySchoolExam(
        schoolId: schoolId,
        schoolName: schoolName,
        candidates: candidates,
        complete: complete,
        submitted: submitted,
        withResult: withResult,
        admitted: admitted,
        transmissions: transmissions,
        lastTransmittedAt: lastTransmittedAt,
        department: department,
        byExam: (byExam.entries.toList()
              ..sort((x, y) => y.value.candidates.compareTo(x.value.candidates)))
            .map((e) => SchoolExamLine(
                  examShortName: e.key,
                  candidates: e.value.candidates,
                  complete: e.value.complete,
                  submitted: e.value.submitted,
                  withResult: e.value.withResult,
                  admitted: e.value.admitted,
                ))
            .toList(),
      );
}
