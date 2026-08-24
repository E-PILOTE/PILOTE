import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/exam_dossier_piece.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  INSCRIPTION AUX EXAMENS — écritures offline (db.execute).
//
//  ── PIÈGE N°1 : LA PERTE SILENCIEUSE ────────────────────────────────────────
//  `exam_candidates` porte UNIQUE(session_id, student_id) CÔTÉ SERVEUR. SQLite
//  local ne l'applique pas : un doublon inséré hors ligne partirait à l'upload,
//  serait rejeté par Postgres, et la transaction PowerSync serait abandonnée —
//  emportant AUSSI les inscriptions valides du même lot. D'où le contrôle
//  anti-doublon LOCAL avant insertion (fiable : les candidatures de l'école
//  sont intégralement synchronisées par by_school).
//
//  ── PIÈGE N°2 : L'ÂGE NE DOIT JAMAIS BLOQUER ────────────────────────────────
//  max_age est RÉGLEMENTAIRE (24 bacs / 20 BET-CAP / 21 autres brevets) mais des
//  dérogations existent, et la date d'appréciation exacte n'est pas établie. Le
//  contrôle est donc CONSULTATIF : on avertit, on n'interdit pas. Un refus
//  serveur sur l'âge provoquerait exactement la perte silencieuse du piège n°1.
// ════════════════════════════════════════════════════════════════════════════

/// Élève d'une classe d'examen, vu depuis l'inscription.
class ExamStudentRow {
  const ExamStudentRow({
    required this.studentId,
    required this.fullName,
    required this.matricule,
    required this.dateOfBirth,
    required this.candidateId,
    required this.dossierStatus,
    required this.candidateNumber,
  });

  final String studentId;
  final String fullName;
  final String? matricule;
  final DateTime? dateOfBirth;

  /// Non null = déjà inscrit à la session.
  final String? candidateId;
  final String? dossierStatus;
  final String? candidateNumber;

  bool get isRegistered => candidateId != null;

  /// Âge à la date d'appréciation de la session (miroir de `exam_age_at_session`).
  /// Consultatif : sert à AVERTIR, jamais à interdire.
  int? ageAt(DateTime? reference) {
    if (dateOfBirth == null || reference == null) return null;
    var age = reference.year - dateOfBirth!.year;
    final hadBirthday = reference.month > dateOfBirth!.month ||
        (reference.month == dateOfBirth!.month && reference.day >= dateOfBirth!.day);
    if (!hadBirthday) age--;
    return age;
  }
}

/// Session retenue pour un examen + les élèves de la classe.
class ClassRegistration {
  const ClassRegistration({
    required this.sessionId,
    required this.examShortName,
    required this.yearLabel,
    required this.maxAge,
    required this.ageReference,
    required this.registrationClosesAt,
    required this.requiredDocuments,
    required this.students,
  });

  final String? sessionId;
  final String examShortName;
  final String? yearLabel;
  final int? maxAge;
  final DateTime? ageReference;
  final DateTime? registrationClosesAt;
  final List<Map<String, dynamic>> requiredDocuments;
  final List<ExamStudentRow> students;

  bool get hasSession => sessionId != null;

  List<ExamStudentRow> get pending =>
      students.where((s) => !s.isRegistered).toList();

  List<ExamStudentRow> get registered =>
      students.where((s) => s.isRegistered).toList();

