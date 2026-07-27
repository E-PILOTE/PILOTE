import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════
// Système éducatif — République du Congo
// Hiérarchie : Cycle └── Programme (filière, si applicable) └── Niveau
//
// Référentiel global (group_id null) commun à tous les groupes
//   + personnalisations propres au groupe (group_id défini) gérées par
//     l'admin_groupe (filières/niveaux supplémentaires).
//
// Règle d'or : aucune valeur codée en dur dans l'UI — tout vient de la base.
// ════════════════════════════════════════════════════════════════════════

// ─── Modèles ──────────────────────────────────────────────────────────────
class EducationCycle {
  const EducationCycle({
    required this.id,
    required this.code,
    required this.name,
    required this.orderIndex,
    required this.hasPrograms,
    required this.isActive,
    this.description,
    this.groupId,
  });

  factory EducationCycle.fromRow(Map<String, dynamic> r) => EducationCycle(
        id:          r['id'] as String,
        code:        r['code'] as String? ?? '',
        name:        r['name'] as String? ?? '—',
        description: r['description'] as String?,
        orderIndex:  (r['order_index'] as int?) ?? 0,
        hasPrograms: r['has_programs'] as bool? ?? false,
        groupId:     r['group_id'] as String?,
        isActive:    r['is_active'] as bool? ?? true,
      );

  final String id;
  final String code;
  final String name;
  final String? description;
  final int orderIndex;
  final bool hasPrograms;
  final String? groupId; // null => référentiel global
  final bool isActive;

  bool get isCustom => groupId != null;
}

class EducationProgram {
  const EducationProgram({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.orderIndex,
    required this.isActive,
    this.code,
    this.description,
    this.groupId,
  });

  factory EducationProgram.fromRow(Map<String, dynamic> r) => EducationProgram(
        id:          r['id'] as String,
        cycleId:     r['cycle_id'] as String,
        code:        r['code'] as String?,
        name:        r['name'] as String? ?? '—',
        description: r['description'] as String?,
        orderIndex:  (r['order_index'] as int?) ?? 0,
        groupId:     r['group_id'] as String?,
        isActive:    r['is_active'] as bool? ?? true,
      );

  final String id;
  final String cycleId;
  final String? code;
  final String name;
  final String? description;
  final int orderIndex;
  final String? groupId;
  final bool isActive;

  bool get isCustom => groupId != null;
}

class EducationLevel {
  const EducationLevel({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.orderIndex,
    required this.isActive,
    this.programId,
    this.code,
    this.groupId,
  });

  factory EducationLevel.fromRow(Map<String, dynamic> r) => EducationLevel(
        id:         r['id'] as String,
        cycleId:    r['cycle_id'] as String,
        programId:  r['program_id'] as String?,
        code:       r['code'] as String?,
        name:       r['name'] as String? ?? '—',
        orderIndex: (r['order_index'] as int?) ?? 0,
        groupId:    r['group_id'] as String?,
        isActive:   r['is_active'] as bool? ?? true,
      );

  final String id;
  final String cycleId;
  final String? programId; // null => niveau général (non lié à une filière)
  final String? code;
  final String name;
  final int orderIndex;
  final String? groupId;
  final bool isActive;

  bool get isCustom => groupId != null;
}

// ─── Catalogue complet (référentiel) ───────────────────────────────────────
class EducationCatalog {
  const EducationCatalog({
    required this.cycles,
    required this.programs,
    required this.levels,
  });

  final List<EducationCycle> cycles;
  final List<EducationProgram> programs;
  final List<EducationLevel> levels;

  static const empty =
      EducationCatalog(cycles: [], programs: [], levels: []);

  /// Cycles actifs, triés.
  List<EducationCycle> get activeCycles =>
      cycles.where((c) => c.isActive).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  EducationCycle? cycleById(String id) {
    for (final c in cycles) {
      if (c.id == id) return c;
    }
    return null;
  }

