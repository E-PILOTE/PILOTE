import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/regional_table_provider.dart';
import 'admin_schools_screen.dart'
    show openSchoolDetailDialog, schoolTypeColor, schoolTypeLabel;

// Largeurs fixes des colonnes (la colonne « École » absorbe l'espace restant).
const double _wLoc = 150, _wCyc = 96, _wStu = 74, _wSta = 84;
const double _wRatio = 72, _wLoad = 84, _wOcc = 92, _wGps = 58, _wComp = 122, _wStat = 80;
const double _rowPadH = 14;
const double _otherCols =
    _wLoc + _wCyc + _wStu + _wSta + _wRatio + _wLoad + _wOcc + _wGps + _wComp + _wStat;

// ─── Mode Tableau analytique ─────────────────────────────────────────────────
class RegionalTableMode extends ConsumerWidget {
  const RegionalTableMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(regionalTableRowsProvider);
    final query = ref.watch(regionalTableQueryProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: async.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: kNavy, strokeWidth: 2.5)),
          error: (e, _) => Center(
            child: Text('Erreur de chargement\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kRed)),
          ),
          data: (rows) {
            final view = applyRegionalQuery(rows, query);
            return Column(
              children: [
                _Toolbar(allRows: rows, shown: view.length),
                Divider(height: 1, color: kBorder),
                _QualityAlerts(rows: rows),
                Divider(height: 1, color: kBorder),
                // En-tête + lignes partagent UN seul scroll horizontal et la
                // même largeur `tableW` → l'en-tête reste aligné aux colonnes
                // et ne déborde plus sur écran étroit.
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final tableW = math.max(
                        c.maxWidth, _otherCols + 280 + _rowPadH * 2);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableW,
                        child: Column(
                          children: [
                            _Header(query: query, tableW: tableW),
                            Divider(height: 1, color: kBorder),
                            Expanded(
                              child: view.isEmpty
                                  ? const _Empty()
                                  : ListView.separated(
                                      itemCount: view.length,
                                      separatorBuilder: (_, _) =>
                                          Divider(
                                              height: 1, color: kBorder),
                                      itemBuilder: (_, i) => _SchoolRow(
                                          row: view[i], tableW: tableW),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double _nameColWidth(double tableW) => tableW - _otherCols - _rowPadH * 2;

/// Couleur de charge pédagogique (élèves/classe) — partagée tableau ↔ carte.
/// 1 = ok (vert), 2 = chargé (ambre), 3 = surchargé (rouge), 0 = inconnu.
Color loadColor(int level) => switch (level) {
      1 => kGreen,
      2 => const Color(0xFFF59E0B),
      3 => kRed,
      _ => kTextMuted,
    };

String loadLabel(int level) => switch (level) {
      1 => 'Effectifs maîtrisés',
      2 => 'Classes chargées',
      3 => 'Classes surchargées',
      _ => 'Charge inconnue',
    };

/// Couleur du taux d'occupation (effectif/capacité) — partagée tableau ↔ carte.
/// 1 = sous-occupé (ambre), 2 = optimal (vert), 3 = saturé (rouge), 0 = inconnu.
Color occColor(int level) => switch (level) {
      1 => const Color(0xFFF59E0B),
      2 => kGreen,
      3 => kRed,
      _ => kTextMuted,
    };

String occLabel(int level) => switch (level) {
      1 => 'Sous-occupée',
      2 => 'Occupation optimale',
      3 => 'Capacité saturée',
      _ => 'Capacité non renseignée',
    };

// ─── Barre d'outils : recherche + filtres + synthèse ─────────────────────────
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.allRows, required this.shown});
  final List<RegionalTableRow> allRows;
  final int shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(regionalTableQueryProvider);
    final notifier = ref.read(regionalTableQueryProvider.notifier);

    final gps = allRows.where((r) => r.hasGps).length;
    final incomplete = allRows.where((r) => r.completeness < 100).length;
    final gpsPct =
        allRows.isEmpty ? 0 : (gps * 100 / allRows.length).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) =>
                      notifier.update((s) => s.copyWith(search: v)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher une école, code, ville, département…',
                    hintStyle:
                        TextStyle(fontSize: 12.5, color: kTextMuted),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kNavy)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$shown / ${allRows.length}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            Text(' écoles',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(
                label: 'Tous',
                active: q.type == null,
                onTap: () => notifier.update((s) => s.copyWith(type: null))),
            _Chip(
                label: 'Public',
                color: schoolTypeColor('public'),
                active: q.type == 'public',
                onTap: () =>
                    notifier.update((s) => s.copyWith(type: 'public'))),
            _Chip(
                label: 'Privé',
                color: schoolTypeColor('prive'),
                active: q.type == 'prive',
                onTap: () => notifier.update((s) => s.copyWith(type: 'prive'))),
            _Chip(
                label: 'Mixte',
                color: schoolTypeColor('mixte'),
                active: q.type == 'mixte',
                onTap: () => notifier.update((s) => s.copyWith(type: 'mixte'))),
            const _Sep(),
            _Chip(
                label: 'Actives',
                icon: Icons.check_circle_rounded,
                active: q.activeOnly,
                onTap: () => notifier.update(
                    (s) => s.copyWith(activeOnly: !s.activeOnly))),
            _Chip(
                label: 'Fiche incomplète ($incomplete)',
                icon: Icons.error_outline_rounded,
                color: kRed,
                active: q.incompleteOnly,
                onTap: () => notifier.update(
                    (s) => s.copyWith(incompleteOnly: !s.incompleteOnly))),
            const _Sep(),
            _MiniStat(
                icon: Icons.gps_fixed_rounded,
                label: '$gpsPct% géolocalisées',
                color: kGreen),
          ]),
        ],
      ),
    );
  }
}

