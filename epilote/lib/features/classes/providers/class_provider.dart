import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/class_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Verrou 4 : périmètre de données (own_school vs own_classes) ──────────────
//
// ⚠️ CE FICHIER RECALCULAIT LE PÉRIMÈTRE LUI-MÊME, ET IL LUI MANQUAIT UN GARDE.
//
// Il portait un `_scopeRestriction` privé, copie du helper canonique
// `classScopeClause` (navigation/providers/permissions_provider.dart) — mais
// figée AVANT que celui-ci ne soit durci. Il lui manquait la seule ligne qui
// compte :
//
//     if (!permissionsLoaded(ref)) return (clause: 'AND 0 = 1', ...);
//
// `modulePermissionProvider` rend `null` dans DEUX cas que rien ne distingue :
// « ce module n'est pas accordé » et « le profil d'accès n'est pas encore lu ».
// Le doublon traitait les deux comme « aucune restriction ». Résultat : à chaque
// démarrage, le temps que le profil se charge, un enseignant en `own_classes`
// voyait TOUTES les classes de l'école et TOUS les effectifs. Pas un cas limite
// — le chemin normal, à chaque ouverture de l'application.
//
// Les quatre requêtes ci-dessous passent désormais par le helper canonique, qui
// traite « je ne sais pas » comme « restreint ». C'était le seul fichier du
// dépôt à refaire ce calcul dans son coin ; il n'y en a plus.
//
// ⚠️ Ne jamais réintroduire de variante locale : c'est cette copie qui a fait
// passer inaperçu le fait que Finance n'appliquait aucun périmètre propre.

// ─── Liste des classes ────────────────────────────────────────────────────────

/// Classes actives de l'école, avec le nombre d'élèves inscrits (actifs).
/// Utilise un JOIN SQLite local — fonctionne 100% hors-ligne.
/// Les classes visibles **dans le périmètre du module [slug]**.
///
/// ── POURQUOI CE PARAMÈTRE EXISTE ──────────────────────────────────────────
/// Il n'y avait qu'un `classesProvider`, verrouillé sur le module `classes`.
/// Tout écran qui s'en servait héritait donc du périmètre d'un AUTRE module que
/// le sien. Finance en vivait entièrement : le `data_scope` de
/// `paiements-eleves` n'était lu nulle part, et le restreindre depuis
/// l'interface d'administration ne produisait aucun effet — un cadenas qui
/// annonce s'être fermé.
///
/// Le risque n'était pas que théorique, et il allait dans les deux sens. Donner
/// un jour `classes = own_classes` à un comptable — geste anodin, pour limiter
/// les listes qu'il parcourt — aurait rétréci son état de recouvrement EN
/// SILENCE : « tout le monde a payé », parce que la moitié des classes avait
/// disparu du calcul.
///
/// Chaque écran demande donc le périmètre de SON module, et d'aucun autre.
final classesForModuleProvider =
    StreamProvider.autoDispose.family<List<ClassModel>, String>((ref, slug) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value([]);
  }

  final scope = classScopeClause(ref, slug, column: 'c.id');
  final scopeClause = scope?.clause ?? '';
  final scopeIds = scope?.params;

  return db
      .watch(
        '''
        SELECT c.*,
               COALESCE(ec.cnt, 0) AS student_count
        FROM   classes c
        LEFT JOIN (
          -- ⚠️ `status = 'active'` ne suffit PAS. `deactivateStudent` retire
          -- l'élève du registre (`students.is_active = 0`) SANS toucher au
          -- statut de son inscription — à dessein : une sortie de classe exige
          -- un motif normalisé (déperdition scolaire), qu'une désactivation
          -- administrative n'a pas. Sans ce second filtre, l'élève disparaît de
          -- la liste Élèves mais continue d'occuper une place ici, et l'écran
          -- Classes annonce un effectif que la liste ne montre plus.
          SELECT ce.class_id, COUNT(*) AS cnt
          FROM   class_enrollments ce
          JOIN   students s ON s.id = ce.student_id
          WHERE  ce.status = 'active' AND COALESCE(s.is_active, 1) <> 0
          GROUP  BY ce.class_id
        ) ec ON ec.class_id = c.id
        WHERE  c.school_id = ?
        AND    c.academic_year_id = ?
        AND    COALESCE(c.is_active, 1) <> 0
        $scopeClause
        ORDER  BY c.name
        ''',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.map(ClassModel.fromMap).toList());
});

