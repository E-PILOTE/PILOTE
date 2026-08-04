import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS DE SCOLARITÉ (table `fee_structures`) — barèmes de frais (inscription,
//  mensualité, examens, autre) avec montant XAF, jour d'échéance et niveau
//  concerné (optionnel = toute l'école). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kFeeTypes = <(String, String)>[
  ('inscription', 'Inscription'),
  ('mensualite', 'Mensualité'),
  ('frais_examens', 'Frais d\'examens'),
  ('autre', 'Autre'),
];

String feeTypeLabel(String? t) =>
    kFeeTypes.firstWhere((e) => e.$1 == t, orElse: () => ('autre', 'Autre')).$2;

class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.dueDay,
    required this.levelId,
    required this.levelName,
  });
  final String id, name, feeType;
  final int amount;
  final int? dueDay;
  final String? levelId, levelName;
}

final feeStructuresProvider =
    StreamProvider.autoDispose<List<FeeStructure>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT f.*, sl.name AS level_name
    FROM fee_structures f
    LEFT JOIN school_levels sl ON sl.id = f.applies_to_level_id
    -- ⚠️ `is_active = 1` rate les lignes écrites par l'application : la vue
    -- PowerSync ne garantit pas l'entier 1. COALESCE(...) <> 0 est la forme
    -- sûre (cf. [[powersync-is-active-egalite-stricte]]).
    WHERE f.school_id = ? AND f.academic_year_id = ?
      AND COALESCE(f.is_active, 1) <> 0
    ORDER BY f.fee_type, f.amount_xaf DESC
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          FeeStructure(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '—',
            feeType: (r['fee_type'] as String?) ?? 'autre',
            amount: (r['amount_xaf'] as num?)?.round() ?? 0,
            dueDay: (r['due_day_of_month'] as num?)?.round(),
            levelId: r['applies_to_level_id'] as String?,
            levelName: r['level_name'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> saveFeeStructure({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String name,
  required String feeType,
  required int amount,
  int? dueDay,
  String? levelId,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE fee_structures SET name = ?, fee_type = ?, amount_xaf = ?, '
      'due_day_of_month = ?, applies_to_level_id = ?, updated_at = ? WHERE id = ?',
      [name, feeType, amount, dueDay, levelId, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO fee_structures (
        id, group_id, school_id, academic_year_id, name, fee_type, amount_xaf,
        due_day_of_month, applies_to_level_id, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, academicYearId, name, feeType, amount,
       dueDay, levelId, now, now],
    );
  }
}

/// Soft delete (is_active=0 → retiré du bucket de synchro).
Future<void> deleteFeeStructure(String id) async {
  await db.execute(
    'UPDATE fee_structures SET is_active = 0, updated_at = ? WHERE id = ?',
    [DateTime.now().toIso8601String(), id],
  );
}

/// Niveaux distincts utilisés par l'école (pour le champ « niveau concerné »).
final schoolLevelOptionsProvider =
    StreamProvider.autoDispose<List<({String id, String name})>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT DISTINCT c.level_id AS id, COALESCE(sl.name, c.level_code) AS name,
           c.level_order AS ord
    FROM classes c
    LEFT JOIN school_levels sl ON sl.id = c.level_id
    WHERE c.school_id = ? AND c.academic_year_id = ? AND c.level_id IS NOT NULL
    ORDER BY c.level_order
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          (id: r['id'] as String, name: (r['name'] as String?) ?? '—'),
      ]);
});
