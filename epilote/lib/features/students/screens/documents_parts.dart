part of 'documents_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Documents : barre de filtres, en-tête résultats, grille de
//  dossiers (checklist par élève), registre des pièces.
// ════════════════════════════════════════════════════════════════════════════

String _filterLabel(_DossierFilter f) => switch (f) {
      _DossierFilter.all => 'Tous',
      _DossierFilter.complete => 'Complets',
      _DossierFilter.incomplete => 'Incomplets',
      _DossierFilter.expired => 'Expirées',
    };

// ─── Conformité — drill-down Cycle › Niveau › Classe (panneau de pilotage) ────
// Une seule source (les dossiers des élèves actifs). On descend en cascade :
// cliquer un cycle affiche ses niveaux, puis un niveau affiche ses classes. À
// chaque cran la liste se restreint au scope (fil d'Ariane pour remonter). La
// barre montre le TAUX de dossiers complets (vert = complet) → repérer les
// groupes en retard.
class _ConformitePanel extends StatelessWidget {
  const _ConformitePanel({
    required this.dossiers,
    required this.navCycle,
    required this.navLevel,
    required this.navClass,
    required this.onDrillCycle,
    required this.onDrillLevel,
    required this.onDrillClass,
    required this.onCrumb,
  });
  final List<StudentDossier> dossiers;
  final String? navCycle, navLevel, navClass;
  final ValueChanged<String> onDrillCycle, onDrillLevel, onDrillClass;
  final ValueChanged<int> onCrumb;

  // Profondeur courante : 0 = cycles, 1 = niveaux d'un cycle, 2 = classes.
  int get _depth => navLevel != null ? 2 : (navCycle != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final hint = switch (_depth) {
      0 => 'Cliquez un cycle pour voir ses niveaux et filtrer la liste.',
      1 => 'Cliquez un niveau pour voir ses classes.',
      _ => 'Cliquez une classe pour cibler son effectif.',
    };
    final groups = switch (_depth) {
      0 => _groupCycles(),
      1 => _groupLevels(navCycle!),
      _ => _groupClasses(navLevel!),
    };
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.fact_check_outlined, size: 16, color: kNavy),
          const SizedBox(width: 8),
          const Text('Conformité des dossiers',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
          _Crumbs(
            cycleLabel: navCycle != null ? _cycName(navCycle) : null,
            levelLabel: navLevel,
            onCrumb: onCrumb,
          ),
        ]),
        const SizedBox(height: 4),
        Text('$hint · barre verte = part de dossiers complets.',
            style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const SizedBox(
              height: 48,
              child:
                  Center(child: Text('—', style: TextStyle(color: kTextMuted))))
        else
          Column(children: [
            for (final g in groups)
              _ConfBar(
                g: g,
                onTap: switch (_depth) {
                  0 => onDrillCycle,
                  1 => onDrillLevel,
                  _ => onDrillClass,
                },
              ),
          ]),
      ]),
    );
  }

  // Niveau 0 : cycles (tous les dossiers).
  List<_ConfGroup> _groupCycles() {
    final map = <String, ({int total, int complete})>{};
    for (final d in dossiers) {
      final k = d.student.cycleCode ?? '';
      if (k.isEmpty) continue;
      final c = map[k];
      map[k] = (
        total: (c?.total ?? 0) + 1,
        complete: (c?.complete ?? 0) + (d.isComplete ? 1 : 0)
      );
    }
    return [
      for (final e in map.entries)
        _ConfGroup(
            key: e.key,
            label: _cycName(e.key),
            total: e.value.total,
            complete: e.value.complete,
            color: _cycColor(e.key),
            sortA: _cycOrder(e.key),
            sortB: 0,
            drillable: true)
    ]..sort((a, b) => a.sortA.compareTo(b.sortA));
  }

  // Niveau 1 : niveaux d'un cycle.
  List<_ConfGroup> _groupLevels(String cycle) {
    final map = <String, ({int total, int complete, int order})>{};
    for (final d in dossiers) {
      if (d.student.cycleCode != cycle) continue;
      final k = d.student.levelCode ?? '';
      if (k.isEmpty) continue;
      final c = map[k];
      map[k] = (
        total: (c?.total ?? 0) + 1,
        complete: (c?.complete ?? 0) + (d.isComplete ? 1 : 0),
        order: d.student.levelOrder,
      );
    }
    return [
      for (final e in map.entries)
        _ConfGroup(
            key: e.key,
            label: e.key,
            total: e.value.total,
            complete: e.value.complete,
            color: _cycColor(cycle),
            sortA: e.value.order,
            sortB: 0,
            drillable: true)
    ]..sort((a, b) => a.sortA.compareTo(b.sortA));
  }

  // Niveau 2 : classes d'un niveau.
  List<_ConfGroup> _groupClasses(String level) {
    final map = <String, ({int total, int complete, String name, String cycle})>{};
    for (final d in dossiers) {
      if (d.student.levelCode != level) continue;
      final id = d.student.classId;
      if (id == null) continue;
      final c = map[id];
      map[id] = (
        total: (c?.total ?? 0) + 1,
        complete: (c?.complete ?? 0) + (d.isComplete ? 1 : 0),
        name: d.student.className ?? '—',
        cycle: d.student.cycleCode ?? '',
      );
    }
    return [
      for (final e in map.entries)
        _ConfGroup(
            key: e.key,
            label: e.value.name,
            total: e.value.total,
            complete: e.value.complete,
            color: _cycColor(e.value.cycle),
            sortA: 0,
            sortB: 0,
            picked: navClass == e.key,
            drillable: false)
    ]..sort((a, b) => a.label.compareTo(b.label));
  }
}