/// Les classes de l'écran **Classes**. Raccourci historique, conservé pour les
/// dizaines d'appelants qui parlent bien du module `classes`.
///
/// ⚠️ Ne pas l'utiliser depuis un autre module : passer par
/// [classesForModuleProvider] avec le slug de CET écran, sans quoi le périmètre
/// appliqué sera celui du module `classes`.
/// Simple relais : il rend l'`AsyncValue` de la famille, sans requête de plus.
/// Les 23 appelants continuent de faire `.valueOrNull`, `.when(...)`, comme
/// avant — aucun ne réclamait l'API d'un `StreamProvider`, vérifié.
final classesProvider = Provider.autoDispose<AsyncValue<List<ClassModel>>>(
    (ref) => ref.watch(classesForModuleProvider('classes')));

// ─── Classe par ID ────────────────────────────────────────────────────────────

final classByIdProvider =
    StreamProvider.autoDispose.family<ClassModel?, String>((ref, classId) {
  return db
      .watch(
        '''
        SELECT c.*,
               COALESCE(ec.cnt, 0) AS student_count
        FROM   classes c
        LEFT JOIN (
          -- ⚠️ `status = 'active'` ne suffit PAS. `deactivateStudent` retire
          -- l'élève du registre (`students.is_active = 0`) SANS toucher au
          -- statut de son inscription — à dessein : une sortie de classe exige
          -- un motif normalisé (déperdition scolaire), qu'une désactivation
          -- administrative n'a pas. Sans ce second filtre, l'élève disparaît de
          -- la liste Élèves mais continue d'occuper une place ici, et l'écran
          -- Classes annonce un effectif que la liste ne montre plus.
          SELECT ce.class_id, COUNT(*) AS cnt
          FROM   class_enrollments ce
          JOIN   students s ON s.id = ce.student_id
          WHERE  ce.status = 'active' AND COALESCE(s.is_active, 1) <> 0
          GROUP  BY ce.class_id
        ) ec ON ec.class_id = c.id
        WHERE  c.id = ?
        LIMIT  1
        ''',
        parameters: [classId],
      )
      .map((rows) => rows.isEmpty ? null : ClassModel.fromMap(rows.first));
});

// ─── Élèves inscrits dans une classe ─────────────────────────────────────────

