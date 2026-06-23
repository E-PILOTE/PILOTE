import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REGISTRE DES ÉLÈVES (la PERSONNE, pas l'inscription). Chaque élève est joint
//  à son inscription de l'ANNÉE ACTIVE (classe + statut) si elle existe — sinon
//  il apparaît « Non inscrit ». Distinct de la page Inscriptions (qui liste les
//  inscriptions de l'année). Offline-first (db.watch).
// ════════════════════════════════════════════════════════════════════════════
class StudentRow {
  const StudentRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.gender,
    required this.dateOfBirth,
    required this.photoUrl,
    required this.isBoarder,
    required this.hasScholarship,
    required this.hasSocialAid,
    required this.isAffecte,
    required this.enrollmentId,
    required this.enrollmentStatus,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.filiereLabel,
  });

  final String id, firstName, lastName, matricule;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final bool isBoarder, hasScholarship, hasSocialAid, isAffecte;

  // Inscription de l'année active (null si non inscrit).
  final String? enrollmentId, enrollmentStatus, classId, className;
  final String? cycleCode, levelCode, filiereLabel;
  final int levelOrder;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  bool get isEnrolled => enrollmentId != null;
  bool get isActiveEnrolled => enrollmentStatus == 'active';

  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 130 ? null : a;
  }
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
bool _b(Object? v) => v == 1 || v == true;

/// Registre complet des élèves de l'école + inscription de l'année active.
final studentsRegistryProvider =
    StreamProvider.autoDispose<List<StudentRow>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);

  return db
      .watch(
        '''
        SELECT s.id, s.first_name, s.last_name, s.matricule, s.gender,
               s.date_of_birth, s.photo_url, s.is_boarder, s.has_scholarship,
               s.has_social_aid, s.is_affecte,
               ce.id            AS enrollment_id,
               ce.status        AS enrollment_status,
               ce.class_id      AS class_id,
               c.name           AS class_name,
               c.cycle_code     AS cycle_code,
               c.level_code     AS level_code,
               c.level_order    AS level_order,
               c.filiere_label  AS filiere_label
        FROM   students s
        LEFT JOIN class_enrollments ce
               ON ce.student_id = s.id AND ce.academic_year_id = ?
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  s.school_id = ? AND s.is_active = 1
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [yearId ?? '', schoolId],
      )
      .map((rows) => [
            for (final r in rows)
              StudentRow(
                id: r['id'] as String,
                firstName: (r['first_name'] as String?) ?? '',
                lastName: (r['last_name'] as String?) ?? '',
                matricule: (r['matricule'] as String?) ?? '',
                gender: r['gender'] as String?,
                dateOfBirth: _d(r['date_of_birth']),
                photoUrl: r['photo_url'] as String?,
                isBoarder: _b(r['is_boarder']),
                hasScholarship: _b(r['has_scholarship']),
                hasSocialAid: _b(r['has_social_aid']),
                isAffecte: _b(r['is_affecte']),
                enrollmentId: r['enrollment_id'] as String?,
                enrollmentStatus: r['enrollment_status'] as String?,
                classId: r['class_id'] as String?,
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                filiereLabel: (r['filiere_label'] as String?)?.trim().isEmpty ?? true
                    ? null
                    : (r['filiere_label'] as String).trim(),
              ),
          ]);
});
