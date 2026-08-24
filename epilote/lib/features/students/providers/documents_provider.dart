import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import 'students_registry_provider.dart';
import 'student_documents_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIERS DOCUMENTAIRES (vue ÉCOLE) — agrège les pièces de `student_documents`
//  pour piloter la CONFORMITÉ : quels élèves ont un dossier complet, quelles
//  pièces sont vérifiées, lesquelles sont expirées. 100% offline (db.watch).
//  Le détail par élève réutilise `studentDocTypes` (catalogue partagé).
// ════════════════════════════════════════════════════════════════════════════

/// Pièces EXIGÉES pour qu'un dossier soit réputé « complet » (sous-ensemble du
/// catalogue `studentDocTypes`). Les autres pièces restent facultatives.
const kRequiredDocTypes = <String>{
  'acte_naissance',
  'photo_identite',
  'certificat_medical',
};

// ─── Ligne de pièce (jointe à l'élève + sa classe de l'année active) ──────────
class DocRow {
  const DocRow({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.className,
    required this.cycleCode,
    required this.levelOrder,
    required this.documentType,
    required this.documentName,
    required this.fileUrl,
    required this.isVerified,
    required this.expiryDate,
    required this.createdAt,
  });

  final String id, studentId, firstName, lastName, matricule;
  final String? className, cycleCode;
  final int levelOrder;
  final String documentType, documentName;
  final String fileUrl;
  final bool isVerified;
  final DateTime? expiryDate;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  String get typeLabel => docTypeLabel(documentType);
  bool get isExpired {
    final e = expiryDate;
    if (e == null) return false;
    return e.isBefore(DateTime.now());
  }
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Toutes les pièces de l'école (jointes à l'élève + sa classe active).
///
/// ── ⚠️ CE PROVIDER PORTE UN PÉRIMÈTRE ──────────────────────────────────────
/// Il alimente DEUX choses que la page présente côte à côte, et qui ne
/// disaient pas la même vérité :
///
///  • la vue « Registre » — une table ÉLÈVE / CLASSE / PIÈCE / DÉPÔT / ÉTAT,
///    avec sa recherche par nom. Elle lisait l'école entière. La vue « Par
///    élève » juste à côté, elle, passe par `studentsRegistryProvider`, donc
///    était correctement restreinte : un enseignant en `own_classes` voyait
///    douze dossiers d'un côté et huit cents lignes de l'autre.
///  • les KPI. « Dossiers complets » comptait le périmètre du membre, « Pièces
///    déposées / Vérifiées / Expirées » comptaient l'établissement : trois
///    cartes sur quatre parlaient d'un autre ensemble que la quatrième, sur la
///    même rangée.
///
/// Les pièces d'un élève sans inscription active de l'année sortent du
/// périmètre restreint — c'est voulu : sans classe, rien ne rattache ce dossier
/// au membre. En `own_school`, aucune clause n'est ajoutée et elles restent.
final schoolDocumentsProvider =
    StreamProvider.autoDispose<List<DocRow>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, 'documents', column: 'ce.class_id');

  return db
      .watch(
        '''
        SELECT d.id, d.student_id, d.document_type, d.document_name,
               d.file_url, d.is_verified, d.expiry_date, d.created_at,
               s.first_name, s.last_name, s.matricule,
               c.name        AS class_name,
               c.cycle_code  AS cycle_code,
               c.level_order AS level_order
        FROM   student_documents d
        JOIN   students s ON s.id = d.student_id
        LEFT JOIN class_enrollments ce
               ON ce.student_id = d.student_id
              AND ce.academic_year_id = ?
              AND ce.status = 'active'
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  d.school_id = ? AND COALESCE(s.is_active, 1) <> 0
        ${scope?.clause ?? ''}
        ORDER  BY s.last_name, s.first_name, d.created_at DESC
        ''',
        parameters: [yearId ?? '', schoolId, ...?scope?.params],
      )
      .map((rows) => [
            for (final r in rows)
              DocRow(
                id: r['id'] as String,
                studentId: r['student_id'] as String,
                firstName: (r['first_name'] as String?) ?? '',
                lastName: (r['last_name'] as String?) ?? '',
                matricule: (r['matricule'] as String?) ?? '',
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                documentType: (r['document_type'] as String?) ?? '',
                documentName: (r['document_name'] as String?) ?? '',
                fileUrl: (r['file_url'] as String?) ?? '',
                isVerified: r['is_verified'] == 1 || r['is_verified'] == true,
                expiryDate: _d(r['expiry_date']),
                createdAt: _d(r['created_at']),
              ),
          ]);
});