  /// Élèves dépassant l'âge réglementaire — signalés, jamais exclus.
  List<ExamStudentRow> get overAge {
    if (maxAge == null) return const [];
    return students.where((s) {
      final a = s.ageAt(ageReference);
      return a != null && a > maxAge!;
    }).toList();
  }
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// Élèves d'une classe + leur état d'inscription à la session de son examen.
final classRegistrationProvider = FutureProvider.autoDispose
    .family<ClassRegistration, String>((ref, classId) async {
  ref.keepAlive();

  // Session à viser : celle de l'examen de la classe. On privilégie une session
  // dont la fenêtre d'inscription est ouverte ; sinon la plus récente.
  final sessionRows = await db.getAll(
    'SELECT s.id, s.year_label, s.max_age, s.age_reference_date, s.written_from, '
    '       s.registration_closes_at, s.required_documents, s.status, e.short_name '
    '  FROM classes c '
    '  JOIN national_exams e ON e.id = COALESCE(c.exam_override_id, c.exam_id) '
    '  JOIN exam_sessions s ON s.exam_id = e.id '
    ' WHERE c.id = ? AND s.status <> ? '
    ' ORDER BY CASE WHEN s.status = ? THEN 0 ELSE 1 END, s.registration_closes_at DESC',
    [classId, 'cancelled', 'open'],
  );

  final s = sessionRows.isEmpty ? null : sessionRows.first;
  final sessionId = s?['id'] as String?;

  final studentRows = await db.getAll(
    'SELECT st.id, st.first_name, st.last_name, st.matricule, st.date_of_birth, '
    '       ec.id AS cand_id, ec.dossier_status, ec.candidate_number '
    '  FROM class_enrollments ce '
    '  JOIN students st ON st.id = ce.student_id '
    '  LEFT JOIN exam_candidates ec '
    '    ON ec.student_id = st.id AND ec.session_id = ? '
    ' WHERE ce.class_id = ? AND ce.status = ? '
    ' AND COALESCE(st.is_active, 1) <> 0 '
    ' ORDER BY st.last_name, st.first_name',
    [sessionId, classId, 'active'],
  );

  List<Map<String, dynamic>> docs = const [];
  final raw = s?['required_documents'];
  if (raw is String && raw.isNotEmpty) {
    try {
      docs = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      docs = const []; // jsonb illisible : on n'empêche pas d'inscrire.
    }
  }

  return ClassRegistration(
    sessionId: sessionId,
    examShortName: (s?['short_name'] as String?) ?? '—',
    yearLabel: s?['year_label'] as String?,
    maxAge: s?['max_age'] as int?,
    ageReference: _date(s?['age_reference_date']) ?? _date(s?['written_from']),
    registrationClosesAt: _date(s?['registration_closes_at']),
    requiredDocuments: docs,
    students: [
      for (final r in studentRows)
        ExamStudentRow(
          studentId: r['id'] as String,
          fullName: '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
          matricule: r['matricule'] as String?,
          dateOfBirth: _date(r['date_of_birth']),
          candidateId: r['cand_id'] as String?,
          dossierStatus: r['dossier_status'] as String?,
          candidateNumber: r['candidate_number'] as String?,
        ),
    ],
  );
});

/// Inscrit des élèves à une session. Retourne le nombre réellement inscrit.
///
/// Anti-doublon LOCAL obligatoire (cf. piège n°1) : on relit les candidatures
/// existantes juste avant d'écrire, et on ignore silencieusement les élèves déjà
/// inscrits plutôt que de laisser Postgres rejeter tout le lot.
Future<int> registerCandidates(
  WidgetRef ref, {
  required String sessionId,
  required String classId,
  required List<String> studentIds,
}) async {
  if (studentIds.isEmpty) return 0;

  final profile = ref.read(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  final schoolId = profile?.schoolId;
  if (groupId == null || schoolId == null) return 0;

  final author = ref.read(activeAgentIdProvider);

  final ph = List.filled(studentIds.length, '?').join(',');
  final existing = await db.getAll(
    'SELECT student_id FROM exam_candidates '
    ' WHERE session_id = ? AND student_id IN ($ph)',
    [sessionId, ...studentIds],
  );
  final already = {for (final r in existing) r['student_id'] as String};

  final session = await db.getAll(
    'SELECT required_documents FROM exam_sessions WHERE id = ?', [sessionId]);
  final required = ExamDossierPiece.parseList(
      session.isEmpty ? null : session.first['required_documents']);

  // Le dossier naît avec les pièces INCONDITIONNELLES pour dues. Les pièces
  // conditionnelles (certificat médical d'inaptitude EPS…) en sont exclues :
  // les inclure rendrait TOUT dossier de bac éternellement incomplet, puisque
  // rien ne nous dit qui est inapte. L'école les ajoute au cas par cas.
  final docs =
      ExamDossierPiece.encodeList(required.where((p) => !p.isConditional));

  final now = DateTime.now().toIso8601String();
  var count = 0;

  for (final sid in studentIds) {
    if (already.contains(sid)) continue;
    await db.execute(
      'INSERT INTO exam_candidates ('
      ' id, session_id, student_id, group_id, school_id, class_id,'
      ' dossier_status, missing_documents, is_repeater, registered_at,'
      ' result, created_by, created_at, updated_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        _uuid.v4(), sessionId, sid, groupId, schoolId, classId,
        // Le dossier naît INCOMPLET : toutes les pièces requises sont dues.
        'incomplet', docs, 0, now,
        'en_attente', author, now, now,
      ],
    );
    count++;
  }
  return count;
}

/// Retire une candidature (erreur de saisie). Ne touche pas à l'élève.
Future<void> unregisterCandidate(String candidateId) =>
    db.execute('DELETE FROM exam_candidates WHERE id = ?', [candidateId]);

/// Met à jour les pièces manquantes d'un dossier et en dérive le statut.
/// Aucune pièce manquante -> `complet` ; sinon `incomplet`. Le passage à
/// `depose`/`valide` est une décision humaine (voir [submitDossier]).
Future<void> updateDossier(
  String candidateId, {
  required List<Map<String, dynamic>> missing,
}) async {
  await db.execute(
    'UPDATE exam_candidates SET missing_documents = ?, dossier_status = ?, '
    ' updated_at = ? WHERE id = ?',
    [
      jsonEncode(missing),
      missing.isEmpty ? 'complet' : 'incomplet',
      DateTime.now().toIso8601String(),
      candidateId,
    ],
  );
}

/// Dépôt officiel du dossier (acte du chef d'établissement).
Future<void> submitDossier(String candidateId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE exam_candidates SET dossier_status = ?, submitted_at = ?, '
    ' updated_at = ? WHERE id = ?',
    ['depose', now, now, candidateId],
  );
}

