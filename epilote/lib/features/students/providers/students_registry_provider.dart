import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REGISTRE DES ÉLÈVES (la PERSONNE, pas l'inscription) — l'effectif ACTIF de
//  l'année en cours : chaque élève est joint à son inscription active, avec sa
//  classe. Un dossier « en attente de validation », retiré ou transféré n'y
//  figure pas ; il vit dans la page Inscriptions. Offline-first (db.watch).
//
//  ── ⚠️ CE PROVIDER PORTE UN PÉRIMÈTRE ──────────────────────────────────────
//  Il alimente TROIS pages — Élèves, Dossiers documentaires et surtout
//  l'Annuaire des familles (noms, téléphones, adresses des tuteurs). Il n'avait
//  aucun filtre : un enseignant dont le profil d'accès dit `own_classes` y
//  voyait l'école entière, coordonnées des parents comprises, alors que la même
//  restriction était correctement appliquée par `studentsProvider`. Le verrou
//  n'était pas contourné — il n'avait jamais été posé ici.
//
//  D'où le paramètre : le périmètre se règle PAR MODULE (`eleves`, `documents`,
//  `annuaire` sont trois entrées distinctes du profil d'accès), donc l'appelant
//  déclare sous quel module il lit. Passer le mauvais slug, c'est appliquer les
//  droits d'une autre page.
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

/// Effectif actif de l'école pour le module [slug] (`eleves`, `documents`,
/// `annuaire`), restreint aux classes du membre si son profil dit
/// `own_classes`.
final studentsRegistryProvider =
    StreamProvider.autoDispose.family<List<StudentRow>, String>((ref, slug) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  // Tant que le profil d'accès n'est pas lu, on ne PUBLIE rien : la page garde
  // son squelette de chargement. Émettre une liste vide afficherait « aucun
  // élève » à une école qui en a huit cents ; émettre la liste complète
  // montrerait à un enseignant restreint ce qu'il n'a pas à voir.
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, slug, column: 'ce.class_id');

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
        JOIN   class_enrollments ce
               ON ce.student_id = s.id
              AND ce.academic_year_id = ?
              AND ce.status = 'active'
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  s.school_id = ? AND s.is_active = 1
        ${scope?.clause ?? ''}
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [yearId ?? '', schoolId, ...?scope?.params],
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

// ─── Évolution de l'effectif (cumul mensuel des inscriptions actives) ────────
class EffectifPoint {
  const EffectifPoint(this.label, this.count, this.cumul);
  final String label;
  final int count, cumul;
}

const _frMonthsShort = [
  'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
  'juil', 'août', 'sept', 'oct', 'nov', 'déc'
];

/// Croissance de l'effectif : nb d'élèves entrés par mois (selon enrollment_date
/// des inscriptions ACTIVES de l'année) + effectif cumulé. Offline-first.
final effectifEvolutionProvider =
    StreamProvider.autoDispose<List<EffectifPoint>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT substr(ce.enrollment_date, 1, 7) AS ym, COUNT(*) AS n
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.academic_year_id = ?
          AND  ce.status = 'active'
          AND  s.school_id = ?
          AND  ce.enrollment_date IS NOT NULL
          AND  ce.enrollment_date != ''
        GROUP  BY ym
        ORDER  BY ym
        ''',
        parameters: [yearId ?? '', schoolId],
      )
      .map((rows) {
        var cumul = 0;
        final out = <EffectifPoint>[];
        for (final r in rows) {
          final ym = (r['ym'] as String?) ?? '';
          final n = (r['n'] as int?) ?? 0;
          cumul += n;
          final parts = ym.split('-');
          final label = parts.length == 2
              ? '${_frMonthsShort[(int.tryParse(parts[1]) ?? 1) - 1]} '
                  '${parts[0].substring(2)}'
              : ym;
          out.add(EffectifPoint(label, n, cumul));
        }
        return out;
      });
});

// ─── Export CSV de l'effectif ────────────────────────────────────────────────
String _csv(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

/// Écrit l'effectif (filtré) en CSV (séparateur `;`, BOM UTF-8 pour Excel FR)
/// dans le dossier Documents de l'appareil. Retourne le chemin.
Future<String> exportStudentsCsv(List<StudentRow> rows) async {
  final b = StringBuffer();
  b.writeln(['Matricule', 'Nom', 'Prénom', 'Sexe', 'Âge', 'Classe', 'Niveau',
    'Filière', 'Interne', 'Boursier']
      .map(_csv)
      .join(';'));
  for (final r in rows) {
    b.writeln([
      r.matricule, r.lastName, r.firstName,
      r.gender ?? '', r.age?.toString() ?? '', r.className ?? '',
      r.levelCode ?? '', r.filiereLabel ?? '',
      r.isBoarder ? 'Oui' : 'Non',
      (r.hasScholarship || r.hasSocialAid) ? 'Oui' : 'Non',
    ].map(_csv).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/eleves_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
