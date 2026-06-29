part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EN-TÊTE DE LA PAGE (style Inscriptions, sans onglets) :
//   • _EdtKpiSection : hero de KPI globaux (état, conflits, couverture…) ;
//   • _EdtFilterBar  : recherche + commutateur de vue + boutons (Paramètres
//     en tiroir, export PDF, Ajouter un créneau) ;
//   • _ViewSegment   : Établissement / Classe / Enseignant / Salle ;
//   • _ScopeChip     : filtre cycle/niveau/classe actif.
// ════════════════════════════════════════════════════════════════════════════

// ─── Hero KPI globaux (cartes pleine taille, comme la page Inscriptions) ──────
class _EdtKpiSection extends StatelessWidget {
  const _EdtKpiSection({
    required this.version,
    required this.conflicts,
    required this.covered,
    required this.totalClasses,
    required this.slots,
    required this.teachers,
    required this.rooms,
  });
  final TimetableVersion? version;
  final int conflicts, covered, totalClasses, slots, teachers, rooms;

  @override
  Widget build(BuildContext context) {
    final published = version?.isPublished ?? false;
    final cards = <Widget>[
      AdminStatCard(
        label: 'État',
        value: version?.statusLabel ?? 'Aucun EDT',
        icon: published ? Icons.verified_rounded : Icons.edit_note_rounded,
        color: published ? kGreen : kAccent,
        subtitle: published ? 'Publié' : 'En préparation',
      ),
      AdminStatCard(
        label: 'Conflits',
        value: '$conflicts',
        icon: conflicts == 0
            ? Icons.check_circle_outline_rounded
            : Icons.warning_amber_rounded,
        color: conflicts == 0 ? kGreen : kRed,
        subtitle: conflicts == 0 ? 'Aucun chevauchement' : 'À corriger',
      ),
      AdminStatCard(
        label: 'Classes couvertes',
        value: '$covered/$totalClasses',
        icon: Icons.groups_2_rounded,
        color: kNavy,
        subtitle: 'Avec emploi du temps',
      ),
      AdminStatCard(
        label: 'Créneaux',
        value: '$slots',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF0EA5E9),
        subtitle: 'Cette semaine',
      ),
      AdminStatCard(
        label: 'Enseignants',
        value: '$teachers',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: 'Mobilisés',
      ),
      AdminStatCard(
        label: 'Salles',
        value: '$rooms',
        icon: Icons.meeting_room_outlined,
        color: const Color(0xFFF59E0B),
        subtitle: 'Déclarées',
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180
          ? 6
          : c.maxWidth >= 920
              ? 4
              : c.maxWidth >= 600
                  ? 3
                  : c.maxWidth >= 380
                      ? 2
                      : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 168,
        ),
        itemBuilder: (_, i) => cards[i],
      );
    });
  }
}

// ─── Bandeau de publication (cycle de vie de la version) ─────────────────────
class _PublicationBar extends StatelessWidget {
  const _PublicationBar({
    required this.version,
    required this.conflicts,
    required this.canManage,
    required this.onPublish,
    required this.onUnpublish,
  });
  final TimetableVersion? version;
  final int conflicts;
  final bool canManage;
  final VoidCallback onPublish, onUnpublish;

  @override
  Widget build(BuildContext context) {
    final published = version?.isPublished ?? false;
    final color = published ? kGreen : kAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Icon(published ? Icons.verified_rounded : Icons.edit_note_rounded,
            size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    published
                        ? 'Emploi du temps publié'
                        : 'Brouillon — non publié',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(
                    published
                        ? 'Visible des enseignants, élèves et parents'
                        : 'En construction — invisible des enseignants/élèves',
                    style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
        ),
        if (canManage && version != null) ...[
          if (conflicts > 0 && !published)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('$conflicts conflit${conflicts > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: kRed)),
            ),
          if (published)
            OutlinedButton.icon(
              onPressed: onUnpublish,
              style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent.withValues(alpha: 0.4))),
              icon: const Icon(Icons.unpublished_outlined, size: 16),
              label: const Text('Brouillon'),
            )
          else
            FilledButton.icon(
              onPressed: onPublish,
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              icon: const Icon(Icons.publish_rounded, size: 16),
              label: const Text('Publier'),
            ),
        ],
      ]),
    );
  }
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _EdtFilterBar extends StatelessWidget {
  const _EdtFilterBar({
    required this.searchCtrl,
    required this.view,
    required this.readOnly,
    required this.showAdd,
    required this.onSearch,
    required this.onView,
    required this.onHistory,
    required this.onSettings,
    required this.onExport,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final TtView view;
  final bool readOnly, showAdd;
  final ValueChanged<String> onSearch;
  final ValueChanged<TtView> onView;
  final VoidCallback onHistory, onSettings, onExport, onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher (matière, enseignant, classe, salle)…',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
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
          _EdtIconBtn(
            icon: Icons.history_rounded,
            tooltip: 'Historique des modifications',
            color: kNavy,
            onTap: onHistory,
          ),
          const SizedBox(width: 8),
          _EdtIconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Paramètres (salles, trame horaire)',
            color: kNavy,
            onTap: onSettings,
          ),
          const SizedBox(width: 8),
          _EdtIconBtn(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: 'Exporter en PDF',
            color: kGreen,
            onTap: onExport,
          ),
          if (showAdd) ...[
            const SizedBox(width: 12),
            _AddCreneauButton(readOnly: readOnly, onAdd: onAdd),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ViewSegment(view: view, onChanged: onView)),
          if (readOnly) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAccent.withValues(alpha: 0.30)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_clock_rounded, size: 14, color: kAccent),
                SizedBox(width: 6),
                Text('Année verrouillée',
                    style: TextStyle(
                        color: kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ─── Commutateur de vue : Établissement / Classe / Enseignant / Salle ────────
class _ViewSegment extends StatelessWidget {
  const _ViewSegment({required this.view, required this.onChanged});
  final TtView view;
  final ValueChanged<TtView> onChanged;
  @override
  Widget build(BuildContext context) {
    const items = <(TtView, IconData, String)>[
      (TtView.ensemble, Icons.dashboard_rounded, 'Établissement'),
      (TtView.classe, Icons.groups_2_rounded, 'Classe'),
      (TtView.enseignant, Icons.person_rounded, 'Enseignant'),
      (TtView.salle, Icons.meeting_room_rounded, 'Salle'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        for (final (m, icon, label) in items)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(m),
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: view == m ? kNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 15,
                          color: view == m ? Colors.white : kTextMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: view == m ? Colors.white : kTextMuted)),
                      ),
                    ]),
              ),
            ),
          ),
      ]),
    );
  }
}


// ─── Bouton icône de la barre de filtres ─────────────────────────────────────
class _EdtIconBtn extends StatelessWidget {
  const _EdtIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      );
}

// ─── Bouton « Ajouter un créneau » ───────────────────────────────────────────
class _AddCreneauButton extends StatelessWidget {
  const _AddCreneauButton({required this.readOnly, required this.onAdd});
  final bool readOnly;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    if (readOnly) return const SizedBox.shrink();
    return PermissionGate(
      slug: _kSlug,
      action: 'create',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kNavyDark, kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Ajouter un créneau',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Bandeau de filtre actif (cycle/niveau/classe) ───────────────────────────
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
            const Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}