// Fil d'Ariane Tous › Cycle › Niveau.
class _Crumbs extends StatelessWidget {
  const _Crumbs(
      {required this.cycleLabel, required this.levelLabel, required this.onCrumb});
  final String? cycleLabel, levelLabel;
  final ValueChanged<int> onCrumb;
  @override
  Widget build(BuildContext context) {
    Widget crumb(String label, int depth, {required bool active}) => InkWell(
          onTap: active ? null : () => onCrumb(depth),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? kTextMuted : kNavy)),
          ),
        );
    const sep = Icon(Icons.chevron_right_rounded, size: 15, color: kTextMuted);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        crumb('Tous', 0, active: cycleLabel == null),
        if (cycleLabel != null) ...[
          sep,
          crumb(cycleLabel!, 1, active: levelLabel == null),
        ],
        if (levelLabel != null) ...[sep, crumb(levelLabel!, 2, active: true)],
      ]),
    );
  }
}

class _ConfGroup {
  const _ConfGroup({
    required this.key,
    required this.label,
    required this.total,
    required this.complete,
    required this.color,
    required this.sortA,
    required this.sortB,
    this.picked = false,
    this.drillable = false,
  });
  final String key, label;
  final int total, complete, sortA, sortB;
  final Color color;
  final bool picked, drillable;
  double get ratio => total == 0 ? 0 : complete / total;
  int get pct => total == 0 ? 0 : (complete * 100 / total).round();
}

// Barre de conformité d'un groupe (vert = part complète) — cliquable (filtre).
class _ConfBar extends StatelessWidget {
  const _ConfBar({required this.g, required this.onTap});
  final _ConfGroup g;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    final full = g.complete == g.total && g.total > 0;
    final barColor = full ? kGreen : (g.pct == 0 ? kRed : const Color(0xFFF59E0B));
    return InkWell(
      onTap: () => onTap(g.key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: g.picked ? kNavy.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: g.picked ? kNavy.withValues(alpha: 0.35) : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: g.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 92,
            child: Text(g.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: g.ratio.clamp(0.0, 1.0),
                minHeight: 15,
                backgroundColor: kSurface,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text('${g.complete}/${g.total}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          SizedBox(
            width: 44,
            child: Text('${g.pct} %',
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: full ? kGreen : kTextMuted)),
          ),
          Icon(
              g.picked
                  ? Icons.filter_alt_rounded
                  : (g.drillable
                      ? Icons.chevron_right_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 17,
              color: g.picked ? kNavy : kTextMuted),
        ]),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.filter,
    required this.byStudent,
    required this.onSearch,
    required this.onFilter,
    required this.onToggleView,
    required this.onReset,
  });
  final TextEditingController searchCtrl;
  final _DossierFilter filter;
  final bool byStudent;
  final ValueChanged<String> onSearch;
  final ValueChanged<_DossierFilter> onFilter;
  final VoidCallback onToggleView, onReset;

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
                width: 240,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher (élève, pièce…)',
                      icon: Icons.search_rounded),
                ),
              ),
              _FilterSegment(value: filter, onChanged: onFilter),
              if (filter != _DossierFilter.all) _ResetChip(onTap: onReset),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(byStudent: byStudent, onToggle: onToggleView),
      ]),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({required this.value, required this.onChanged});
  final _DossierFilter value;
  final ValueChanged<_DossierFilter> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(_DossierFilter v) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Text(_filterLabel(v),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final v in _DossierFilter.values) seg(v),
      ]),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.byStudent, required this.onToggle});
  final bool byStudent;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    Widget seg(bool student, IconData icon, String label) {
      final sel = byStudent == student;
      return GestureDetector(
        onTap: sel ? null : onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextMuted)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(true, Icons.people_alt_rounded, 'Par élève'),
        seg(false, Icons.list_alt_rounded, 'Registre'),
      ]),
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRed.withValues(alpha: 0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_alt_off_rounded, size: 14, color: kRed),
              SizedBox(width: 5),
              Text('Réinitialiser',
                  style: TextStyle(
                      color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ─── Bandeau de filtre actif (groupe sélectionné dans le panneau) ────────────
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    return Align(
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
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.byStudent,
    required this.count,
    required this.total,
    this.onExportPdf,
  });
  final bool byStudent;
  final int count, total;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final noun = byStudent
        ? (total <= 1 ? 'élève' : 'élèves')
        : (total <= 1 ? 'pièce' : 'pièces');
    final txt = count == total ? '$total $noun' : '$count / $total $noun';
    return Row(children: [
      Icon(byStudent ? Icons.people_alt_rounded : Icons.list_alt_rounded,
          size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}

// ─── Vue « Par élève » : grille de dossiers avec checklist ────────────────────
class _DossierGrid extends StatelessWidget {
  const _DossierGrid({required this.dossiers, required this.onOpen});
  final List<StudentDossier> dossiers;
  final ValueChanged<StudentDossier> onOpen;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final d in dossiers)
            SizedBox(
                width: cardW,
                child: _DossierCard(d: d, onOpen: () => onOpen(d))),
        ],
      );
    });
  }
}

