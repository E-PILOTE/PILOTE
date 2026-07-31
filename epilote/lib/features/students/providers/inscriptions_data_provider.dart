import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DONNÉES DE LA PAGE INSCRIPTIONS — 100% offline (db.watch local), année active.
//  Joint class_enrollments + students + classes ; les KPI/graphes/listes sont
//  dérivés côté client (une école = quelques centaines d'inscrits au plus).
// ════════════════════════════════════════════════════════════════════════════

// ─── Classifieur de cycle (nom de classe → cycle) ────────────────────────────
// Les classes congolaises n'ont pas toujours de level_id renseigné ; le NOM de
// la classe (« 6ème A », « CP1 », « Terminale C ») est le seul lien fiable et
// 100% offline vers le cycle. Les cycles présents reflètent dynamiquement ceux
// de l'école (hérités à sa création). Ordre = ordre pédagogique (préscolaire→FP).
class InscriptionCycle {
  const InscriptionCycle(this.code, this.label, this.order);
  final String code;
  final String label;
  final int order;
}

const _cyclePrescolaire = InscriptionCycle('prescolaire', 'Préscolaire', 1);
const _cyclePrimaire    = InscriptionCycle('primaire', 'Primaire', 2);
const _cycleCollege     = InscriptionCycle('college', 'Collège', 3);
const _cycleLycee       = InscriptionCycle('lycee', 'Lycée', 4);
const _cycleFp          = InscriptionCycle('fp', 'Formation Pro.', 5);
const _cycleAutre       = InscriptionCycle('autre', 'Non classé', 9);

/// Cycle RÉEL d'une classe via son `cycle_code` (dénormalisé depuis
/// classe→niveau→cycle, migration 0010). Repli sur l'heuristique par NOM
/// uniquement si la classe n'est pas encore reliée à un niveau (cycle_code nul).
const _cycleByCode = <String, InscriptionCycle>{
  'prescolaire': _cyclePrescolaire,
  'primaire': _cyclePrimaire,
  'college': _cycleCollege,
  'lycee': _cycleLycee,
  'formation_pro': _cycleFp,
};

InscriptionCycle inscriptionCycleFromCode(String? code, String? fallbackName) {
  final c = _cycleByCode[code];
  return c ?? inscriptionCycleOf(fallbackName);
}

/// Ordre pédagogique d'un cycle par son code normalisé (cf. InscriptionCycle).
/// Sert au tri GLOBAL des niveaux/classes quand l'école a plusieurs cycles
/// (sinon CP1, 6ᵉ et 2ⁿᵈᵉ — tous d'ordre 1 dans leur cycle — s'entremêlent).
const _cycleOrderByCode = <String, int>{
  'prescolaire': 1, 'primaire': 2, 'college': 3, 'lycee': 4, 'fp': 5,
};
int cycleOrderOf(String code) => _cycleOrderByCode[code] ?? 9;

/// Déduit le cycle d'une classe à partir de son nom (conventions Congo).
InscriptionCycle inscriptionCycleOf(String? rawName) {
  final n = (rawName ?? '').toLowerCase().trim();
  if (n.isEmpty) return _cycleAutre;
  // Normalisation : accents → ascii, espaces/tirets retirés.
  final s = n
      .replaceAll(RegExp(r'[éèê]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[\s\-_.]'), '');
  if (s.contains('maternelle') ||
      RegExp(r'^(ps|ms|gs|creche|eveil)').hasMatch(s)) {
    return _cyclePrescolaire;
  }
  if (RegExp(r'(cp[12]?|ce[12]|cm[12])').hasMatch(s)) return _cyclePrimaire;
  if (RegExp(r'^(6|5|4|3)(e|eme|ieme)').hasMatch(s)) return _cycleCollege;
  if (RegExp(r'(2nd|2de|seconde|1er|1re|premiere|tle|tlle|terminale)')
      .hasMatch(s)) {
    return _cycleLycee;
  }
  if (RegExp(r'(cap|bep|bacpro|^bt|^fp)').hasMatch(s)) return _cycleFp;
  return _cycleAutre;
}

