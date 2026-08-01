part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BRIQUES DE PRÉSENTATION DE LA PAGE INSCRIPTIONS — bandeau d'explication,
//  cartes KPI, courbe du rythme, barre de filtres et squelette de chargement.
//
//  Extraites de `inscriptions_screen.dart`, qui dépassait 1 400 lignes : la
//  logique du guichet (validation, rejet, retrait, réaffectation, impression)
//  reste dans l'écran, l'habillage vit ici. La coupe suit cette couture-là, pas
//  un compte de lignes.
// ════════════════════════════════════════════════════════════════════════════

class _PipelineNotice extends StatelessWidget {
  const _PipelineNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kNavy.withValues(alpha: 0.16)),
        ),
        child: Row(children: [
          Icon(Icons.inbox_rounded, size: 17, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette page est le guichet des admissions : elle ne liste que les '
              'dossiers encore à traiter — en attente, rejetés ou sortis. Dès '
              'qu\'une inscription est validée, l\'élève rejoint la page Élèves.',
              style: TextStyle(
                  fontSize: 12.5, color: kTextMuted, height: 1.45),
            ),
          ),
        ]),
      );
}

// ─── Section KPI générale (cartes pleine taille, comme le Tableau de bord) ────
class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.st, required this.year});
  final InscriptionStats st;
  final YearInscriptionTotals year;

  @override
  Widget build(BuildContext context) {
    // ⚠️ DEUX SOURCES, ET C'EST VOULU.
    // `st` décrit le GUICHET : les dossiers encore à traiter (la liste du bas).
    // `year` décrit l'ANNÉE ENTIÈRE, inscriptions validées comprises.
    //
    // Les quatre cartes de droite lisaient `st` : « Nouvelles » affichait 0
    // dans une école qui avait inscrit trente élèves, parce que ces trente-là
    // étaient validés donc absents du guichet. Un compteur d'activité qui
    // retombe à zéro à mesure que le travail est fait ne mesure pas le travail.
    final cards = <Widget>[
      AdminStatCard(
        label: 'Inscrits',
        value: '${year.enrolled}',
        icon: Icons.groups_rounded,
        color: kGreen,
        subtitle: 'Effectif de l\'année',
      ),
      AdminStatCard(
        label: 'En attente',
        value: '${st.pending}',
        icon: Icons.hourglass_top_rounded,
        color: kAccent,
        subtitle: 'À valider',
      ),
      AdminStatCard(
        label: 'Rejetées',
        value: '${st.rejected}',
        icon: Icons.cancel_outlined,
        color: kRed,
        subtitle: 'Dossiers refusés',
      ),
      AdminStatCard(
        label: 'Nouvelles',
        value: '${year.newCount}',
        icon: Icons.fiber_new_rounded,
        color: kNavy,
        subtitle: 'Premières inscriptions',
      ),
      AdminStatCard(
        label: 'Réinscriptions',
        value: '${year.reinscription}',
        icon: Icons.autorenew_rounded,
        color: _kBlue,
        subtitle: 'Élèves de retour',
      ),
      AdminStatCard(
        label: 'Redoublants',
        value: '${year.repeating}',
        icon: Icons.replay_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: 'Recommencent leur niveau',
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


// ─── Rythme des inscriptions ─────────────────────────────────────────────────
// Sens RÉEL du graphe : combien d'élèves s'inscrivent CHAQUE mois (barres =
// rythme de la campagne) et comment l'effectif se REMPLIT (courbe = cumul).
class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.points});
  final List<EnrollPoint> points;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(children: [
              _LegendDot(color: kNavy, label: 'Inscriptions du mois'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreen, label: 'Effectif cumulé', line: true),
            ]),
          ),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              axes: <ChartAxis>[
                NumericAxis(
                  name: 'cumul',
                  opposedPosition: true,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                  labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<EnrollPoint, String>>[
                ColumnSeries<EnrollPoint, String>(
                  name: 'Inscriptions',
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.count,
                  color: kNavy.withValues(alpha: 0.85),
                  width: 0.55,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                SplineSeries<EnrollPoint, String>(
                  name: 'Cumulé',
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.cumul,
                  yAxisName: 'cumul',
                  color: kGreen,
                  width: 2.5,
                  markerSettings: const MarkerSettings(
                      isVisible: true, height: 5, width: 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.line = false});
  final Color color;
  final String label;
  final bool line;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: line ? 14 : 10,
          height: line ? 3 : 10,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(line ? 2 : 3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted)),
      ]);
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.filiere,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.filieresPresent,
    required this.onSearch,
    required this.onFiliere,
    required this.onType,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.onExport,
  });
  final double width;
  final TextEditingController searchCtrl;
  final String? filiere, type;
  final String status;
  final bool isTable, readOnly;
  final List<String> filieresPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onFiliere, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters =>
      filiere != null || type != null || status != 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
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
                hintText: 'Rechercher (nom, matricule)…',
                hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: kTextMuted),
                        onPressed: () { searchCtrl.clear(); onSearch(''); })
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
          _IconBtn(
            icon: isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            tooltip: isTable ? 'Vue en cartes' : 'Vue en tableau',
            color: kNavy,
            onTap: onToggleView,
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.download_rounded,
            tooltip: 'Exporter en CSV',
            color: kGreen,
            onTap: onExport,
          ),
          const SizedBox(width: 12),
          _AddButton(readOnly: readOnly, onAdd: onAdd),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filieresPresent.isNotEmpty)
              _FilterDropdown<String?>(
                icon: Icons.workspaces_outlined,
                value: filiere,
                active: filiere != null,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Toutes les filières')),
                  for (final f in filieresPresent)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: onFiliere,
              ),
            _FilterDropdown<String?>(
              icon: Icons.category_outlined,
              value: type,
              active: type != null,
              items: const [
                DropdownMenuItem(value: null, child: Text('Tous les types')),
                DropdownMenuItem(value: 'new', child: Text('Nouvelles')),
                DropdownMenuItem(
                    value: 'reinscription', child: Text('Réinscriptions')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferts')),
              ],
              onChanged: onType,
            ),
            _StatusSegment(value: status, onChanged: onStatus),
            if (_hasFilters)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                      const SizedBox(width: 4),
                      Text('Réinitialiser',
                          style: TextStyle(
                              color: kRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.readOnly, required this.onAdd});
  final bool readOnly;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
          const SizedBox(width: 6),
          Text('Année verrouillée',
              style: TextStyle(
                  color: kAccent, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return PermissionGate(
      slug: 'inscriptions',
      action: 'create',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
              Icon(Icons.person_add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('Inscrire',
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({
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

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.active,
  });
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? kNavy : kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                icon: Icon(Icons.expand_more_rounded,
                    size: 14, color: active ? kNavy : kTextMuted),
                isExpanded: true,
                style: TextStyle(
                  color: active ? kNavy : kTextPrimary,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
      );
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
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
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('pending_validation', 'En attente'),
        seg('rejected', 'Rejetées'),
        seg('withdrawn', 'Sorties'),
      ]),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) => Row(children: [
        // « inscrit » était faux : la requête du provider exclut
        // `status = 'active'`, donc cette page ne montre QUE des dossiers non
        // encore validés. L'élève inscrit, lui, vit dans la page Élèves.
        Text('$filtered dossier${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
        const Spacer(),
        if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
      ]);
}

// ─── Skeleton de chargement (shimmer, calqué sur la vraie page) ──────────────
class _InscriptionsSkeleton extends StatelessWidget {
  const _InscriptionsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    // Jetons de thème, pas des gris figés : ce squelette est le TOUT PREMIER
    // écran affiché à l'ouverture du module. En gris clair codé en dur, il
    // éclatait en blanc sur le fond sombre avant même que la page existe.
    return Shimmer.fromColors(
      baseColor: kSurface,
      highlightColor: kBorder,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero KPI (6 cartes responsives)
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1180
                  ? 6
                  : c.maxWidth >= 920
                      ? 4
                      : c.maxWidth >= 600
                          ? 3
                          : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 12),
              );
            }),
            const SizedBox(height: 26),
            // Carte « Répartition » (en-tête + grille)
            _box(double.infinity, 320, r: 12),
            const SizedBox(height: 26),
            // Évolution
            _box(180, 16, r: 6),
            const SizedBox(height: 12),
            _box(double.infinity, 230, r: 12),
            const SizedBox(height: 22),
            // Barre de filtres
            _box(double.infinity, 110, r: 8),
            const SizedBox(height: 18),
            // Quelques lignes de tableau
            for (var i = 0; i < 6; i++) ...[
              _box(double.infinity, 52, r: 10),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
