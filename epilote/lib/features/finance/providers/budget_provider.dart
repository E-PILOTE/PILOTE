import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import 'depenses_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  BUDGET (table `budget_lines`, SENSIBLE — gatée par `sync_finance`). Lignes
//  budgétaires : on saisit le « prévu » (budgeted) par poste ; le « réalisé »
//  est DÉRIVÉ du grand-livre des Dépenses (poste à poste, slug commun) — jamais
//  saisi à la main, pour que prévu/réalisé ne divergent pas. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

/// Postes budgétaires = taxonomie CANONIQUE des dépenses (slugs partagés).
const kBudgetCategories = kExpenseCategories;

/// Libellé d'un poste (slug → libellé), aligné sur les Dépenses.
String budgetCategoryLabel(String? slug) => expenseCategoryLabel(slug);

class BudgetLine {
  const BudgetLine({
    required this.id,
    required this.category,
    required this.budgeted,
    required this.actual,
    required this.notes,
  });
  final String id, category;
  final int budgeted;

  /// Réalisé dérivé des Dépenses (injecté par `budgetLinesProvider`).
  final int actual;
  final String? notes;

  String get categoryLabel => budgetCategoryLabel(category);
  int get remaining => budgeted - actual;
  double get rate => budgeted == 0 ? 0 : actual / budgeted;
  bool get overBudget => actual > budgeted;

  BudgetLine withActual(int a) => BudgetLine(
        id: id, category: category, budgeted: budgeted, actual: a, notes: notes);
}

final budgetLinesProvider = StreamProvider.autoDispose<List<BudgetLine>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  // Réalisé = dépenses réelles par poste (dépendance Dépenses → Budget).
  final byCat = ref.watch(expensesByCategoryProvider).valueOrNull ?? const {};
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    'SELECT * FROM budget_lines WHERE school_id = ? AND academic_year_id = ? '
    'ORDER BY budgeted_amount_xaf DESC',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          BudgetLine(
            id: r['id'] as String,
            category: (r['category'] as String?) ?? 'autre',
            budgeted: (r['budgeted_amount_xaf'] as num?)?.round() ?? 0,
            actual: byCat[(r['category'] as String?) ?? 'autre'] ?? 0,
            notes: r['notes'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> saveBudgetLine({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String category,
  required int budgeted,
  String? notes,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    // On ne touche pas à actual_amount_xaf : le réalisé vient des Dépenses.
    await db.execute(
      'UPDATE budget_lines SET category = ?, budgeted_amount_xaf = ?, '
      'notes = ?, updated_at = ? WHERE id = ?',
      [category, budgeted, notes, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO budget_lines (
        id, group_id, school_id, academic_year_id, category,
        budgeted_amount_xaf, actual_amount_xaf, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, academicYearId, category, budgeted,
       notes, now, now],
    );
  }
}

Future<void> deleteBudgetLine(String id) async {
  await db.execute('DELETE FROM budget_lines WHERE id = ?', [id]);
}