/// Inscriptions actives d'une classe, avec les infos élèves (JOIN local).
final classEnrollmentsProvider = StreamProvider.autoDispose
    .family<List<ClassEnrollmentModel>, String>((ref, classId) {
  return db
      .watch(
        '''
        SELECT ce.*,
               s.first_name,
               s.last_name,
               s.matricule,
               s.photo_url,
               s.gender
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.class_id = ?
        AND    ce.status   = 'active'
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [classId],
      )
      .map((rows) => rows.map(ClassEnrollmentModel.fromMap).toList());
});

// ─── Stats globales ───────────────────────────────────────────────────────────

/// Nombre total de classes actives pour l'école courante.
final classCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(0);
  }
  final scope = classScopeClause(ref, 'classes', column: 'id');
  final scopeClause = scope?.clause ?? '';
  final scopeIds = scope?.params;
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM classes '
        'WHERE school_id = ? AND academic_year_id = ? '
        'AND COALESCE(is_active, 1) <> 0 $scopeClause',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});

/// Nombre total d'élèves inscrits (actifs) pour l'école et l'année actives.
final enrolledStudentCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(0);
  }
  final scope = classScopeClause(ref, 'eleves', column: 'class_id');
  final scopeClause = scope?.clause ?? '';
  final scopeIds = scope?.params;
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM class_enrollments '
        'WHERE school_id = ? AND academic_year_id = ? AND status = \'active\' $scopeClause',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});

// ─── Mutations (offline-first) ────────────────────────────────────────────────

/// Crée une classe dans SQLite local — PowerSync la synchronise vers Supabase
/// dès que la connexion est disponible.
Future<String> createClass({
  required String schoolId,
  required String groupId,
  required String academicYearId,
  required String name,
  int? capacity,
  String? mainTeacherId,
  String? room,
  String? levelId,
}) async {
  // Pré-validation anti-perte silencieuse : contrainte UNIQUE
  // (school_id, academic_year_id, name). Sans ce contrôle, un doublon part en
  // local « avec succès » puis est rejeté en silence (23505) à la synchro.
  final dup = await db.getAll(
    'SELECT 1 FROM classes '
    'WHERE school_id = ? AND academic_year_id = ? AND name = ? LIMIT 1',
    [schoolId, academicYearId, name],
  );
  if (dup.isNotEmpty) {
    throw Exception('Une classe « $name » existe déjà pour cette année scolaire.');
  }

  final id  = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO classes
      (id, school_id, group_id, academic_year_id, name, capacity,
       main_teacher_id, room, level_id, is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, schoolId, groupId, academicYearId, name,
     capacity, mainTeacherId, room, levelId, now, now],
  );
  return id;
}

/// Crée une classe RATTACHÉE à un niveau de la structure académique : pose le
/// vrai `level_id` ET les champs dénormalisés (cycle_code/level_code/level_order
/// /filiere_*) dont dépendent les KPI Inscriptions → cohérence garantie.
Future<String> createStructuredClass({
  required String schoolId,
  required String groupId,
  required String academicYearId,
  required String name,
  required String levelId,
  required String cycleCode,
  required String levelCode,
  required int    levelOrder,
  int?    capacity,
  String? room,
  String? mainTeacherId,
  String? filiereCode,
  String? filiereLabel,
}) async {
  final dup = await db.getAll(
    'SELECT 1 FROM classes WHERE school_id = ? AND academic_year_id = ? AND name = ? LIMIT 1',
    [schoolId, academicYearId, name],
  );
  if (dup.isNotEmpty) {
    throw Exception('Une classe « $name » existe déjà pour cette année scolaire.');
  }
  final id  = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO classes
      (id, school_id, group_id, academic_year_id, name, capacity, room,
       main_teacher_id, level_id, cycle_code, level_code, level_order,
       filiere_code, filiere_label, is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, schoolId, groupId, academicYearId, name, capacity, room,
     mainTeacherId, levelId, cycleCode, levelCode, levelOrder,
     filiereCode, filiereLabel, now, now],
  );
  return id;
}

/// Met à jour les infos d'une classe (nom, capacité, salle, filière).
Future<void> updateClassInfo({
  required String classId,
  String? name,
  int?    capacity,
  String? room,
  String? mainTeacherId,
  bool    clearTeacher = false,
  String? filiereCode,
  String? filiereLabel,
}) async {
  final now = DateTime.now().toIso8601String();
  final fields = <String, dynamic>{
    'name':          ?name,
    'capacity':      ?capacity,
    'room':          ?room,
    if (clearTeacher) 'main_teacher_id': null else 'main_teacher_id': ?mainTeacherId,
    'filiere_code':  ?filiereCode,
    'filiere_label': ?filiereLabel,
  };
  if (fields.isEmpty) return;
  final setClauses = fields.keys.map((k) => '$k = ?').join(', ');
  await db.execute(
    'UPDATE classes SET $setClauses, updated_at = ? WHERE id = ?',
    [...fields.values, now, classId],
  );
}

/// Archive une classe (soft delete — is_active = 0).
Future<void> archiveClass(String classId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE classes SET is_active = 0, updated_at = ? WHERE id = ?',
    [now, classId],
  );
}

/// Export CSV des classes (séparateur `;`, BOM UTF-8). Retourne le chemin.
Future<String> exportClassesCsv(List<ClassModel> rows) async {
  String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
  final b = StringBuffer();
  b.writeln(['Classe', 'Niveau', 'Filière', 'Effectif', 'Capacité', 'Salle']
      .map(cell)
      .join(';'));
  for (final r in rows) {
    b.writeln([
      r.name, r.levelCode ?? '', r.filiereLabel ?? '',
      '${r.studentCount ?? 0}', r.capacity?.toString() ?? '', r.room ?? '',
    ].map(cell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/classes_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}

// ─── Inscriptions en attente de validation ────────────────────────────────────

/// Inscriptions `pending_validation` de l'école courante (tableau du directeur).
final pendingEnrollmentsProvider =
    StreamProvider.autoDispose<List<ClassEnrollmentModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value([]);
  }
  final scope = classScopeClause(ref, 'inscriptions', column: 'ce.class_id');
  final scopeClause = scope?.clause ?? '';
  final scopeIds = scope?.params;
  return db
      .watch(
        '''
        SELECT ce.*,
               s.first_name,
               s.last_name,
               s.matricule,
               s.photo_url,
               s.gender
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.school_id = ?
        AND    ce.academic_year_id = ?
        AND    ce.status    = 'pending_validation'
        $scopeClause
        ORDER  BY ce.created_at DESC
        ''',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.map(ClassEnrollmentModel.fromMap).toList());
});

/// Inscrit un élève dans une classe avec statut `pending_validation`.
/// Le directeur devra valider ou rejeter via [validateEnrollment]/[rejectEnrollment].
Future<String> enrollStudent({
  required String schoolId,
  required String groupId,
  required String studentId,
  required String classId,
  required String academicYearId,
  bool isRepeating = false,
  String? previousClassId,
  String inscriptionType = 'new',        // new | reinscription | transfer
  String? previousSchoolName,
  String? previousClassName,
  String? transferReason,                // motif si type=transfer (0007)
  String? filiereId,                     // filière FP → education_programs (0007)
  String? notes,                         // notes internes (0007)
  String? createdBy,                     // agent ayant saisi l'inscription (0007)
}) async {
  // Pré-validation anti-perte silencieuse : contrainte UNIQUE
  // (student_id, academic_year_id) — un élève = une seule inscription par année
  // (tout statut confondu). Sans ce contrôle, le doublon serait rejeté en
  // silence (23505) à la synchro et l'inscription « disparaîtrait ».
  final dup = await db.getAll(
    'SELECT 1 FROM class_enrollments '
    'WHERE student_id = ? AND academic_year_id = ? LIMIT 1',
    [studentId, academicYearId],
  );
  if (dup.isNotEmpty) {
    throw Exception('Cet élève est déjà inscrit pour cette année scolaire.');
  }

  final id    = _uuid.v4();
  final now   = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  await db.execute(
    '''
    INSERT INTO class_enrollments
      (id, group_id, school_id, student_id, class_id, academic_year_id,
       enrollment_date, status, is_repeating, previous_class_id,
       inscription_type, previous_school_name, previous_class_name,
       transfer_reason, filiere_id, notes, created_by,
       created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending_validation', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id, groupId, schoolId, studentId, classId, academicYearId,
      today, isRepeating ? 1 : 0, previousClassId,
      inscriptionType, previousSchoolName, previousClassName,
      transferReason, filiereId, notes, createdBy,
      now, now,
    ],
  );
  return id;
}

/// Valide une inscription (pending_validation → active).
Future<void> validateEnrollment({
  required String enrollmentId,
  required String validatedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status       = 'active',
           validated_at = ?,
           validated_by = ?,
           updated_at   = ?
    WHERE  id = ?
    ''',
    [now, validatedBy, now, enrollmentId],
  );
}

/// Rejette une inscription (pending_validation → rejected).
Future<void> rejectEnrollment({
  required String enrollmentId,
  required String rejectionReason,
  required String validatedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status           = 'rejected',
           rejection_reason = ?,
           validated_at     = ?,
           validated_by     = ?,
           updated_at       = ?
    WHERE  id = ?
    ''',
    [rejectionReason, now, validatedBy, now, enrollmentId],
  );
}

/// Remet un dossier REJETÉ dans le circuit de validation.
///
/// ── Pourquoi cette fonction existe ──────────────────────────────────────────
/// `class_enrollments` porte `UNIQUE (student_id, academic_year_id)` SANS
/// condition de statut. Une fois l'inscription rejetée, la ligne occupe la
/// place : `enrollStudent` refuse toute nouvelle saisie pour cet élève et cette
/// année. La seule sortie offerte était « Supprimer l'inscription », un DELETE
/// sec — c'est-à-dire la disparition du motif de rejet et de son auteur.
///
/// Or un rejet est un acte d'établissement. Le secrétariat qui corrige une
/// pièce manquante et resoumet le dossier ne doit pas, ce faisant, effacer la
/// trace de la décision du chef.
///
/// ── Où va le motif ─────────────────────────────────────────────────────────
/// Il descend dans les notes internes, daté, et `rejection_reason` est libéré.
/// Le garder en place afficherait « Motif du rejet » sur un dossier redevenu
/// « en attente » — deux états contradictoires sur la même fiche. L'historique
/// appartient aux notes ; le champ de rejet décrit l'état courant.
Future<void> reopenRejectedEnrollment({
  required String enrollmentId,
  required String actorName,
}) async {
  final now = DateTime.now();
  final row = await db.getOptional(
    'SELECT notes, rejection_reason FROM class_enrollments WHERE id = ?',
    [enrollmentId],
  );
  final motif = (row?['rejection_reason'] as String?)?.trim() ?? '';
  final notes = (row?['notes'] as String?)?.trim() ?? '';

  final d = '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year}';
  final trace = motif.isEmpty
      ? 'Dossier rejeté puis repris le $d par $actorName.'
      : 'Rejeté le $d — motif : $motif. Dossier repris par $actorName.';
  final fusion = notes.isEmpty ? trace : '$notes\n$trace';

  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status           = 'pending_validation',
           rejection_reason = NULL,
           validated_at     = NULL,
           validated_by     = NULL,
           notes            = ?,
           updated_at       = ?
    WHERE  id = ?
    ''',
    [fusion, now.toIso8601String(), enrollmentId],
  );
}

/// Accorde, modifie ou retire l'exonération de scolarité d'une inscription.
///
/// [taux] est un pourcentage 1–100, ou `null` pour retirer l'exonération.
/// [motif] est OBLIGATOIRE dès qu'un taux est posé — la contrainte
/// `class_enrollments_exoneration_justifiee` (migration 0109) le refuse
/// autrement, et un refus serveur fait abandonner à PowerSync le LOT ENTIER
/// des écritures de la fenêtre, en silence. On valide donc AVANT d'écrire.
///
/// ⚠️ Zéro n'est pas une exonération : la base le refuse, et « exonéré de
/// rien » n'a pas de sens. Un taux ≤ 0 vaut retrait.
///
/// La décision descend dans les notes internes, datée et signée : une remise
/// de scolarité est de l'argent auquel l'école renonce, elle doit rester
/// lisible six mois plus tard sans consulter l'audit.
Future<void> setEnrollmentExemption({
  required String enrollmentId,
  required int? taux,
  required String motif,
  required String actorName,
}) async {
  final accorde = taux != null && taux > 0;
  final m = motif.trim();
  if (accorde && m.isEmpty) {
    throw ArgumentError('Une exonération sans motif est refusée par la base.');
  }
  if (accorde && taux > 100) {
    throw ArgumentError('Le taux d\'exonération ne peut pas dépasser 100 %.');
  }

  final now = DateTime.now();
  final d = '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year}';
  final row = await db.getOptional(
    'SELECT notes FROM class_enrollments WHERE id = ?',
    [enrollmentId],
  );
  final notes = (row?['notes'] as String?)?.trim() ?? '';
  final trace = accorde
      ? 'Exonération de scolarité de $taux % accordée le $d par $actorName — '
          'motif : $m.'
      : 'Exonération de scolarité retirée le $d par $actorName.';
  final fusion = notes.isEmpty ? trace : '$notes\n$trace';

  await db.execute(
    '''
    UPDATE class_enrollments
    SET    exemption_rate  = ?,
           exemption_motif = ?,
           notes           = ?,
           updated_at      = ?
    WHERE  id = ?
    ''',
    [
      accorde ? taux : null,
      accorde ? m : null,
      fusion,
      now.toIso8601String(),
      enrollmentId,
    ],
  );
}

/// Retire un élève d'une classe (status → withdrawn).
Future<void> withdrawStudent({
  required String enrollmentId,
  required String reason,
  required String motif,
}) async {
  final now   = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status = 'withdrawn',
           withdrawal_date   = ?,
           withdrawal_motif  = ?,
           withdrawal_reason = ?,
           updated_at        = ?
    WHERE  id = ?
    ''',
    [today, motif, reason, now, enrollmentId],
  );
}

