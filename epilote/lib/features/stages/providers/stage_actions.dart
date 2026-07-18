import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/stage_detail.dart';

const _uuid = Uuid();

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — les écritures. Le module était en LECTURE SEULE.
//
//  Il affichait fièrement « dossiers bloqués faute d'attestation » et n'offrait
//  aucun moyen d'en délivrer une : il signalait un problème qu'il rendait
//  impossible à résoudre.
//
//  ── CE QUE PRODUIT CE MODULE, ET POURQUOI C'EST SÉRIEUX ────────────────────
//  L'attestation de fin de stage est une PIÈCE DU DOSSIER DU BACCALAURÉAT
//  (note officielle METP). Ce n'est pas un module de confort : sans attestation,
//  l'élève ne s'inscrit pas au bac. Un clic ici vaut une année.
//
//  ── PIÈGE : LA PERTE SILENCIEUSE ───────────────────────────────────────────
//  SQLite local n'applique NI les NOT NULL serveur NI les FK. Une écriture
//  incomplète part à l'upload, Postgres la rejette, et PowerSync ABANDONNE la
//  transaction — emportant au passage le travail valide du même lot. D'où :
//   • `group_id`, `school_id`, `student_id`, `status` toujours renseignés ;
//   • `id`, `created_at`, `updated_at` posés à la main (les DEFAULT serveur —
//     gen_random_uuid(), now() — ne s'appliquent PAS à un insert local) ;
//   • aucune contrainte inventée côté client : on ne bloque pas, on signale.
// ════════════════════════════════════════════════════════════════════════════

/// Identité du tenant + auteur. `null` si la session n'est pas exploitable :
/// mieux vaut ne rien écrire qu'écrire une ligne orpheline.
({String groupId, String schoolId, String? author})? _context(WidgetRef ref) {
  final p = ref.read(authNotifierProvider).valueOrNull;
  final g = p?.groupId;
  final s = p?.schoolId;
  if (g == null || s == null) return null;
  return (groupId: g, schoolId: s, author: ref.read(activeAgentIdProvider));
}

String _now() => DateTime.now().toIso8601String();

/// `2026-03-01` — les colonnes `date` de Postgres n'acceptent pas un ISO complet.
String? _day(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

// ── Entreprises ─────────────────────────────────────────────────────────────

class CompanyRow {
  const CompanyRow({
    required this.id,
    required this.name,
    required this.sector,
    required this.isShared,
  });

  final String id;
  final String name;
  final String? sector;

  /// `school_id IS NULL` = entreprise partagée par tout le groupe. Les écoles
  /// d'un même groupe envoient souvent leurs élèves chez les mêmes employeurs :
  /// re-saisir « SOTEC » dans chaque école produirait des doublons impossibles
  /// à recouper ensuite.
  final bool isShared;
}

final companiesProvider = FutureProvider.autoDispose<List<CompanyRow>>((ref) async {
  final rows = await db.getAll(
    'SELECT id, name, sector, school_id FROM internship_companies '
    ' WHERE is_active = 1 ORDER BY name',
  );
  return [
    for (final r in rows)
      CompanyRow(
        id: r['id'] as String,
        name: r['name'] as String,
        sector: r['sector'] as String?,
        isShared: r['school_id'] == null,
      ),
  ];
});

/// Crée une entreprise. `shared` = visible par tout le groupe.
Future<String?> createCompany(
  WidgetRef ref, {
  required String name,
  String? sector,
  String? address,
  String? contactName,
  String? contactPhone,
  bool shared = false,
}) async {
  final ctx = _context(ref);
  if (ctx == null) return null;

  final id = _uuid.v4();
  final now = _now();
  await db.execute(
    'INSERT INTO internship_companies '
    ' (id, group_id, school_id, name, sector, address, contact_name, '
    '  contact_phone, is_active, created_by, created_at, updated_at) '
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)',
    [
      id,
      ctx.groupId,
      shared ? null : ctx.schoolId,
      name.trim(),
      sector?.trim(),
      address?.trim(),
      contactName?.trim(),
      contactPhone?.trim(),
      ctx.author,
      now,
      now,
    ],
  );
  return id;
}

