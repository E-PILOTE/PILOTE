import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/biblio_provider.dart';
import '../providers/vs_students_provider.dart';
import '../widgets/vs_kit.dart';
import '../widgets/vs_form_chrome.dart';
import '../widgets/vs_student_field.dart';
import '../../../core/utils/erreur_metier.dart';

part 'biblio_forms.dart';
part 'biblio_cards.dart';

const _kSlug = kSlugBibliotheque;

// ════════════════════════════════════════════════════════════════════════════
//  BIBLIOTHÈQUE — catalogue + emprunts. KPI hero → segments Catalogue / Emprunts.
//  Catalogue : ouvrages (CRUD, disponibilité). Emprunts : prêts (nouveau prêt,
//  retour, retards). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class BibliothequeScreen extends ConsumerWidget {
  const BibliothequeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Bibliothèque',
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
  int _tab = 0; // 0 = catalogue, 1 = emprunts
  bool _activeOnly = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openItemForm({LibraryItem? item}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ItemForm(item: item),
      );

  void _openLoanForm() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LoanForm(),
      );

  Future<void> _deleteItem(LibraryItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer cet ouvrage ?'),
        content: Text('« ${it.title} » sera retiré du catalogue '
            '(l\'historique des prêts est conservé).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteItem(it.id),
        success: 'Ouvrage retiré');
  }

  Future<void> _return(LibraryLoan l) async {
    await runModuleWrite(context, () => returnLoan(l),
        success: 'Retour enregistré');
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final loans = ref.watch(libraryLoansProvider).valueOrNull ?? const [];
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    final titles = items.length;
    final copies = items.fold(0, (a, i) => a + i.quantity);
    final borrowed = loans.where((l) => !l.returned).length;
    final overdue = loans.where((l) => l.overdue).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Bibliothèque scolaire',
          subtitle: 'Catalogue des ouvrages et gestion des prêts',
          trailing: _Segments(
              tab: _tab, onChange: (t) => setState(() => _tab = t)),
        ),
        const SizedBox(height: 20),
        VsHeroKpis(cards: [
          (Icons.menu_book_rounded, 'Titres', '$titles', kNavy, 'au catalogue'),
          (Icons.collections_bookmark_rounded, 'Exemplaires', '$copies',
              const Color(0xFF0EA5E9), null),
          (Icons.book_rounded, 'Empruntés', '$borrowed',
              borrowed == 0 ? kTextMuted : const Color(0xFFF59E0B), 'en cours'),
          (Icons.warning_amber_rounded, 'En retard', '$overdue',
              overdue == 0 ? kTextMuted : kRed, 'à relancer'),
        ]),
        const SizedBox(height: 18),
        if (_tab == 0)
          _catalogue(items, canCreate && !readOnly, canEdit && !readOnly,
              canDelete && !readOnly)
        else
          _emprunts(loans, canCreate && !readOnly, canEdit && !readOnly),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ─── Vue Catalogue ─────────────────────────────────────────────────────────
  Widget _catalogue(
      List<LibraryItem> items, bool canCreate, bool canEdit, bool canDelete) {
    final q = _search.text.trim().toLowerCase();
    final filtered = [
      for (final it in items)
        if (q.isEmpty ||
            it.title.toLowerCase().contains(q) ||
            (it.author ?? '').toLowerCase().contains(q) ||
            (it.category ?? '').toLowerCase().contains(q))
          it,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _searchBar('Rechercher (titre, auteur, catégorie)…', canCreate,
          'Ouvrage', _openItemForm),
      const SizedBox(height: 16),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AdminEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Catalogue vide',
            message: 'Ajoutez des ouvrages pour constituer le fonds de la '
                'bibliothèque et gérer les prêts.',
            actionLabel: canCreate ? 'Nouvel ouvrage' : null,
            onAction: canCreate ? () => _openItemForm() : null,
          ),
        )
      else if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 30),
          child: AdminEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Aucun résultat',
            message: 'Ajustez la recherche.',
          ),
        )
      else
        LayoutBuilder(builder: (ctx, cns) {
          final cols = cns.maxWidth >= 1180 ? 3 : (cns.maxWidth >= 760 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 132,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _ItemCard(
              item: filtered[i],
              canEdit: canEdit,
              canDelete: canDelete,
              onEdit: () => _openItemForm(item: filtered[i]),
              onDelete: () => _deleteItem(filtered[i]),
            ),
          );
        }),
    ]);
  }

  // ─── Vue Emprunts ──────────────────────────────────────────────────────────
  Widget _emprunts(List<LibraryLoan> loans, bool canCreate, bool canEdit) {
    final list = [
      for (final l in loans)
        if (!_activeOnly || !l.returned) l,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          _filterChip('En cours', _activeOnly,
              () => setState(() => _activeOnly = true)),
          const SizedBox(width: 8),
          _filterChip('Tous', !_activeOnly,
              () => setState(() => _activeOnly = false)),
          const Spacer(),
          if (canCreate) _addButton('Nouveau prêt', _openLoanForm),
        ]),
      ),
      const SizedBox(height: 16),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AdminEmptyState(
            icon: Icons.book_outlined,
            title: _activeOnly ? 'Aucun prêt en cours' : 'Aucun prêt',
            message: 'Enregistrez un prêt depuis le catalogue ou ici.',
            actionLabel: canCreate ? 'Nouveau prêt' : null,
            onAction: canCreate ? _openLoanForm : null,
          ),
        )
      else
        for (final l in list)
          _LoanCard(loan: l, canEdit: canEdit, onReturn: () => _return(l)),
    ]);
  }

  // ─── Sous-widgets locaux ───────────────────────────────────────────────────
  Widget _searchBar(
      String hint, bool canAdd, String addLabel, VoidCallback onAdd) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
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
        if (canAdd) _addButton(addLabel, onAdd),
      ]),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) => MouseRegion(
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

  Widget _filterChip(String label, bool sel, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? kNavy : kBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
}

// ─── Segments Catalogue / Emprunts ───────────────────────────────────────────
class _Segments extends StatelessWidget {
  const _Segments({required this.tab, required this.onChange});
  final int tab;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) {
    Widget seg(int i, IconData ic, String label) {
      final sel = tab == i;
      return InkWell(
        onTap: () => onChange(i),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 15, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : kTextMuted)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(0, Icons.menu_book_rounded, 'Catalogue'),
        seg(1, Icons.swap_horiz_rounded, 'Emprunts'),
      ]),
    );
  }
}