/// Enregistre un résultat REÇU de la DEC. `average`/`mention` restent
/// facultatifs : un « absent » ou une « fraude » n'a pas de moyenne.
///
/// ── DEUX HORLOGES, NE JAMAIS LES CONFONDRE (migration 0053) ────────────────
/// `decidedAt`  = date de PROCLAMATION par la DEC. NULL si l'école l'ignore.
/// `receivedAt` = date de RÉCEPTION chez nous — posée ici, automatiquement.
///
/// La version précédente écrivait `decided_at = now()` : elle datait la
/// proclamation officielle du jour de la frappe. Une date fausse, opposable à
/// la DEC un jour. Un résultat n'est pas produit par nous, il nous arrive.
Future<void> setResult(
  String candidateId, {
  required String result,
  double? average,
  String? mention,
  DateTime? decidedAt,
  String source = 'saisie_manuelle',
  String? recordedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE exam_candidates SET result = ?, average = ?, mention = ?, '
    ' decided_at = ?, result_received_at = ?, result_source = ?, '
    ' result_recorded_by = ?, updated_at = ? WHERE id = ?',
    [
      result,
      average,
      mention,
      decidedAt?.toIso8601String(),
      now,
      source,
      recordedBy,
      now,
      candidateId,
    ],
  );
}

/// Efface un résultat saisi par erreur — et TOUTE sa provenance avec lui.
/// Laisser une source ou une date de réception derrière un résultat effacé
/// laisserait croire que la DEC a dit quelque chose. Elle n'a rien dit.
Future<void> clearResult(String candidateId) async {
  await db.execute(
    'UPDATE exam_candidates SET result = ?, average = NULL, mention = NULL, '
    ' decided_at = NULL, result_received_at = NULL, result_source = NULL, '
    ' result_recorded_by = NULL, updated_at = ? WHERE id = ?',
    ['en_attente', DateTime.now().toIso8601String(), candidateId],
  );
}

// ─── Attribution en masse des numéros de candidat ────────────────────────────

/// Attribue les numéros de candidat communiqués par la DEC.
///
/// La correspondance est POSITIONNELLE : le n-ième numéro va au n-ième
/// candidat de la liste affichée. C'est ainsi que la DEC transmet ses listes
/// (un tableur dans l'ordre alphabétique) ; toute autre règle obligerait à
/// ressaisir. Les numéros vides sont ignorés — ils n'effacent pas un numéro
/// déjà attribué, car une ligne blanche dans un collage est une distraction,
/// pas une décision.
Future<int> assignCandidateNumbers(Map<String, String> numbersByCandidateId) async {
  final entries = numbersByCandidateId.entries
      .where((e) => e.value.trim().isNotEmpty)
      .toList();
  if (entries.isEmpty) return 0;

  final now = DateTime.now().toIso8601String();
  await db.writeTransaction((tx) async {
    for (final e in entries) {
      await tx.execute(
        'UPDATE exam_candidates SET candidate_number = ?, updated_at = ? '
        'WHERE id = ?',
        [e.value.trim(), now, e.key],
      );
    }
  });
  return entries.length;
}