// ── Stages ──────────────────────────────────────────────────────────────────

/// Crée un stage. Le statut initial se DÉDUIT des dates plutôt que d'être
/// demandé : un agent qui saisit un stage passé n'a aucune raison de cocher
/// « terminé » à la main — et l'oublierait.
Future<String?> createInternship(
  WidgetRef ref, {
  required String studentId,
  String? classId,
  String? companyId,
  String? academicYearId,
  String? title,
  DateTime? startDate,
  DateTime? endDate,
  String? schoolTutorId,
  String? companyTutorName,
  String? companyTutorPhone,
  DateTime? conventionSignedAt,
  String? notes,
}) async {
  final ctx = _context(ref);
  if (ctx == null) return null;

  final id = _uuid.v4();
  final now = _now();
  await db.execute(
    'INSERT INTO internships '
    ' (id, group_id, school_id, student_id, class_id, academic_year_id, '
    '  company_id, title, start_date, end_date, school_tutor_id, '
    '  company_tutor_name, company_tutor_phone, convention_signed_at, '
    '  status, notes, created_by, created_at, updated_at) '
    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      ctx.groupId,
      ctx.schoolId,
      studentId,
      classId,
      academicYearId,
      companyId,
      title?.trim(),
      _day(startDate),
      _day(endDate),
      schoolTutorId,
      companyTutorName?.trim(),
      companyTutorPhone?.trim(),
      _day(conventionSignedAt),
      statusFromDates(startDate, endDate),
      notes?.trim(),
      ctx.author,
      now,
      now,
    ],
  );
  return id;
}

Future<void> updateInternship(
  String internshipId, {
  String? companyId,
  String? title,
  DateTime? startDate,
  DateTime? endDate,
  String? companyTutorName,
  String? companyTutorPhone,
  DateTime? conventionSignedAt,
  String? status,
  String? notes,
}) async {
  await db.execute(
    'UPDATE internships SET company_id = ?, title = ?, start_date = ?, '
    ' end_date = ?, company_tutor_name = ?, company_tutor_phone = ?, '
    ' convention_signed_at = ?, status = ?, notes = ?, updated_at = ? '
    ' WHERE id = ?',
    [
      companyId,
      title?.trim(),
      _day(startDate),
      _day(endDate),
      companyTutorName?.trim(),
      companyTutorPhone?.trim(),
      _day(conventionSignedAt),
      status ?? statusFromDates(startDate, endDate),
      notes?.trim(),
      _now(),
      internshipId,
    ],
  );
}

Future<void> deleteInternship(String internshipId) =>
    db.execute('DELETE FROM internships WHERE id = ?', [internshipId]);

/// Note d'évaluation du stage — attribuée par le tuteur d'entreprise, saisie
/// par l'école. Elle ne conditionne PAS l'attestation : un stage peut être
/// attesté sans être noté (le tuteur ne rend pas toujours sa fiche), et refuser
/// l'attestation pour ça coûterait le bac à l'élève.
Future<void> setInternshipEvaluation(
  String internshipId, {
  double? grade,
  String? comment,
}) =>
    db.execute(
      'UPDATE internships SET evaluation_grade = ?, evaluation_comment = ?, '
      ' updated_at = ? WHERE id = ?',
      [grade, comment?.trim(), _now(), internshipId],
    );

/// Délivre l'attestation de fin de stage — LA pièce du dossier de bac.
///
/// Passe aussi le stage à `valide` : une attestation délivrée sur un stage
/// encore « prévu » serait incohérente, et c'est l'incohérence que la DEC
/// verrait au comptoir.
Future<void> issueAttestation(
  String internshipId, {
  DateTime? issuedAt,
  String? url,
}) =>
    db.execute(
      'UPDATE internships SET attestation_issued_at = ?, attestation_url = ?, '
      ' status = ?, updated_at = ? WHERE id = ?',
      [
        _day(issuedAt ?? DateTime.now()),
        url,
        'valide',
        _now(),
        internshipId,
      ],
    );

