import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  DÉPENSES (table `expenses`, SENSIBLE — gatée par `sync_finance`). Dépenses de
//  fonctionnement de l'école : intitulé, montant, date, catégorie. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

// Taxonomie CANONIQUE des postes de dépense — partagée avec le Budget
// (`kBudgetCategories` la réexporte) pour que « prévu » (Budget) et « réalisé »
// (Dépenses) se rapprochent poste à poste. Tout décaissement passe par ici,
// y compris Personnel (salaires) et Investissement (capex).
const kExpenseCategories = <(String, String)>[
  ('personnel', 'Personnel'),
  ('fournitures', 'Fournitures'),
  ('equipement', 'Équipement'),
  ('maintenance', 'Maintenance'),
  ('services', 'Services (eau, élec., internet)'),
  ('transport', 'Transport'),
  ('evenements', 'Événements'),
  ('investissement', 'Investissement'),
  ('autre', 'Autre'),
];

String expenseCategoryLabel(String? c) => kExpenseCategories
    .firstWhere((e) => e.$1 == c, orElse: () => ('autre', 'Autre'))
    .$2;

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
  });
  final String id, title;
  final String? description, date, category;
  final int amount;
}

final expensesProvider = StreamProvider.autoDispose<List<Expense>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    'SELECT * FROM expenses WHERE school_id = ? AND academic_year_id = ? '
    'ORDER BY expense_date DESC, created_at DESC',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          Expense(
            id: r['id'] as String,
            title: (r['title'] as String?) ?? '—',
            description: r['description'] as String?,
            amount: (r['amount_xaf'] as num?)?.round() ?? 0,
            date: r['expense_date'] as String?,
            category: r['category'] as String?,
          ),
      ]);
});

/// Total des dépenses réelles par poste (slug → FCFA) pour l'année active.
/// Source du « réalisé » du Budget (dépendance Dépenses → Budget).
final expensesByCategoryProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) {
    return Stream.value(const <String, int>{});
  }
  return db.watch(
    'SELECT category, SUM(amount_xaf) AS total FROM expenses '
    'WHERE school_id = ? AND academic_year_id = ? GROUP BY category',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => {
        for (final r in rows)
          (r['category'] as String?) ?? 'autre':
              (r['total'] as num?)?.round() ?? 0,
      });
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> saveExpense({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String title,
  String? description,
  required int amount,
  required String date,
  required String category,
  required String createdBy,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE expenses SET title = ?, description = ?, amount_xaf = ?, '
      'expense_date = ?, category = ?, updated_at = ? WHERE id = ?',
      [title, description, amount, date, category, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO expenses (
        id, group_id, school_id, academic_year_id, title, description,
        amount_xaf, expense_date, category, created_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, academicYearId, title, description,
       amount, date, category, createdBy, now, now],
    );
  }
}

Future<void> deleteExpense(String id) async {
  await db.execute('DELETE FROM expenses WHERE id = ?', [id]);
}
