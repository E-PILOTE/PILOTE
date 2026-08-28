import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import 'depenses_provider.dart';
import '../../../core/utils/erreur_metier.dart';

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

  // ⚠️ UN POSTE, UNE LIGNE. Le réalisé d'une ligne est le total des dépenses de
  // SA CATÉGORIE : deux lignes sur le même poste affichent donc toutes deux la
  // même dépense, et le total « Réalisé » de l'écran la compte deux fois. Le
  // poste se choisit dans une liste fermée — rien n'empêchait d'en reprendre
  // un déjà budgété, et le budget se mettait alors à mentir sans qu'aucune
  // ligne soit fausse prise isolément.
  //
  // Aucune contrainte en base ne l'attrape : ce garde est le seul.
  final doublon = await db.getAll(
    'SELECT id FROM budget_lines WHERE school_id = ? AND academic_year_id = ? '
    'AND category = ? LIMIT 1',
    [schoolId, academicYearId, category],
  );
  if (doublon.isNotEmpty && (id == null || doublon.first['id'] != id)) {
    throw const ErreurMetier(
        'Ce poste a déjà une ligne budgétaire cette année. Modifiez-la '
        'plutôt que d\'en créer une seconde : le réalisé serait compté deux '
        'fois.');
  }

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
      // Un poste par année : deux postes hors ligne qui budgètent « Personnel »
      // le même jour écrivent la MÊME ligne au lieu d'en créer deux.
      [idDeterministe('budget_line', [schoolId, academicYearId, category]),
       groupId, schoolId, academicYearId, category, budgeted,
       notes, now, now],
    );
  }
}

/// Le réalisé VRAI de l'année, et la part qui n'a pas de poste au budget.
///
/// ⚠️ L'écran totalisait le réalisé en additionnant les LIGNES du budget. Deux
/// conséquences, opposées et simultanées :
///   • une dépense sur un poste non budgété n'apparaissait NULLE PART — le
///     « Réalisé » annonçait moins que ce que l'école avait sorti de caisse ;
///   • deux lignes sur un même poste la comptaient deux fois.
/// Le réalisé se lit donc à sa source, les dépenses ; les lignes ne servent
/// qu'à le répartir.
final budgetReelProvider =
    Provider.autoDispose<({int total, int horsBudget})>((ref) {
  final byCat = ref.watch(expensesByCategoryProvider).valueOrNull ?? const {};
  final lignes = ref.watch(budgetLinesProvider).valueOrNull ?? const [];
  final postesBudgetes = {for (final l in lignes) l.category};
  var total = 0;
  var hors = 0;
  for (final e in byCat.entries) {
    total += e.value;
    if (!postesBudgetes.contains(e.key)) hors += e.value;
  }
  return (total: total, horsBudget: hors);
});

Future<void> deleteBudgetLine(String id) async {
  await db.execute('DELETE FROM budget_lines WHERE id = ?', [id]);
}