// ─── Bandeau d'alertes qualité actionnables (Tier 2) ─────────────────────────
// Manques concrets à corriger, chacun cliquable → filtre le tableau dessus.
class _QualityAlerts extends ConsumerWidget {
  const _QualityAlerts({required this.rows});
  final List<RegionalTableRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(regionalTableQueryProvider);
    final notifier = ref.read(regionalTableQueryProvider.notifier);

    final noGps = rows.where((r) => !r.hasGps).length;
    final noDir = rows.where((r) => !r.hasDirector).length;
    final noCyc = rows.where((r) => r.cycleCodes.isEmpty).length;
    final incomplete = rows.where((r) => r.completeness < 100).length;
    final clean = noGps == 0 && noDir == 0 && noCyc == 0 && incomplete == 0;

    void toggle(RegionalGap g) => notifier.update(
        (s) => s.copyWith(gap: s.gap == g ? null : g));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: clean ? kGreen.withValues(alpha: 0.05) : kSurface,
      child: Row(children: [
        Icon(clean ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 15, color: clean ? kGreen : _kAmber),
        const SizedBox(width: 8),
        Text(clean ? 'Réseau complet' : 'À corriger',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: clean ? kGreen : kTextPrimary)),
        const SizedBox(width: 12),
        Expanded(
          child: clean
              ? Text('Toutes les fiches sont complètes et géolocalisées.',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                  overflow: TextOverflow.ellipsis)
              : Wrap(spacing: 8, runSpacing: 8, children: [
                  _AlertChip(
                      label: 'Sans GPS',
                      count: noGps,
                      color: _kAmber,
                      active: q.gap == RegionalGap.noGps,
                      onTap: () => toggle(RegionalGap.noGps)),
                  _AlertChip(
                      label: 'Sans directeur',
                      count: noDir,
                      color: kRed,
                      active: q.gap == RegionalGap.noDirector,
                      onTap: () => toggle(RegionalGap.noDirector)),
                  _AlertChip(
                      label: 'Sans cycle',
                      count: noCyc,
                      color: _kPurpleA,
                      active: q.gap == RegionalGap.noCycle,
                      onTap: () => toggle(RegionalGap.noCycle)),
                  _AlertChip(
                      label: 'Fiche incomplète',
                      count: incomplete,
                      color: kNavy,
                      active: q.gap == RegionalGap.incomplete,
                      onTap: () => toggle(RegionalGap.incomplete)),
                ]),
        ),
        if (q.gap != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () => notifier.update((s) => s.copyWith(gap: null)),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.close_rounded, size: 13, color: kTextMuted),
                const SizedBox(width: 2),
                Text('Filtre actif',
                    style: TextStyle(fontSize: 10, color: kTextMuted)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

const Color _kAmber = Color(0xFFF59E0B);
const Color _kPurpleA = Color(0xFF7C3AED);

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = count == 0;
    final c = muted ? kTextMuted : color;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: muted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c : c.withValues(alpha: muted ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? c : c.withValues(alpha: 0.25),
              width: active ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: 0.25) : c,
                borderRadius: BorderRadius.circular(20)),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : Colors.white)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : c)),
        ]),
      ),
    );
  }
}