// ─── Ligne d'inscription (vue liste/table/cartes) ───────────────────────────
class InscriptionRow {
  const InscriptionRow({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.gender,
    required this.dateOfBirth,
    required this.photoUrl,
    required this.classId,
    required this.className,
    required this.capacity,
    required this.cycle,
    required this.levelCode,
    required this.levelOrder,
    required this.filiereLabel,
    required this.inscriptionType,
    required this.status,
    required this.isRepeating,
    required this.enrollmentDate,
    required this.validatedAt,
  });

  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String matricule;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final String? classId;
  final String className;

  /// Âge en années révolues (null si date de naissance inconnue).
  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 130 ? null : a;
  }
  final int capacity;           // capacité de la classe (0 si non définie)
  final InscriptionCycle cycle;
  final String? levelCode;      // niveau réel (ex. « 6e ») via classe→niveau
  final int levelOrder;         // ordre pédagogique (tri des niveaux)
  final String? filiereLabel;   // filière (lycée/FP) via classe→niveau, NULL sinon
  final String inscriptionType; // new | reinscription | transfer
  final String status;          // active | pending_validation | rejected | …
  final bool isRepeating;
  final DateTime? enrollmentDate;
  final DateTime? validatedAt;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  String get typeLabel => switch (inscriptionType) {
        'new' => 'Nouvelle',
        'reinscription' => 'Réinscription',
        'transfer' => 'Transfert',
        _ => inscriptionType,
      };

  String get statusLabel => switch (status) {
        'active' => 'Validée',
        'pending_validation' => 'En attente',
        'rejected' => 'Rejetée',
        'withdrawn' => 'Retirée',
        'transferred' => 'Transférée',
        'graduated' => 'Diplômée',
        _ => status,
      };
}