/// Réaffecte une inscription dans une autre classe (même année).
Future<void> changeEnrollmentClass({
  required String enrollmentId,
  required String newClassId,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE class_enrollments SET class_id = ?, updated_at = ? WHERE id = ?',
    [newClassId, now, enrollmentId],
  );
}

/// Annule la validation d'une inscription (active → pending_validation).
/// L'élève quitte la page Élèves et réapparaît dans le pipeline Inscriptions.
Future<void> revertEnrollmentToValidation(String enrollmentId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status       = 'pending_validation',
           validated_at = NULL,
           validated_by = NULL,
           updated_at   = ?
    WHERE  id = ?
    ''',
    [now, enrollmentId],
  );
}

/// Sortie d'un élève de l'effectif : transfert / radiation / fin de scolarité.
/// [status] ∈ transferred | withdrawn | graduated. Conserve la ligne (historique).
Future<void> setEnrollmentExit({
  required String enrollmentId,
  required String status,
  required String reason,
  required String motif,
}) async {
  final now = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status            = ?,
           withdrawal_date   = ?,
           withdrawal_motif  = ?,
           withdrawal_reason = ?,
           updated_at        = ?
    WHERE  id = ?
    ''',
    [status, today, motif, reason, now, enrollmentId],
  );
}

/// Met à jour les informations de scolarité d'une inscription (classe, type,
/// redoublant, école d'origine, notes). Le statut/validation n'est PAS touché.
Future<void> updateEnrollmentDetails({
  required String enrollmentId,
  required String classId,
  required String inscriptionType,
  required bool isRepeating,
  String? previousSchoolName,
  String? previousClassName,
  String? transferReason,
  String? notes,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    class_id             = ?,
           inscription_type     = ?,
           is_repeating         = ?,
           previous_school_name = ?,
           previous_class_name  = ?,
           transfer_reason      = ?,
           notes                = ?,
           updated_at           = ?
    WHERE  id = ?
    ''',
    [
      classId, inscriptionType, isRepeating ? 1 : 0,
      previousSchoolName, previousClassName, transferReason, notes,
      now, enrollmentId,
    ],
  );
}

/// Supprime définitivement une inscription (hard delete de la ligne).
/// L'élève (table students) est conservé : seul le lien classe/année part.
Future<void> deleteEnrollment(String enrollmentId) async {
  await db.execute('DELETE FROM class_enrollments WHERE id = ?', [enrollmentId]);
}
