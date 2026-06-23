part of 'subjects_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Matières : répartition par coefficient, barre de filtres,
//  table, cartes, formulaire création/édition.
// ════════════════════════════════════════════════════════════════════════════

// ─── Répartition par coefficient (barres maison, sans dépendance) ────────────
class _CoefDistribution extends StatelessWidget {
  const _CoefDistribution({required this.subjects});
  final List<SubjectModel> subjects;

  @override
  Widget build(BuildContext context) {
    final byCoef = <int, int>{};
    for (final s in subjects) {
      byCoef[s.coefficient] = (byCoef[s.coefficient] ?? 0) + 1;
    }
    final coefs = byCoef.keys.toList()..sort();
    final maxN = byCoef.values.fold(0, (a, b) => a > b ? a : b);

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final c in coefs)
              Expanded(
                child: _CoefBar(
                  coef: c,
                  count: byCoef[c]!,
                  ratio: maxN == 0 ? 0 : byCoef[c]! / maxN,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoefBar extends StatelessWidget {
  const _CoefBar(
      {required this.coef, required this.count, required this.ratio});
  final int coef, count;
  final double ratio;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$count',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Container(
              height: (ratio * 90).clamp(4, 90),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kNavy, Color(0xFF2E5288)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('coef. $coef',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ],
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _SubjectFilterBar extends StatelessWidget {
  const _SubjectFilterBar({
    required this.searchCtrl,
    required this.isTable,
    required this.sort,
    required this.sortAsc,
    required this.onSearch,
    required this.onSort,
    required this.onToggleView,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final bool isTable, sortAsc;
  final String sort;
  final ValueChanged<String> onSearch, onSort;
  final VoidCallback onToggleView, onAdd;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher une matière',
                      icon: Icons.search_rounded),
                ),
              ),
              _SortChip(
                  label: 'Nom',
                  active: sort == 'name',
                  asc: sortAsc,
                  onTap: () => onSort('name')),
              _SortChip(
                  label: 'Coefficient',
                  active: sort == 'coef',
                  asc: sortAsc,
                  onTap: () => onSort('coef')),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onToggleView,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    isTable
                        ? Icons.grid_view_rounded
                        : Icons.table_rows_rounded,
                    size: 16,
                    color: kNavy),
                const SizedBox(width: 7),
                Text(isTable ? 'Cartes' : 'Table',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kNavy)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PermissionGate(
          slug: _kSlug,
          action: 'create',
          child: AdminPrimaryButton(
            label: 'Nouvelle matière',
            icon: Icons.add_rounded,
            color: kNavy,
            onTap: onAdd,
          ),
        ),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label,
      required this.active,
      required this.asc,
      required this.onTap});
  final String label;
  final bool active, asc;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? kNavy.withValues(alpha: 0.08) : kSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? kNavy : kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? kNavy : kTextMuted)),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 13, color: kNavy),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'matière', 'matières')
        : '$filtered / ${_pl(total, 'matière', 'matières')}';
    return Row(children: [
      const Icon(Icons.menu_book_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _SubjectTable extends ConsumerWidget {
  const _SubjectTable({
    required this.rows,
    required this.sort,
    required this.sortAsc,
    required this.onSort,
    required this.onEdit,
    required this.onArchive,
  });
  final List<SubjectModel> rows;
  final String sort;
  final bool sortAsc;
  final ValueChanged<String> onSort;
  final ValueChanged<SubjectModel> onEdit, onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _Th('MATIÈRE',
                flex: 5,
                asc: sort == 'name' ? sortAsc : null,
                onTap: () => onSort('name')),
            _Th('COEFFICIENT',
                flex: 3,
                asc: sort == 'coef' ? sortAsc : null,
                onTap: () => onSort('coef')),
            const SizedBox(width: 96),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _SubjectRow(
            s: rows[i],
            last: i == rows.length - 1,
            canEdit: canEdit,
            canDelete: canDelete,
            onEdit: () => onEdit(rows[i]),
            onArchive: () => onArchive(rows[i]),
          ),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex, this.onTap, this.asc});
  final String label;
  final int flex;
  final VoidCallback? onTap;
  final bool? asc;
  @override
  Widget build(BuildContext context) {
    final child = Row(children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      ),
      if (asc != null)
        Icon(asc! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: kTextMuted),
    ]);
    return Expanded(
      flex: flex,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.s,
    required this.last,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onArchive,
  });
  final SubjectModel s;
  final bool last, canEdit, canDelete;
  final VoidCallback onEdit, onArchive;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.menu_book_rounded, size: 17, color: col),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBadge('Coef. ${s.coefficient}', color: kGreen),
          ),
        ),
        SizedBox(
          width: 96,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (canEdit)
              IconButton(
                tooltip: 'Modifier',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18, color: kNavy),
                onPressed: onEdit,
              ),
            if (canDelete)
              IconButton(
                tooltip: 'Archiver',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.archive_outlined, size: 18, color: kRed),
                onPressed: onArchive,
              ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _SubjectCards extends ConsumerWidget {
  const _SubjectCards(
      {required this.rows, required this.onEdit, required this.onArchive});
  final List<SubjectModel> rows;
  final ValueChanged<SubjectModel> onEdit, onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 4 : (w >= 880 ? 3 : (w >= 560 ? 2 : 1));
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in rows)
            SizedBox(
              width: cardW,
              child: _SubjectGridCard(
                s: s,
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () => onEdit(s),
                onArchive: () => onArchive(s),
              ),
            ),
        ],
      );
    });
  }
}

class _SubjectGridCard extends StatelessWidget {
  const _SubjectGridCard({
    required this.s,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onArchive,
  });
  final SubjectModel s;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onArchive;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: col,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.menu_book_rounded, size: 20, color: col),
          ),
          const Spacer(),
          if (canEdit)
            IconButton(
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Archiver',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.archive_outlined, size: 17, color: kRed),
              onPressed: onArchive,
            ),
        ]),
        const SizedBox(height: 12),
        Text(s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        const SizedBox(height: 10),
        AdminBadge('Coefficient ${s.coefficient}', color: kGreen),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE — création / édition (nom + coefficient via stepper).
// ════════════════════════════════════════════════════════════════════════════
class _SubjectForm extends ConsumerStatefulWidget {
  const _SubjectForm({this.existing});
  final SubjectModel? existing;
  @override
  ConsumerState<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<_SubjectForm> {
  late final _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late int _coef = widget.existing?.coefficient ?? 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la matière est obligatoire.', kRed);
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || schoolId.isEmpty) {
      _snack('École introuvable.', kRed);
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateSubject(
              id: widget.existing!.id, name: name, coefficient: _coef);
        } else {
          await createSubject(
              groupId: groupId,
              schoolId: schoolId,
              name: name,
              coefficient: _coef);
        }
      },
      success: _isEdit ? 'Matière mise à jour' : 'Matière créée',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Modifier la matière' : 'Nouvelle matière',
      subtitle: 'Le coefficient pondère la matière dans la moyenne',
      width: 460,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Nom de la matière *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5),
          decoration:
              adminFilledInput('Ex. Mathématiques', icon: Icons.menu_book_outlined),
        ),
        const SizedBox(height: 18),
        const Text('Coefficient',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          _StepBtn(
              icon: Icons.remove_rounded,
              onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
          Expanded(
            child: Center(
              child: Text('$_coef',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
            ),
          ),
          _StepBtn(
              icon: Icons.add_rounded,
              onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
        ]),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Icon(icon, size: 20, color: kNavy),
          ),
        ),
      );
}