  EducationProgram? programById(String id) {
    for (final p in programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Filières d'un cycle (toutes), triées.
  List<EducationProgram> programsOf(String cycleId) =>
      programs.where((p) => p.cycleId == cycleId).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  /// Filières actives d'un cycle.
  List<EducationProgram> activeProgramsOf(String cycleId) =>
      programsOf(cycleId).where((p) => p.isActive).toList();

  /// Niveaux généraux d'un cycle (sans filière), triés.
  List<EducationLevel> generalLevelsOf(String cycleId) =>
      levels
          .where((l) => l.cycleId == cycleId && l.programId == null)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  /// Niveaux actifs généraux d'un cycle.
  List<EducationLevel> activeGeneralLevelsOf(String cycleId) =>
      generalLevelsOf(cycleId).where((l) => l.isActive).toList();

  /// Niveaux d'une filière, triés.
  List<EducationLevel> levelsOfProgram(String programId) =>
      levels.where((l) => l.programId == programId).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  /// Niveaux actifs d'une filière.
  List<EducationLevel> activeLevelsOfProgram(String programId) =>
      levelsOfProgram(programId).where((l) => l.isActive).toList();
}

// ─── Provider : catalogue (global + groupe) ─────────────────────────────────
// La RLS renvoie automatiquement les lignes globales (group_id null) + celles
// du groupe courant. On garde tout (actif/inactif) : l'UI filtre selon besoin.
final educationCatalogProvider =
    FutureProvider.autoDispose<EducationCatalog>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  try {
    final cyc = await client
        .from('education_cycles')
        .select('id, code, name, description, order_index, has_programs, group_id, is_active')
        .order('order_index', ascending: true) as List;
    final pro = await client
        .from('education_programs')
        .select('id, cycle_id, code, name, description, order_index, group_id, is_active')
        .order('order_index', ascending: true) as List;
    final lvl = await client
        .from('education_levels')
        .select('id, cycle_id, program_id, code, name, order_index, group_id, is_active')
        .order('order_index', ascending: true) as List;

    return EducationCatalog(
      cycles:   [for (final r in cyc) EducationCycle.fromRow(r as Map<String, dynamic>)],
      programs: [for (final r in pro) EducationProgram.fromRow(r as Map<String, dynamic>)],
      levels:   [for (final r in lvl) EducationLevel.fromRow(r as Map<String, dynamic>)],
    );
  } catch (_) {
    return EducationCatalog.empty;
  }
});

// ─── Sélection d'une école ──────────────────────────────────────────────────
class SchoolEducationSelection {
  const SchoolEducationSelection({
    required this.cycleIds,
    required this.programIds,
    required this.levelIds,
  });

  final Set<String> cycleIds;
  final Set<String> programIds;
  final Set<String> levelIds;

  static const empty = SchoolEducationSelection(
      cycleIds: {}, programIds: {}, levelIds: {});
}

// Sélections enregistrées pour une école (vide si école pas encore créée).
final schoolEducationProvider = FutureProvider.autoDispose
    .family<SchoolEducationSelection, String>((ref, schoolId) async {
  ref.keepAlive();
  if (schoolId.isEmpty) return SchoolEducationSelection.empty;
  final client = ref.watch(supabaseClientProvider);
  try {
    final cyc = await client
        .from('school_cycles')
        .select('cycle_id')
        .eq('school_id', schoolId) as List;
    final pro = await client
        .from('school_education_programs')
        .select('program_id')
        .eq('school_id', schoolId) as List;
    final lvl = await client
        .from('school_education_levels')
        .select('level_id')
        .eq('school_id', schoolId) as List;
    return SchoolEducationSelection(
      cycleIds:   {for (final r in cyc) r['cycle_id'] as String},
      programIds: {for (final r in pro) r['program_id'] as String},
      levelIds:   {for (final r in lvl) r['level_id'] as String},
    );
  } catch (_) {
    return SchoolEducationSelection.empty;
  }
});

// ─── Service (mutations) ────────────────────────────────────────────────────
class EducationService {
  EducationService(this._ref);
  final Ref _ref;