/// Retire une attestation délivrée par erreur. Le stage redescend à `termine` :
/// le travail a bien eu lieu, seule la pièce est annulée.
Future<void> revokeAttestation(String internshipId) => db.execute(
      'UPDATE internships SET attestation_issued_at = NULL, '
      ' attestation_url = NULL, status = ?, updated_at = ? WHERE id = ?',
      ['termine', _now(), internshipId],
    );

/// Statut déduit des dates — jamais demandé à l'agent.
/// Sans date de fin, un stage commencé reste « en cours » : on ne peut pas
/// inventer qu'il est terminé.
String statusFromDates(DateTime? start, DateTime? end) {
  final today = DateTime.now();
  final d = DateTime(today.year, today.month, today.day);
  if (start == null) return 'prevu';
  if (start.isAfter(d)) return 'prevu';
  if (end != null && end.isBefore(d)) return 'termine';
  return 'en_cours';
}

/// Charge le détail COMPLET d'un stage (élève, entreprise, tuteurs, évaluation)
/// pour générer les documents officiels. Lecture offline pure (db.getAll).
Future<StageDetail?> fetchStageDetail(String internshipId) async {
  final rows = await db.getAll(
    'SELECT i.id, i.title, i.start_date, i.end_date, i.status, '
    '       i.company_tutor_name, i.company_tutor_phone, '
    '       i.convention_signed_at, i.attestation_issued_at, '
    '       i.evaluation_grade, i.evaluation_comment, '
    '       s.first_name, s.last_name, s.matricule, s.date_of_birth, s.gender, '
    '       c.name AS class_name, c.filiere_label, '
    '       co.name AS company_name, co.sector, co.address, co.city, '
    '       co.contact_name AS company_contact, '
    '       tut.first_name AS tutor_first, tut.last_name AS tutor_last '
    '  FROM internships i '
    '  LEFT JOIN students s ON s.id = i.student_id '
    '  LEFT JOIN classes c ON c.id = i.class_id '
    '  LEFT JOIN internship_companies co ON co.id = i.company_id '
    '  LEFT JOIN profiles tut ON tut.id = i.school_tutor_id '
    ' WHERE i.id = ? LIMIT 1',
    [internshipId],
  );
  if (rows.isEmpty) return null;
  final r = rows.first;

  String? nz(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  final tutor = '${r['tutor_first'] ?? ''} ${r['tutor_last'] ?? ''}'.trim();

  return StageDetail(
    id: r['id'] as String,
    studentName: '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
    matricule: nz(r['matricule']),
    dateOfBirth: _date(r['date_of_birth']),
    gender: nz(r['gender']),
    className: nz(r['class_name']),
    filiereLabel: nz(r['filiere_label']),
    companyName: nz(r['company_name']),
    companySector: nz(r['sector']),
    companyAddress: nz(r['address']),
    companyCity: nz(r['city']),
    companyContact: nz(r['company_contact']),
    companyTutorName: nz(r['company_tutor_name']),
    companyTutorPhone: nz(r['company_tutor_phone']),
    schoolTutorName: tutor.isEmpty ? null : tutor,
    title: nz(r['title']),
    startDate: _date(r['start_date']),
    endDate: _date(r['end_date']),
    status: r['status'] as String? ?? 'prevu',
    conventionSignedAt: _date(r['convention_signed_at']),
    attestationIssuedAt: _date(r['attestation_issued_at']),
    evaluationGrade: (r['evaluation_grade'] as num?)?.toDouble(),
    evaluationComment: nz(r['evaluation_comment']),
  );
}
