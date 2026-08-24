part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI SURPLOMBE LA LISTE : graphe d'évolution, barre de filtres, bandeau de
//  périmètre, barre d'actions groupées, en-tête de résultats, et le sélecteur
//  de classe qu'ouvre une réaffectation.
//
//  Séparé de la liste elle-même (`eleves_liste_parts.dart`) : ce fichier répond
//  à « comment on restreint et on agit », l'autre à « comment un élève
//  s'affiche ». Deux questions, deux lecteurs.
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Élèves : graphes, barre de filtres, barre d'actions
//  groupées, table (sélection), cartes, avatar, sélecteur de classe.
// ════════════════════════════════════════════════════════════════════════════

// ─── Évolution de l'effectif (graphe mensuel) ────────────────────────────────
class _EffectifEvolution extends ConsumerWidget {
  const _EffectifEvolution();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pts = ref.watch(effectifEvolutionProvider).valueOrNull ?? const [];
    // Le garde « moins de deux points » a rejoint le widget : il était identique
    // ici et sur la page Inscriptions, à la phrase près.
    return MonthlyEvolutionCard(
      points: [for (final p in pts) EvoPoint(p.label, p.count, p.cumul)],
      barLabel: 'Élèves entrés',
      lineLabel: 'Effectif cumulé',
      emptyMessage: 'Pas encore assez d\'historique pour tracer une évolution '
          '(les dates d\'inscription se cumulent au fil de l\'année).',
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _ElevesFilterBar extends StatelessWidget {
  const _ElevesFilterBar({
    required this.searchCtrl,
    required this.gender,
    required this.particularite,
    required this.isTable,
    required this.readOnly,
    required this.onSearch,
    required this.onGender,
    required this.onParticularite,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? gender, particularite;
  final bool isTable, readOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onGender, onParticularite;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFilter = searchCtrl.text.isNotEmpty ||
        gender != null ||
        particularite != null;
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
                width: 250,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  // L'INE se cherche ici depuis qu'il est reconnu : c'est le
                  // numéro qui arrive d'ailleurs, et le dire évite qu'on
                  // l'essaie une fois, sans résultat, puis jamais plus.
                  decoration: adminFilledInput('Rechercher (nom, matricule, INE)',
                      icon: Icons.search_rounded),
                ),
              ),
              _Drop(
                hint: 'Tous les sexes',
                value: gender,
                items: const {'M': 'Garçons', 'F': 'Filles'},
                onChanged: onGender,
              ),
              _Drop(
                hint: 'Toutes particularités',
                value: particularite,
                items: kParticularitesEleve,
                onChanged: onParticularite,
              ),
              if (hasFilter)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(foregroundColor: kTextMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(isTable: isTable, onToggle: onToggleView),
        if (!readOnly) ...[
          const SizedBox(width: 10),
          PermissionGate(
            slug: 'eleves',
            action: 'create',
            child: AdminPrimaryButton(
              label: 'Nouvel élève',
              icon: Icons.person_add_alt_1_rounded,
              color: kNavy,
              onTap: onAdd,
            ),
          ),
        ],
      ]),
    );
  }
}

// Bandeau de filtre actif (scope choisi dans le panneau de répartition).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

class _Drop extends StatelessWidget {
  const _Drop(
      {required this.hint,
      required this.value,
      required this.items,
      required this.onChanged});
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        icon: Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        decoration: adminFilledInput(hint),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: kTextMuted)),
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                size: 16, color: kNavy),
            const SizedBox(width: 7),
            Text(isTable ? 'Cartes' : 'Table',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onChangeClass,
    required this.onRevert,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onChangeClass, onRevert, onExport, onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('$count sélectionné${count > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        const Spacer(),
        _BulkBtn(
            icon: Icons.swap_horiz_rounded,
            label: 'Changer de classe',
            onTap: onChangeClass),
        _BulkBtn(
            icon: Icons.undo_rounded,
            label: 'Annuler l\'inscription',
            onTap: onRevert),
        _BulkBtn(
            icon: Icons.download_rounded, label: 'Exporter', onTap: onExport),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Désélectionner',
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

// ─── En-tête de résultats ────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'élève', 'élèves')
        : '$filtered / ${_pl(total, 'élève', 'élèves')}';
    return Row(children: [
      Icon(Icons.groups_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}

// ─── Sélecteur de classe (cascade) — renvoie l'id de classe choisi ───────────
class _ClassChooserDialog extends ConsumerStatefulWidget {
  const _ClassChooserDialog({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  ConsumerState<_ClassChooserDialog> createState() =>
      _ClassChooserDialogState();
}

class _ClassChooserDialogState extends ConsumerState<_ClassChooserDialog> {
  String? _classId;

  ClassPickerEntry _entry(ClassModel c) {
    final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
    return ClassPickerEntry(
      id: c.id,
      name: c.name,
      cycleCode: cyc.code,
      cycleLabel: cyc.label,
      cycleOrder: cyc.order,
      levelCode: c.levelCode ?? '',
      levelOrder: c.levelOrder ?? 999,
      capacity: c.capacity,
      count: c.studentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      width: 520,
      submitLabel: 'Valider',
      submitIcon: Icons.check_rounded,
      // ⚠️ `onSubmit: () { if (_classId == null) return; }` ne faisait RIEN :
      // le bouton restait actif, l'agent cliquait, la fenêtre ne bougeait pas
      // et rien n'expliquait pourquoi. Un bouton désactivé dit la même chose,
      // mais avant le clic.
      onSubmit: _classId == null
          ? null
          : () => Navigator.pop(context, _classId),
      body: classesAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Text(messageErreur(e), style: TextStyle(color: kRed)),
        data: (classes) {
          if (classes.isEmpty) {
            return Text('Aucune classe disponible.',
                style: TextStyle(color: kTextMuted, fontSize: 13));
          }
          return CycleLevelClassPicker(
            entries: [for (final c in classes) _entry(c)],
            classId: _classId,
            onChanged: (v) => setState(() => _classId = v),
          );
        },
      ),
    );
  }
}