// ─── En-tête de colonnes triables ────────────────────────────────────────────
class _Header extends ConsumerWidget {
  const _Header({required this.query, required this.tableW});
  final RegionalTableQuery query;
  final double tableW;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameW = _nameColWidth(tableW);
    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: _rowPadH, vertical: 9),
      child: Row(children: [
        _Sort(width: nameW, label: 'ÉCOLE', k: RegionalSortKey.name, q: query),
        _Sort(
            width: _wLoc,
            label: 'LOCALISATION',
            k: RegionalSortKey.dept,
            q: query),
        const _HCell(width: _wCyc, label: 'CYCLES'),
        _Sort(
            width: _wStu,
            label: 'ÉLÈVES',
            k: RegionalSortKey.students,
            q: query,
            right: true),
        _Sort(
            width: _wSta,
            label: 'PERSONNEL',
            k: RegionalSortKey.staff,
            q: query,
            right: true),
        _Sort(
            width: _wRatio,
            label: 'É/ENS',
            k: RegionalSortKey.ratio,
            q: query,
            right: true),
        _Sort(
            width: _wLoad,
            label: 'É/CLASSE',
            k: RegionalSortKey.load,
            q: query,
            right: true),
        _Sort(
            width: _wOcc,
            label: 'OCCUP.',
            k: RegionalSortKey.occupancy,
            q: query,
            right: true),
        const _HCell(width: _wGps, label: 'GPS', center: true),
        _Sort(
            width: _wComp,
            label: 'COMPLÉTUDE',
            k: RegionalSortKey.completeness,
            q: query),
        const _HCell(width: _wStat, label: 'STATUT', center: true),
      ]),
    );
  }
}