class _DossierCard extends StatelessWidget {
  const _DossierCard({required this.d, required this.onOpen});
  final StudentDossier d;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final complete = d.isComplete;
    final accent = complete ? kGreen : (d.docs.isEmpty ? kRed : kAccent);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: accent,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Text(
              d.student.firstName.isNotEmpty
                  ? d.student.firstName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.student.lastFirst,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Row(children: [
                if (d.student.className != null) ...[
                  Flexible(
                    child: Text(d.student.className!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ),
                  const Text(' · ',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
                Text(d.student.matricule,
                    style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
            ]),
          ),
          AdminBadge(complete ? 'Complet' : 'Incomplet', color: accent),
        ]),
        const SizedBox(height: 14),
        // Checklist des pièces exigées (présent / vérifié / manquant).
        for (final e in studentDocTypes.entries)
          if (kRequiredDocTypes.contains(e.key))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _ChecklistRow(
                label: e.value,
                present: d.presentTypes.contains(e.key),
                verified: d.docs
                    .any((x) => x.documentType == e.key && x.isVerified),
              ),
            ),
        const Divider(height: 18, color: kBorder),
        Row(children: [
          _MiniStat(Icons.description_outlined, '${d.docs.length}', 'pièces'),
          const SizedBox(width: 16),
          _MiniStat(Icons.verified_outlined, '${d.verifiedCount}', 'vérif.'),
          if (d.expiredCount > 0) ...[
            const SizedBox(width: 16),
            _MiniStat(Icons.event_busy_outlined, '${d.expiredCount}', 'expir.',
                color: kRed),
          ],
          const Spacer(),
          const Text('Gérer',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kNavy),
        ]),
      ]),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow(
      {required this.label, required this.present, required this.verified});
  final String label;
  final bool present, verified;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = !present
        ? (Icons.radio_button_unchecked_rounded, kTextMuted)
        : verified
            ? (Icons.verified_rounded, kGreen)
            : (Icons.check_circle_outline_rounded, const Color(0xFF0EA5E9));
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 9),
      Expanded(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                color: present ? kTextPrimary : kTextMuted,
                fontWeight: present ? FontWeight.w600 : FontWeight.w400)),
      ),
      if (present && !verified)
        const Text('à vérifier',
            style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9))),
      if (!present)
        const Text('manquant',
            style: TextStyle(fontSize: 11, color: kTextMuted)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.icon, this.value, this.label, {this.color = kTextMuted});
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
          children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text('$value ',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
      ]);
}

// ─── Vue « Registre » : toutes les pièces déposées ────────────────────────────
class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.rows});
  final List<DocRow> rows;
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            _Th('ÉLÈVE', flex: 4),
            _Th('CLASSE', flex: 2),
            _Th('PIÈCE', flex: 4),
            _Th('DÉPÔT', flex: 2),
            _Th('ÉTAT', flex: 2),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _RegistryRow(d: rows[i], last: i == rows.length - 1),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow({required this.d, required this.last});
  final DocRow d;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.lastFirst,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            Text(d.matricule,
                style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: d.className != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: AdminBadge(d.className!, color: kNavy))
              : const Text('—', style: TextStyle(color: kTextMuted)),
        ),
        Expanded(
          flex: 4,
          child: Text(d.typeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ),
        Expanded(
          flex: 2,
          child: Text(_fmtDate(d.createdAt),
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: d.isExpired
                ? const AdminBadge('Expirée', color: kRed)
                : d.isVerified
                    ? const AdminBadge('Vérifiée', color: kGreen)
                    : const AdminBadge('À vérifier',
                        color: Color(0xFF0EA5E9)),
          ),
        ),
      ]),
    );
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