  String? get _groupId =>
      _ref.read(authNotifierProvider).valueOrNull?.groupId;

  /// Remplace l'offre éducative d'une école (cycles / filières / niveaux).
  Future<void> saveSchoolEducation({
    required String schoolId,
    required Set<String> cycleIds,
    required Set<String> programIds,
    required Set<String> levelIds,
  }) async {
    final groupId = _groupId;
    if (groupId == null) throw Exception('Groupe introuvable');
    final c = _ref.read(supabaseClientProvider);

    // Stratégie « delete + insert » : simple et idempotent (la RLS borne au groupe).
    await c.from('school_cycles').delete().eq('school_id', schoolId);
    await c.from('school_education_programs').delete().eq('school_id', schoolId);
    await c.from('school_education_levels').delete().eq('school_id', schoolId);

    if (cycleIds.isNotEmpty) {
      await c.from('school_cycles').insert([
        for (final id in cycleIds)
          {'school_id': schoolId, 'cycle_id': id, 'group_id': groupId},
      ]);
    }
    if (programIds.isNotEmpty) {
      await c.from('school_education_programs').insert([
        for (final id in programIds)
          {'school_id': schoolId, 'program_id': id, 'group_id': groupId},
      ]);
    }
    if (levelIds.isNotEmpty) {
      await c.from('school_education_levels').insert([
        for (final id in levelIds)
          {'school_id': schoolId, 'level_id': id, 'group_id': groupId},
      ]);
    }

    _ref.invalidate(schoolEducationProvider(schoolId));
  }

  // ─── Gestion dynamique du référentiel (lignes propres au groupe) ──────────

  /// Crée une filière personnalisée pour le groupe ; renvoie son id.
  Future<String> createProgram({
    required String cycleId,
    required String name,
    String? description,
    int orderIndex = 900,
  }) async {
    final groupId = _groupId;
    if (groupId == null) throw Exception('Groupe introuvable');
    final row = await _ref
        .read(supabaseClientProvider)
        .from('education_programs')
        .insert({
          'cycle_id': cycleId,
          'name': name,
          'description': ?description,
          'order_index': orderIndex,
          'group_id': groupId,
          'is_active': true,
        })
        .select('id')
        .single();
    _ref.invalidate(educationCatalogProvider);
    return row['id'] as String;
  }

  /// Modifie une filière (uniquement les filières propres au groupe — la RLS
  /// interdit la modification des lignes globales).
  Future<void> updateProgram({
    required String id,
    required String name,
    String? description,
  }) async {
    await _ref.read(supabaseClientProvider).from('education_programs').update({
      'name': name,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(educationCatalogProvider);
  }

  /// Active / désactive une filière propre au groupe.
  Future<void> setProgramActive(String id, bool active) async {
    await _ref.read(supabaseClientProvider).from('education_programs').update({
      'is_active': active,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(educationCatalogProvider);
  }

  /// Ajoute un niveau personnalisé (général au cycle, ou rattaché à une
  /// filière) ; renvoie son id.
  Future<String> createLevel({
    required String cycleId,
    String? programId,
    required String name,
    int orderIndex = 900,
  }) async {
    final groupId = _groupId;
    if (groupId == null) throw Exception('Groupe introuvable');
    final row = await _ref
        .read(supabaseClientProvider)
        .from('education_levels')
        .insert({
          'cycle_id': cycleId,
          'program_id': ?programId,
          'name': name,
          'order_index': orderIndex,
          'group_id': groupId,
          'is_active': true,
        })
        .select('id')
        .single();
    _ref.invalidate(educationCatalogProvider);
    return row['id'] as String;
  }

  /// Active / désactive un niveau propre au groupe.
  Future<void> setLevelActive(String id, bool active) async {
    await _ref.read(supabaseClientProvider).from('education_levels').update({
      'is_active': active,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(educationCatalogProvider);
  }
}

final educationServiceProvider =
    Provider<EducationService>((ref) => EducationService(ref));