/// Toutes les inscriptions de l'année active (tous statuts) + élève + classe.
final inscriptionsDataProvider =
    StreamProvider.autoDispose<List<InscriptionRow>>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  return db
      .watch(
        '''
        SELECT ce.id, ce.student_id, ce.status, ce.inscription_type,
               ce.is_repeating, ce.enrollment_date, ce.validated_at,
               s.first_name, s.last_name, s.matricule, s.gender,
               s.date_of_birth, s.photo_url,
               c.id AS class_id, c.name AS class_name, c.capacity AS capacity,
               c.cycle_code AS cycle_code, c.level_code AS level_code,
               c.level_order AS level_order, c.filiere_label AS filiere_label
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  ce.school_id = ? AND ce.academic_year_id = ?
        AND    ce.status != 'active'
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [schoolId, yearId],
      )
      .map((rows) => [
            for (final r in rows)
              InscriptionRow(
                id: r['id'] as String,
                studentId: r['student_id'] as String,
                firstName: r['first_name'] as String? ?? '',
                lastName: r['last_name'] as String? ?? '',
                matricule: r['matricule'] as String? ?? '',
                gender: r['gender'] as String?,
                dateOfBirth: _d(r['date_of_birth']),
                photoUrl: r['photo_url'] as String?,
                classId: r['class_id'] as String?,
                className: r['class_name'] as String? ?? '—',
                capacity: (r['capacity'] as int?) ?? 0,
                cycle: inscriptionCycleFromCode(
                    r['cycle_code'] as String?, r['class_name'] as String?),
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                filiereLabel: (r['filiere_label'] as String?)?.trim().isEmpty ?? true
                    ? null
                    : (r['filiere_label'] as String).trim(),
                inscriptionType: r['inscription_type'] as String? ?? 'new',
                status: r['status'] as String? ?? 'active',
                isRepeating: r['is_repeating'] == 1 || r['is_repeating'] == true,
                enrollmentDate: _d(r['enrollment_date']),
                validatedAt: _d(r['validated_at']),
              ),
          ]);
});

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

// ─── Évolution du pipeline par dimension (cycle / niveau / classe) ───────────
// Le pipeline = dossiers EN COURS (statut ≠ validé ; rejets exclus). Pour chaque
// catégorie de la dimension choisie : total + arrivées par mois (rythme). Sert au
// graphe d'évolution multi-séries ET aux compteurs par catégorie. 100% dérivé des
// lignes déjà chargées — distinct de la page Élèves (effectif VALIDÉ).
class PipelineCat {
  const PipelineCat(this.key, this.label, this.cycleCode, this.order, this.total,
      this.monthly);
  final String key, label, cycleCode;
  final int order, total;
  final List<int> monthly; // aligné sur PipelineEvolution.months
}

class PipelineEvolution {
  const PipelineEvolution(this.months, this.cats);
  final List<String> months;     // « MM/yyyy » chronologique
  final List<PipelineCat> cats;  // trié cycle → ordre niveau → total
  int get grandTotal => cats.fold(0, (s, c) => s + c.total);
  static const empty = PipelineEvolution([], []);
}

/// Évolution du pipeline pour la dimension [dim] = 'cycle' | 'niveau' | 'classe'.
final pipelineEvolutionProvider =
    Provider.autoDispose.family<PipelineEvolution, String>((ref, dim) {
  final rows = ref.watch(inscriptionsDataProvider).valueOrNull ?? const [];

  String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  final monthsSet = <String>{};
  for (final r in rows) {
    if (r.status == 'rejected') continue;
    final d = r.enrollmentDate;
    if (d != null) monthsSet.add(monthKey(d));
  }
  final months = monthsSet.toList()..sort();
  final monthIdx = {for (var i = 0; i < months.length; i++) months[i]: i};

  final monthly = <String, List<int>>{};
  final totals = <String, int>{};
  final meta = <String, (String, String, int)>{}; // key → (label, cycle, order)

  for (final r in rows) {
    if (r.status == 'rejected') continue;
    String key, label;
    final cycle = r.cycle.code;
    int order;
    switch (dim) {
      case 'niveau':
        final lc = r.levelCode;
        if (lc == null || lc.isEmpty) continue;
        key = '$cycle/$lc';
        label = lc;
        order = r.levelOrder;
      case 'classe':
        if (r.className.isEmpty || r.className == '—') continue;
        key = r.className;
        label = r.className;
        order = r.levelOrder;
      default: // cycle
        key = cycle;
        label = r.cycle.label;
        order = r.cycle.order;
    }
    monthly.putIfAbsent(key, () => List<int>.filled(months.length, 0));
    meta[key] = (label, cycle, order);
    totals[key] = (totals[key] ?? 0) + 1;
    final d = r.enrollmentDate;
    if (d != null) {
      final mi = monthIdx[monthKey(d)];
      if (mi != null) monthly[key]![mi]++;
    }
  }

  final cats = <PipelineCat>[
    for (final e in monthly.entries)
      PipelineCat(e.key, meta[e.key]!.$1, meta[e.key]!.$2, meta[e.key]!.$3,
          totals[e.key] ?? 0, e.value),
  ]..sort((a, b) {
      final c = cycleOrderOf(a.cycleCode).compareTo(cycleOrderOf(b.cycleCode));
      if (c != 0) return c;
      final o = a.order.compareTo(b.order);
      return o != 0 ? o : b.total.compareTo(a.total);
    });

  return PipelineEvolution(months, cats);
});

// ─── Dossier complet d'un élève (détail / modification) ──────────────────────
class StudentTutorInfo {
  const StudentTutorInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.phonePrimary,
    required this.phoneSecondary,
    required this.email,
    required this.profession,
    required this.address,
    required this.isPrimary,
    required this.isEmergency,
  });
  final String id, firstName, lastName, relationship;
  final String? phonePrimary, phoneSecondary, email, profession, address;
  final bool isPrimary, isEmergency;

  String get fullName => '$firstName $lastName'.trim();
}

class StudentDossier {
  const StudentDossier({required this.student, required this.tutors});
  final Map<String, dynamic> student; // ligne students brute
  final List<StudentTutorInfo> tutors;

  String s(String k) => (student[k] as String?)?.trim() ?? '';
  DateTime? get dob => _d(student['date_of_birth']);
}

/// Dossier élève (offline) : ligne students + tuteurs. Invalidé après édition.
final studentDossierProvider =
    FutureProvider.autoDispose.family<StudentDossier, String>((ref, id) async {
  final s = await db.getOptional('SELECT * FROM students WHERE id = ?', [id]);
  final tutors = await db.getAll(
    'SELECT * FROM student_tutors WHERE student_id = ? '
    'ORDER BY is_primary_contact DESC, last_name',
    [id],
  );
  return StudentDossier(
    student: s ?? const {},
    tutors: [
      for (final t in tutors)
        StudentTutorInfo(
          id: (t['id'] as String?) ?? '',
          firstName: (t['first_name'] as String?) ?? '',
          lastName: (t['last_name'] as String?) ?? '',
          relationship: (t['relationship'] as String?) ?? '',
          phonePrimary: t['phone_primary'] as String?,
          phoneSecondary: t['phone_secondary'] as String?,
          email: t['email'] as String?,
          profession: t['profession'] as String?,
          address: t['address'] as String?,
          isPrimary: t['is_primary_contact'] == 1 ||
              t['is_primary_contact'] == true,
          isEmergency: t['is_emergency_contact'] == 1 ||
              t['is_emergency_contact'] == true,
        ),
    ],
  );
});

/// Ligne brute `class_enrollments` (champs scolarité non portés par la vue
/// liste : école/classe d'origine, motif transfert, notes, rejet, retrait).
/// Utilisée par la fiche détail et l'assistant de modification.
final enrollmentDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, enrollmentId) async {
  final r = await db.getOptional(
      'SELECT * FROM class_enrollments WHERE id = ?', [enrollmentId]);
  return r ?? const <String, dynamic>{};
});

// ─── Structure académique RÉELLE de l'école (cycles / niveaux / classes) ─────
// Dérivée 100% offline de la table `classes` (déjà synchronisée). Une classe
// porte son cycle (`cycle_code`), son niveau (`level_code`/`level_order`) et sa
// filière (`filiere_label`). On peut inscrire un élève UNIQUEMENT dans une
// classe : la structure pertinente pour les inscriptions = les classes qui
// existent. Dès que la direction crée une classe (ex. une 2nde au Lycée), son
// cycle / niveau / classe apparaît automatiquement — sans dépendre d'un
// déploiement des sync-rules. Inclut les classes VIDES (0 inscrit).
class SchoolLevelDef {
  const SchoolLevelDef(this.code, this.cycleCode, this.order);
  final String code, cycleCode;
  final int order;
}

class SchoolClassDef {
  const SchoolClassDef(this.name, this.cycleCode, this.levelCode,
      this.levelOrder, this.capacity, this.filiere);
  final String name, cycleCode;
  final String? levelCode, filiere;
  final int levelOrder, capacity;
}

class SchoolStructure {
  const SchoolStructure(this.cycles, this.levels, this.classes);
  final List<InscriptionCycle> cycles;
  final List<SchoolLevelDef> levels;
  final List<SchoolClassDef> classes;
  static const empty = SchoolStructure([], [], []);
}

final schoolStructureProvider =
    StreamProvider.autoDispose<SchoolStructure>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(SchoolStructure.empty);
  }
  // Scopé à l'ANNÉE ACTIVE (comme les inscriptions) : les classes d'une autre
  // année n'apparaissent pas. Dynamique aussi au changement d'école/groupe
  // (schoolId) et d'année (yearId).
  return db
      .watch(
    '''
    SELECT name, cycle_code, level_code, level_order, capacity, filiere_label
    FROM   classes
    WHERE  school_id = ? AND academic_year_id = ? AND is_active = 1
    ORDER  BY level_order, name
    ''',
    parameters: [schoolId, yearId],
  )
      .map((rows) {
    final cyclesByCode = <String, InscriptionCycle>{};
    final levels = <SchoolLevelDef>[];
    final seenLevel = <String>{};
    final classes = <SchoolClassDef>[];
    for (final r in rows) {
      final cyc = inscriptionCycleFromCode(
          r['cycle_code'] as String?, r['name'] as String?);
      cyclesByCode.putIfAbsent(cyc.code, () => cyc);
      final lc = r['level_code'] as String?;
      final lo = (r['level_order'] as int?) ?? 999;
      if (lc != null && lc.isNotEmpty && seenLevel.add('${cyc.code}/$lc')) {
        levels.add(SchoolLevelDef(lc, cyc.code, lo));
      }
      final fl = (r['filiere_label'] as String?)?.trim();
      classes.add(SchoolClassDef(
        r['name'] as String? ?? '—',
        cyc.code,
        (lc == null || lc.isEmpty) ? null : lc,
        lo,
        (r['capacity'] as int?) ?? 0,
        (fl == null || fl.isEmpty) ? null : fl,
      ));
    }
    final cycles = cyclesByCode.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    levels.sort((a, b) {
      final c = cycleOrderOf(a.cycleCode).compareTo(cycleOrderOf(b.cycleCode));
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return SchoolStructure(cycles, levels, classes);
  });
});

// ════════════════════════════════════════════════════════════════════════════
//  BILAN DE L'ANNÉE — toutes les inscriptions, pas seulement celles qui restent
//  au guichet.
//
//  La liste de cette page est volontairement le PIPELINE : `inscriptionsDataProvider`
//  écarte `status = 'active'`, parce qu'un dossier validé n'a plus rien à y
//  faire — l'élève inscrit vit dans la page Élèves. C'est un bon découpage.
//
//  Mais les compteurs, eux, en héritaient : sur une école qui avait inscrit
//  trente élèves et en avait réinscrit trente et un, la carte « Nouvelles —
//  premières inscriptions » affichait **0**, et « Réinscriptions » **1**. Non
//  pas approximativement : le chiffre décrivait les deux dossiers non traités
//  qui traînaient, pas le travail de l'année. Aucune ligne à l'écran ne
//  permettait de s'en douter, et la question la plus simple qu'on pose à un
//  module d'inscription — « combien d'élèves avez-vous inscrits ? » — n'avait
//  aucune réponse dans la page qui porte ce nom.
//
//  D'où cette agrégation distincte, sur TOUTES les inscriptions de l'année.
//  Elle compte des lignes, pas des personnes : un élève réinscrit après un
//  rejet a deux dossiers, et c'est bien deux dossiers qu'a traités le
//  secrétariat. L'effectif, lui, se lit sur les inscriptions actives.
// ════════════════════════════════════════════════════════════════════════════
class YearInscriptionTotals {
  const YearInscriptionTotals({
    this.enrolled = 0,
    this.newCount = 0,
    this.reinscription = 0,
    this.transfer = 0,
    this.repeating = 0,
  });

  /// Inscriptions ACTIVES : l'effectif réellement scolarisé cette année.
  final int enrolled;

  /// Dossiers de l'année par type, tous statuts confondus.
  final int newCount, reinscription, transfer;

  /// Dossiers portant la mention « redoublant ».
  final int repeating;
}

final yearInscriptionTotalsProvider =
    StreamProvider.autoDispose<YearInscriptionTotals>((ref) {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const YearInscriptionTotals());
  }
  return db
      .watch(
        '''
        SELECT
          SUM(CASE WHEN status = 'active'                THEN 1 ELSE 0 END) AS enrolled,
          SUM(CASE WHEN inscription_type = 'reinscription' THEN 1 ELSE 0 END) AS re,
          SUM(CASE WHEN inscription_type = 'transfer'      THEN 1 ELSE 0 END) AS tr,
          SUM(CASE WHEN COALESCE(inscription_type, 'new') NOT IN
                        ('reinscription', 'transfer')     THEN 1 ELSE 0 END) AS nw,
          SUM(CASE WHEN is_repeating = 1                 THEN 1 ELSE 0 END) AS rep
        FROM class_enrollments
        WHERE school_id = ? AND academic_year_id = ?
        ''',
        parameters: [schoolId, yearId],
      )
      .map((rows) {
        if (rows.isEmpty) return const YearInscriptionTotals();
        int n(String k) => (rows.first[k] as int?) ?? 0;
        return YearInscriptionTotals(
          enrolled: n('enrolled'),
          newCount: n('nw'),
          reinscription: n('re'),
          transfer: n('tr'),
          repeating: n('rep'),
        );
      });
});

// ─── Export CSV ──────────────────────────────────────────────────────────────

String _csvCell(String? v) {
  final s = (v ?? '').replaceAll('"', '""');
  return '"$s"';
}

/// Génère un CSV (séparateur `;` — compatible Excel FR) des inscriptions filtrées
/// et l'écrit dans le dossier Documents de l'appareil. Retourne le chemin.
Future<String> exportInscriptionsCsv(List<InscriptionRow> rows) async {
  final b = StringBuffer();
  b.writeln([
    'Matricule', 'Nom', 'Prénom', 'Sexe', 'Classe', 'Cycle',
    'Type', 'Statut', 'Redoublant', 'Date inscription',
  ].map(_csvCell).join(';'));
  for (final r in rows) {
    b.writeln([
      r.matricule, r.lastName, r.firstName,
      r.gender ?? '', r.className, r.cycle.label,
      r.typeLabel, r.statusLabel, r.isRepeating ? 'Oui' : 'Non',
      r.enrollmentDate?.toIso8601String().substring(0, 10) ?? '',
    ].map(_csvCell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/inscriptions_$ts.csv');
  // BOM UTF-8 pour qu'Excel lise correctement les accents.
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}

// ─── Agrégations dérivées (KPI / cycles / évolution) ─────────────────────────

class CycleCount {
  const CycleCount(this.cycle, this.total, this.boys, this.girls);
  final InscriptionCycle cycle;
  final int total, boys, girls;
}

class LevelCount {
  const LevelCount(
      this.code, this.cycleCode, this.order, this.total, this.boys, this.girls);
  final String code;            // ex. « 6e », « CP1 », « Tle »
  final String cycleCode;       // cycle parent (couleur d'accent)
  final int order, total, boys, girls;
}

class ClassCount {
  const ClassCount(this.name, this.cycleCode, this.levelCode, this.levelOrder,
      this.capacity, this.total, this.boys, this.girls);
  final String name;            // ex. « 6ème A »
  final String cycleCode;       // pour la couleur d'accent
  final String? levelCode;      // niveau parent (ex. « 6e ») → groupage par niveau
  final int levelOrder, capacity, total, boys, girls;
  double get fillRatio => capacity > 0 ? total / capacity : 0;
}

class ProgramCount {
  const ProgramCount(this.label, this.total, this.boys, this.girls);
  final String label;           // filière (lycée/FP) ex. « Série C »
  final int total, boys, girls;
}

/// Un point d'évolution : nouvelles inscriptions du mois + cumul à ce mois.
class EnrollPoint {
  const EnrollPoint(this.label, this.count, this.cumul);
  final String label;           // « MM/yyyy »
  final int count;              // inscriptions DU mois (rythme)
  final int cumul;              // effectif cumulé à la fin du mois
}

class InscriptionStats {
  const InscriptionStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.rejected,
    required this.boys,
    required this.girls,
    required this.typeNew,
    required this.reinscription,
    required this.transfer,
    required this.repeating,
    required this.byCycle,
    required this.byLevel,
    required this.byClass,
    required this.byProgram,
    required this.capacityTotal,
    required this.evolution,
  });

  final int total, active, pending, rejected;
  final int boys, girls;
  final int typeNew, reinscription, transfer, repeating;
  final int capacityTotal;               // somme des capacités des classes
  double get fillRatio =>
      capacityTotal > 0 ? total / capacityTotal : 0;
  final List<CycleCount> byCycle;        // trié ordre pédagogique
  final List<LevelCount> byLevel;        // par niveau (6e, 5e…), ordre pédagogique
  final List<ClassCount> byClass;        // par classe (6ème A…), ordre niveau puis nom
  final List<ProgramCount> byProgram;    // par filière (lycée/FP) — vide si aucune
  final List<EnrollPoint> evolution;     // rythme + cumul par mois (croissant)
}

/// Statistiques d'inscription dérivées (mêmes données, calculées côté client).
final inscriptionStatsProvider = Provider.autoDispose<InscriptionStats>((ref) {
  final rows = ref.watch(inscriptionsDataProvider).valueOrNull ?? const [];
  final structure =
      ref.watch(schoolStructureProvider).valueOrNull ?? SchoolStructure.empty;

  var active = 0, pending = 0, rejected = 0, boys = 0, girls = 0;
  var tNew = 0, tRe = 0, tTr = 0, repeating = 0;
  final cycleMap = <String, List<int>>{}; // code → [total, boys, girls, order]
  final cycleObj = <String, InscriptionCycle>{};
  final levelMap = <String, List<int>>{}; // code niveau → [total, boys, girls, order]
  final levelCycle = <String, String>{};  // code niveau → cycle code
  final classMap = <String, List<int>>{}; // nom classe → [total, boys, girls, order, capacity]
  final classCycle = <String, String>{};  // nom classe → cycle code
  final classLevel = <String, String?>{}; // nom classe → code niveau (groupage)
  final progMap = <String, List<int>>{};  // filière → [total, boys, girls]
  final monthCount = <String, int>{};

  // Amorçage à 0 depuis la structure RÉELLE de l'école : tous les cycles,
  // niveaux et classes configurés apparaissent même sans inscrit (dynamique).
  for (final c in structure.cycles) {
    cycleMap.putIfAbsent(c.code, () => [0, 0, 0, c.order]);
    cycleObj[c.code] = c;
  }
  for (final l in structure.levels) {
    levelMap.putIfAbsent(l.code, () => [0, 0, 0, l.order]);
    levelCycle[l.code] = l.cycleCode;
  }
  for (final cl in structure.classes) {
    classMap.putIfAbsent(cl.name, () => [0, 0, 0, cl.levelOrder, cl.capacity]);
    classCycle[cl.name] = cl.cycleCode;
    classLevel[cl.name] = cl.levelCode;
    if (cl.filiere != null) progMap.putIfAbsent(cl.filiere!, () => [0, 0, 0]);
  }

  for (final r in rows) {
    switch (r.status) {
      case 'active': active++;
      case 'pending_validation': pending++;
      case 'rejected': rejected++;
    }
    // KPI cycle/genre/évolution : sur les inscriptions « réelles » (hors rejet).
    if (r.status == 'rejected') continue;
    if (r.gender == 'M') {
      boys++;
    } else if (r.gender == 'F') {
      girls++;
    }
    switch (r.inscriptionType) {
      case 'new': tNew++;
      case 'reinscription': tRe++;
      case 'transfer': tTr++;
    }
    if (r.isRepeating) repeating++;

    final c = cycleMap.putIfAbsent(r.cycle.code, () => [0, 0, 0, r.cycle.order]);
    cycleObj[r.cycle.code] = r.cycle;
    c[0]++;
    if (r.gender == 'M') {
      c[1]++;
    } else if (r.gender == 'F') {
      c[2]++;
    }

    final lc = r.levelCode;
    if (lc != null && lc.isNotEmpty) {
      final lv = levelMap.putIfAbsent(lc, () => [0, 0, 0, r.levelOrder]);
      levelCycle[lc] = r.cycle.code;
      lv[0]++;
      if (r.gender == 'M') {
        lv[1]++;
      } else if (r.gender == 'F') {
        lv[2]++;
      }
    }

    // Par classe (toujours disponible : nom de classe).
    if (r.className.isNotEmpty && r.className != '—') {
      final cl = classMap.putIfAbsent(
          r.className, () => [0, 0, 0, r.levelOrder, r.capacity]);
      classCycle[r.className] = r.cycle.code;
      classLevel[r.className] = r.levelCode;
      cl[0]++;
      if (r.gender == 'M') {
        cl[1]++;
      } else if (r.gender == 'F') {
        cl[2]++;
      }
    }

    // Par filière (lycée/FP) — uniquement si la classe est reliée à une filière.
    final fl = r.filiereLabel;
    if (fl != null && fl.isNotEmpty) {
      final pg = progMap.putIfAbsent(fl, () => [0, 0, 0]);
      pg[0]++;
      if (r.gender == 'M') {
        pg[1]++;
      } else if (r.gender == 'F') {
        pg[2]++;
      }
    }

    final d = r.enrollmentDate;
    if (d != null) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthCount[key] = (monthCount[key] ?? 0) + 1;
    }
  }

  final byCycle = cycleMap.entries
      .map((e) => CycleCount(cycleObj[e.key]!, e.value[0], e.value[1], e.value[2]))
      .toList()
    ..sort((a, b) => a.cycle.order.compareTo(b.cycle.order));

  final byLevel = levelMap.entries
      .map((e) => LevelCount(e.key, levelCycle[e.key] ?? 'autre', e.value[3],
          e.value[0], e.value[1], e.value[2]))
      .toList()
    ..sort((a, b) {
      final c = cycleOrderOf(a.cycleCode).compareTo(cycleOrderOf(b.cycleCode));
      return c != 0 ? c : a.order.compareTo(b.order);
    });

  final byClass = classMap.entries
      .map((e) => ClassCount(e.key, classCycle[e.key] ?? 'autre',
          classLevel[e.key], e.value[3], e.value[4], e.value[0], e.value[1],
          e.value[2]))
      .toList()
    ..sort((a, b) {
      final c = cycleOrderOf(a.cycleCode).compareTo(cycleOrderOf(b.cycleCode));
      if (c != 0) return c;
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  final byProgram = progMap.entries
      .map((e) => ProgramCount(e.key, e.value[0], e.value[1], e.value[2]))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  // Évolution par mois (croissant) : rythme (du mois) + cumul.
  final months = monthCount.keys.toList()..sort();
  var cumul = 0;
  final evolution = <EnrollPoint>[];
  for (final m in months) {
    final c = monthCount[m]!;
    cumul += c;
    final parts = m.split('-');
    evolution.add(EnrollPoint('${parts[1]}/${parts[0]}', c, cumul));
  }

  return InscriptionStats(
    total: active + pending, // dossiers vivants (hors rejet)
    active: active,
    pending: pending,
    rejected: rejected,
    boys: boys,
    girls: girls,
    typeNew: tNew,
    reinscription: tRe,
    transfer: tTr,
    repeating: repeating,
    byCycle: byCycle,
    byLevel: byLevel,
    byClass: byClass,
    byProgram: byProgram,
    capacityTotal:
        structure.classes.fold<int>(0, (s, c) => s + c.capacity),
    evolution: evolution,
  );
});