class _Sort extends ConsumerWidget {
  const _Sort({
    required this.width,
    required this.label,
    required this.k,
    required this.q,
    this.right = false,
  });
  final double width;
  final String label;
  final RegionalSortKey k;
  final RegionalTableQuery q;
  final bool right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = q.sortKey == k;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => ref.read(regionalTableQueryProvider.notifier).update(
            (s) => s.copyWith(
                sortKey: k, ascending: active ? !s.ascending : false)),
        child: Row(
          mainAxisAlignment:
              right ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: active ? kNavy : kTextMuted)),
            ),
            if (active)
              Icon(
                  q.ascending
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: kNavy),
          ],
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  const _HCell({required this.width, required this.label, this.center = false});
  final double width;
  final String label;
  final bool center;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(label,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

// ─── Une ligne école ─────────────────────────────────────────────────────────
class _SchoolRow extends ConsumerWidget {
  const _SchoolRow({required this.row, required this.tableW});
  final RegionalTableRow row;
  final double tableW;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = row.school;
    final tColor = schoolTypeColor(s.type);
    final nameW = _nameColWidth(tableW);

    return InkWell(
      onTap: () => openSchoolDetailDialog(context, ref, s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _rowPadH, vertical: 10),
        child: Row(children: [
          // École : logo + nom + code
          SizedBox(
            width: nameW,
            child: Row(children: [
              _Logo(url: s.logoUrl, color: tColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      const SizedBox(height: 1),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: tColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(schoolTypeLabel(s.type),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: tColor)),
                        ),
                        if (s.code != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('· ${s.code}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10, color: kTextMuted)),
                          ),
                        ],
                      ]),
                    ]),
              ),
            ]),
          ),
          // Localisation
          SizedBox(
            width: _wLoc,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.department ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  if (s.city != null)
                    Text(s.city!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10, color: kTextMuted)),
                ]),
          ),
          // Cycles
          SizedBox(width: _wCyc, child: _Cycles(codes: row.cycleCodes)),
          // Élèves
          _Num(width: _wStu, value: '${s.students}'),
          // Personnel
          _Num(width: _wSta, value: '${s.staff}'),
          // Ratio
          SizedBox(
            width: _wRatio,
            child: Text(
                row.studentsPerStaff > 0 ? '${row.studentsPerStaff}' : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: row.studentsPerStaff > 40 ? kRed : kTextPrimary)),
          ),
          // Charge (élèves / classe)
          SizedBox(
            width: _wLoad,
            child: row.loadLevel == 0
                ? Text('—',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: kTextMuted))
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: loadColor(row.loadLevel)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${row.studentsPerClass}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: loadColor(row.loadLevel))),
                    ),
                  ),
          ),
          // Occupation (effectif / capacité)
          SizedBox(
            width: _wOcc,
            child: row.occupancyPct == null
                ? Text('—',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: kTextMuted))
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: occColor(row.occupancyLevel)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${row.occupancyPct}%',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: occColor(row.occupancyLevel))),
                    ),
                  ),
          ),
          // GPS
          SizedBox(
            width: _wGps,
            child: Center(
              child: Icon(
                  row.hasGps
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_off_rounded,
                  size: 15,
                  color: row.hasGps ? kGreen : kTextMuted.withValues(alpha: 0.5)),
            ),
          ),
          // Complétude
          SizedBox(width: _wComp, child: _Completeness(pct: row.completeness)),
          // Statut
          SizedBox(
            width: _wStat,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (s.isActive ? kGreen : kTextMuted)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(s.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: s.isActive ? kGreen : kTextMuted)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.width, required this.value});
  final double width;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(value,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.color});
  final String? url;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 32,
        height: 32,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(),
                placeholder: (_, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: color.withValues(alpha: 0.12),
        child: Icon(Icons.school_rounded, size: 16, color: color),
      );
}

class _Cycles extends StatelessWidget {
  const _Cycles({required this.codes});
  final List<String> codes;
  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) {
      return Text('—', style: TextStyle(fontSize: 11, color: kTextMuted));
    }
    final show = codes.take(3).toList();
    return Wrap(spacing: 3, runSpacing: 3, children: [
      for (final c in show)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4)),
          child: Text(c.toUpperCase(),
              style: TextStyle(
                  fontSize: 8.5, fontWeight: FontWeight.w800, color: kNavy)),
        ),
      if (codes.length > 3)
        Text('+${codes.length - 3}',
            style: TextStyle(fontSize: 9, color: kTextMuted)),
    ]);
  }
}

class _Completeness extends StatelessWidget {
  const _Completeness({required this.pct});
  final int pct;
  @override
  Widget build(BuildContext context) {
    final color = pct >= 80
        ? kGreen
        : pct >= 50
            ? kAccent
            : kRed;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text('$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

// ─── Petits composants partagés ──────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.color,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kNavy;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? c : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13, color: active ? Colors.white : kTextMuted),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : kTextMuted)),
        ]),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, color: kBorder);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_alt_off_rounded,
              size: 32, color: kTextMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('Aucune école pour ces filtres',
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        ]),
      );
}