/// Pièces d'UN élève en direct (pour le détail du dossier — relit après
/// téléversement / vérification / retrait). Pas de jointure classe (l'en-tête
/// du détail porte déjà l'élève).
final studentDocRowsProvider = StreamProvider.autoDispose
    .family<List<DocRow>, String>((ref, studentId) {
  return db
      .watch(
        '''
        SELECT id, student_id, document_type, document_name, file_url,
               is_verified, expiry_date, created_at
        FROM   student_documents
        WHERE  student_id = ?
        ORDER  BY created_at DESC
        ''',
        parameters: [studentId],
      )
      .map((rows) => [
            for (final r in rows)
              DocRow(
                id: r['id'] as String,
                studentId: r['student_id'] as String,
                firstName: '',
                lastName: '',
                matricule: '',
                className: null,
                cycleCode: null,
                levelOrder: 999,
                documentType: (r['document_type'] as String?) ?? '',
                documentName: (r['document_name'] as String?) ?? '',
                fileUrl: (r['file_url'] as String?) ?? '',
                isVerified: r['is_verified'] == 1 || r['is_verified'] == true,
                expiryDate: _d(r['expiry_date']),
                createdAt: _d(r['created_at']),
              ),
          ]);
});

// ─── Dossier par élève (élève actif + pièces + état de conformité) ────────────
class StudentDossier {
  StudentDossier({required this.student, required this.docs});
  final StudentRow student;
  final List<DocRow> docs;

  /// Types de pièces présents (au moins une pièce du type).
  Set<String> get presentTypes => {for (final d in docs) d.documentType};
  Set<String> get missingRequired =>
      kRequiredDocTypes.difference(presentTypes);
  bool get isComplete => missingRequired.isEmpty;
  int get verifiedCount => docs.where((d) => d.isVerified).length;
  int get expiredCount => docs.where((d) => d.isExpired).length;
  int get requiredPresent =>
      kRequiredDocTypes.intersection(presentTypes).length;
}

/// Dossiers de tous les élèves ACTIFS (même ceux sans aucune pièce → incomplets).
final studentDossiersProvider =
    Provider.autoDispose<AsyncValue<List<StudentDossier>>>((ref) {
  final roster = ref.watch(studentsRegistryProvider('documents'));
  final docs = ref.watch(schoolDocumentsProvider);
  return roster.whenData((students) {
    final byStudent = <String, List<DocRow>>{};
    for (final d in docs.valueOrNull ?? const <DocRow>[]) {
      byStudent.putIfAbsent(d.studentId, () => []).add(d);
    }
    return [
      for (final s in students)
        StudentDossier(student: s, docs: byStudent[s.id] ?? const []),
    ];
  });
});

// ─── Statistiques de conformité (KPIs) ───────────────────────────────────────
class DocStats {
  const DocStats({
    required this.totalDocs,
    required this.verified,
    required this.completeFolders,
    required this.totalFolders,
    required this.expired,
  });
  final int totalDocs, verified, completeFolders, totalFolders, expired;
}

final docStatsProvider = Provider.autoDispose<DocStats>((ref) {
  final docs = ref.watch(schoolDocumentsProvider).valueOrNull ?? const [];
  final dossiers =
      ref.watch(studentDossiersProvider).valueOrNull ?? const [];
  return DocStats(
    totalDocs: docs.length,
    verified: docs.where((d) => d.isVerified).length,
    expired: docs.where((d) => d.isExpired).length,
    completeFolders: dossiers.where((d) => d.isComplete).length,
    totalFolders: dossiers.length,
  );
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
/// Vérifie / dé-vérifie une pièce du dossier (cachet de l'administration).
Future<void> setDocumentVerified({
  required String id,
  required bool verified,
  String? verifiedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE student_documents
    SET is_verified = ?, verified_by = ?, verified_at = ?, updated_at = ?
    WHERE id = ?
    ''',
    [verified ? 1 : 0, verified ? verifiedBy : null, verified ? now : null,
     now, id],
  );
}

/// Renseigne / efface la date d'expiration d'une pièce.
Future<void> setDocumentExpiry({
  required String id,
  required DateTime? expiry,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE student_documents SET expiry_date = ?, updated_at = ? WHERE id = ?',
    [expiry?.toIso8601String().substring(0, 10), now, id],
  );
}

/// Retire une pièce du dossier (la ligne ; le fichier Storage reste orphelin).
Future<void> deleteStudentDocument(String id) async {
  await db.execute('DELETE FROM student_documents WHERE id = ?', [id]);
}
