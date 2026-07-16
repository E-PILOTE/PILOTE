import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../providers/depenses_provider.dart';

part 'depenses_form.dart';

const _kSlug = 'depenses';

// ════════════════════════════════════════════════════════════════════════════
//  DÉPENSES — registre des dépenses (sensible). KPI hero → répartition par
//  catégorie → barre (recherche + catégorie + Nouvelle) → liste. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class DepensesScreen extends ConsumerWidget {
  const DepensesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Dépenses',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Expense> _apply(List<Expense> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((e) {
      if (_category != null && e.category != _category) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          (e.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({Expense? expense}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ExpenseForm(expense: expense),
      );

  Future<void> _delete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette dépense ?'),
        content: Text('« ${e.title} » (${fmtXaf(e.amount)}) sera supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteExpense(e.id),
        success: 'Dépense supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expensesProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);
    final month = DateTime.now().toIso8601String().substring(0, 7);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        final filtered = _apply(all);
        final total = all.fold(0, (a, e) => a + e.amount);
        final thisMonth = all
            .where((e) => (e.date ?? '').startsWith(month))
            .fold(0, (a, e) => a + e.amount);
        // Répartition par catégorie.
        final byCat = <String, int>{};
        for (final e in all) {
          byCat[e.category ?? 'autre'] =
              (byCat[e.category ?? 'autre'] ?? 0) + e.amount;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Registre des dépenses',
              subtitle: 'Dépenses de fonctionnement — année en cours',
              trailing: (canCreate && !readOnly)
                  ? _AddBtn(label: 'Dépense', onTap: () => _openForm())
                  : null,
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.trending_down_rounded, 'Total dépenses', fmtCompact(total),
                  kRed, 'FCFA cette année'),
              (Icons.calendar_month_rounded, 'Ce mois', fmtCompact(thisMonth),
                  const Color(0xFFF59E0B), 'FCFA'),
              (Icons.receipt_long_rounded, 'Nombre', '${all.length}', kNavy,
                  'opérations'),
              (Icons.pie_chart_rounded, 'Catégories', '${byCat.length}',
                  const Color(0xFF8B5CF6), 'postes'),
            ]),
            if (byCat.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CategoryBreakdown(byCat: byCat, total: total),
            ],
            const SizedBox(height: 22),
            _FilterBar(
              search: _search,
              category: _category,
              canCreate: canCreate && !readOnly,
              onSearch: (_) => setState(() {}),
              onCategory: (v) => setState(() => _category = v),
              onReset: () => setState(() {
                _search.clear();
                _category = null;
              }),
              onAdd: () => _openForm(),
            ),
            const SizedBox(height: 16),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.trending_down_rounded,
                  title: 'Aucune dépense',
                  message:
                      'Enregistrez les dépenses de fonctionnement pour suivre '
                      'le budget de l\'école.',
                  actionLabel:
                      (canCreate && !readOnly) ? 'Nouvelle dépense' : null,
                  onAction: (canCreate && !readOnly) ? () => _openForm() : null,
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Aucun résultat',
                  message: 'Ajustez la recherche ou le filtre.',
                ),
              )
            else
              for (final e in filtered)
                _ExpenseCard(
                  expense: e,
                  canEdit: canEdit && !readOnly,
                  canDelete: canDelete && !readOnly,
                  onEdit: () => _openForm(expense: e),
                  onDelete: () => _delete(e),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ─── Répartition par catégorie (barre empilée) ───────────────────────────────
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.byCat, required this.total});
  final Map<String, int> byCat;
  final int total;
  static List<Color> get _colors => [
    const Color(0xFF0EA5E9), kGreen, const Color(0xFFF59E0B), const Color(0xFF8B5CF6),
    const Color(0xFFEC4899), kNavy, kTextMuted,
  ];
  @override
  Widget build(BuildContext context) {
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pie_chart_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Text('Répartition par catégorie',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            for (var i = 0; i < entries.length; i++)
              Expanded(
                flex: entries[i].value,
                child: Container(
                    height: 12, color: _colors[i % _colors.length]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          for (var i = 0; i < entries.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _colors[i % _colors.length],
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text(
                  '${expenseCategoryLabel(entries[i].key)} · ${fmtXaf(entries[i].value)}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ]),
        ]),
      ]),
    );
  }
}

// ─── Barre de filtres ────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.category,
    required this.canCreate,
    required this.onSearch,
    required this.onCategory,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController search;
  final String? category;
  final bool canCreate;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategory;
  final VoidCallback onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: search,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher une dépense…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String?>(
            initialValue: category,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: kSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('Catégorie', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Catégorie : toutes')),
              for (final (v, l) in kExpenseCategories)
                DropdownMenuItem(value: v, child: Text(l)),
            ],
            onChanged: onCategory,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Réinitialiser',
          onPressed: onReset,
          icon: Icon(Icons.filter_alt_off_outlined, color: kTextMuted),
        ),
        const SizedBox(width: 4),
        if (canCreate) _AddBtn(label: 'Dépense', onTap: onAdd),
      ]),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final Expense expense;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final e = expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.trending_down_rounded, size: 20, color: kRed),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: kNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(expenseCategoryLabel(e.category),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                    '${e.date ?? '—'}'
                    '${(e.description ?? '').isNotEmpty ? ' · ${e.description}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
        ),
        Text(fmtXaf(e.amount),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kRed)),
        if (canEdit || canDelete)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (ctx) => [
              if (canEdit)
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ])),
              if (canDelete)
                PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                      const SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: kRed)),
                    ])),
            ],
          )
        else
          const SizedBox(width: 12),
      ]),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
