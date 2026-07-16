part of 'notes_screen.dart';

// ─── Hero KPI ─────────────────────────────────────────────────────────────────
class _NotesKpis extends StatelessWidget {
  const _NotesKpis({required this.items});
  final List<Evaluation> items;
  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final published = items.where((e) => e.isPublished).length;
    final pending = items.where((e) => !e.isComplete).length;
    final graded = items.where((e) => e.average != null);
    final avg = graded.isEmpty
        ? null
        : graded.map((e) => e.average!).reduce((a, b) => a + b) / graded.length;
    final cards = <(IconData, String, String, Color, String?)>[
      (Icons.grade_rounded, 'Évaluations', '$total', kNavy, 'ce trimestre'),
      (
        Icons.published_with_changes_rounded,
        'Publiées',
        '$published',
        kGreen,
        'visibles élèves/parents'
      ),
      (
        Icons.pending_actions_rounded,
        'À compléter',
        '$pending',
        const Color(0xFFF59E0B),
        'notes manquantes'
      ),
      (
        Icons.functions_rounded,
        'Moyenne générale',
        avg == null ? '—' : '${avg.toStringAsFixed(2)}/20',
        const Color(0xFF0EA5E9),
        'toutes évaluations'
      ),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: cards.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = cards[i];
          return AdminStatCard(
              label: label, value: value, icon: icon, color: color, subtitle: sub);
        },
      );
    });
  }
}

// ─── Barre de filtres ────────────────────────────────────────────────────────
class _NotesFilterBar extends StatelessWidget {
  const _NotesFilterBar({
    required this.searchCtrl,
    required this.type,
    required this.status,
    required this.readOnly,
    required this.onSearch,
    required this.onType,
    required this.onStatus,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? type, status;
  final bool readOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType, onStatus;
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
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher (titre, matière, classe)…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: kTextMuted),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearch('');
                      })
                  : null,
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
          child: _FilterDropdown(
            hint: 'Type',
            value: type,
            items: kEvaluationTypes,
            onChanged: onType,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _FilterDropdown(
            hint: 'Statut',
            value: status,
            items: kEvalStatuses,
            onChanged: onStatus,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Réinitialiser',
          onPressed: onReset,
          icon: Icon(Icons.filter_alt_off_outlined, color: kTextMuted),
        ),
        const SizedBox(width: 4),
        if (!readOnly)
          PermissionGate(
            slug: _kSlug,
            action: 'create',
            child: _AddButton(onAdd: onAdd),
          ),
      ]),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String hint;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(hint,
          style: TextStyle(fontSize: 13, color: kTextMuted)),
      items: [
        DropdownMenuItem(value: null, child: Text('$hint : tous')),
        for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l)),
      ],
      onChanged: onChanged,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Nouvelle',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── En-tête de résultats + chip de scope ────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(width: 6),
        Text(filtered == total ? 'évaluations' : 'sur $total évaluations',
            style: TextStyle(fontSize: 13, color: kTextMuted)),
      ]);
}

// ─── Atelier d'une classe : filtres + liste de ses évaluations ───────────────
class _ClassWorkspace extends StatelessWidget {
  const _ClassWorkspace({
    required this.className,
    required this.evals,
    required this.searchCtrl,
    required this.type,
    required this.status,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.onSearch,
    required this.onType,
    required this.onStatus,
    required this.onReset,
    required this.onAdd,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onSetStatus,
  });
  final String? className;
  final List<Evaluation> evals;
  final TextEditingController searchCtrl;
  final String? type, status;
  final bool canCreate, canEdit, canDelete;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType, onStatus;
  final VoidCallback onReset, onAdd;
  final ValueChanged<Evaluation> onOpen, onEdit, onDelete;
  final void Function(Evaluation, String) onSetStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.class_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text(className ?? 'Classe',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: 26),
          Flexible(
            child: Text(
                canCreate
                    ? 'Créez une évaluation avec « + Nouvelle », puis cliquez '
                        'dessus pour saisir les notes élève par élève.'
                    : 'Cliquez une évaluation pour consulter les notes.',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        ]),
        const SizedBox(height: 14),
        _NotesFilterBar(
          searchCtrl: searchCtrl,
          type: type,
          status: status,
          readOnly: !canCreate,
          onSearch: onSearch,
          onType: onType,
          onStatus: onStatus,
          onReset: onReset,
          onAdd: onAdd,
        ),
        const SizedBox(height: 16),
        if (evals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AdminEmptyState(
              icon: Icons.grade_outlined,
              title: 'Aucune évaluation',
              message:
                  'Créez une évaluation (composition, devoir, séquence…) pour '
                  'cette classe et ce trimestre, puis saisissez les notes.',
              actionLabel: canCreate ? 'Nouvelle évaluation' : null,
              onAction: canCreate ? onAdd : null,
            ),
          )
        else ...[
          _ResultHeader(total: evals.length, filtered: evals.length),
          const SizedBox(height: 12),
          _EvalList(
            items: evals,
            canEdit: canEdit,
            canDelete: canDelete,
            onOpen: onOpen,
            onEdit: onEdit,
            onDelete: onDelete,
            onStatus: onSetStatus,
          ),
        ],
      ]),
    );
  }
}
