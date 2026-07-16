import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../students/widgets/scope_drilldown_panel.dart'
    show scopeCycleName, scopeCycleOrder;
import '../providers/staff_directory_provider.dart';
import '../providers/staff_dossier_provider.dart' show employmentStatusLabel;

// ════════════════════════════════════════════════════════════════════════════
//  KIT PARTAGÉ « RH » — la distinction du personnel n'est PAS cycle/niveau/classe
//  (axes élève) mais : CATÉGORIE MÉTIER (Direction / Administration / Enseignants
//  / Vie scolaire) et STATUT D'EMPLOI (fonctionnaire / contractuel / volontaire…).
//  Ce kit fournit la segmentation par axe + la barre de segments cliquable
//  (filtre + métrique par segment) réutilisée par Présences, Congés, Paie.
// ════════════════════════════════════════════════════════════════════════════

/// Axe de distinction du personnel. Le CYCLE (primaire/collège/lycée) ne vaut
/// que pour les enseignants (déduit des classes enseignées) ; les non-enseignants
/// y sont regroupés en « Hors enseignement ».
enum StaffAxis { categorie, statut, cycle }

String staffAxisLabel(StaffAxis a) => switch (a) {
      StaffAxis.categorie => 'Catégorie',
      StaffAxis.statut => 'Statut',
      StaffAxis.cycle => 'Cycle',
    };

/// Clé de segment d'un agent selon l'axe (null/vide regroupé en «—»).
String staffSegKey(StaffMember s, StaffAxis axis) => switch (axis) {
      StaffAxis.categorie => staffCategory(s.role).name,
      StaffAxis.statut =>
        (s.employmentStatus ?? '').isEmpty ? '—' : s.employmentStatus!,
      StaffAxis.cycle => (s.teachingCycle ?? '').isEmpty ? '—' : s.teachingCycle!,
    };

String staffSegLabel(String key, StaffAxis axis) {
  switch (axis) {
    case StaffAxis.categorie:
      final c = StaffCategory.values.firstWhere((e) => e.name == key,
          orElse: () => StaffCategory.autres);
      return staffCategoryLabel(c);
    case StaffAxis.statut:
      return key == '—' ? 'Statut non renseigné' : employmentStatusLabel(key);
    case StaffAxis.cycle:
      return key == '—' ? 'Hors enseignement' : scopeCycleName(key);
  }
}

Color staffSegColor(String key, StaffAxis axis) {
  switch (axis) {
    case StaffAxis.categorie:
      return switch (key) {
        'direction' => kNavy,
        'administration' => const Color(0xFF7C3AED),
        'enseignement' => const Color(0xFF0EA5E9),
        'vieScolaire' => kGreen,
        _ => kTextMuted,
      };
    case StaffAxis.statut:
      return switch (key) {
        'fonctionnaire' => kNavy,
        'contractuel' => const Color(0xFF0EA5E9),
        'volontaire' => kGreen,
        'prestataire' => const Color(0xFF7C3AED),
        'stagiaire' => const Color(0xFFF59E0B),
        'benevole' => const Color(0xFF0D9488),
        _ => kTextMuted,
      };
    case StaffAxis.cycle:
      return switch (key) {
        'primaire' => const Color(0xFF0EA5E9),
        'college' => const Color(0xFF7C3AED),
        'lycee' => kNavy,
        _ => kTextMuted,
      };
  }
}

/// Ordre stable des segments (catégorie = organigramme ; statut = ordre enum ;
/// cycle = ordre scolaire, hors enseignement en dernier).
int staffSegOrder(String key, StaffAxis axis) {
  switch (axis) {
    case StaffAxis.categorie:
      final i = staffCategoryOrder.indexWhere((c) => c.name == key);
      return i < 0 ? 99 : i;
    case StaffAxis.statut:
      const order = ['fonctionnaire', 'contractuel', 'volontaire',
        'prestataire', 'stagiaire', 'benevole', '—'];
      final i = order.indexOf(key);
      return i < 0 ? 99 : i;
    case StaffAxis.cycle:
      return key == '—' ? 99 : scopeCycleOrder(key);
  }
}

/// Un segment agrégé : total d'agents + métrique « ok » (présents, payés…).
class StaffSegment {
  StaffSegment(this.key, this.axis);
  final String key;
  final StaffAxis axis;
  int total = 0;
  int ok = 0;
  String get label => staffSegLabel(key, axis);
  Color get color => staffSegColor(key, axis);
  double get rate => total == 0 ? 0 : ok / total;
}

/// Agrège une liste d'agents en segments selon l'axe, avec une métrique « ok ».
List<StaffSegment> staffSegments(
  List<StaffMember> agents,
  StaffAxis axis, {
  bool Function(StaffMember)? okOf,
}) {
  final map = <String, StaffSegment>{};
  for (final a in agents) {
    final k = staffSegKey(a, axis);
    final seg = map.putIfAbsent(k, () => StaffSegment(k, axis));
    seg.total++;
    if (okOf != null && okOf(a)) seg.ok++;
  }
  final list = map.values.toList()
    ..sort((a, b) => staffSegOrder(a.key, axis).compareTo(staffSegOrder(b.key, axis)));
  return list;
}

// ─── Bascule d'axe (Catégorie / Statut) ──────────────────────────────────────
class StaffAxisToggle extends StatelessWidget {
  const StaffAxisToggle({super.key, required this.axis, required this.onChanged});
  final StaffAxis axis;
  final ValueChanged<StaffAxis> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final a in StaffAxis.values)
          GestureDetector(
            onTap: () => onChanged(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: axis == a ? kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(staffAxisLabel(a),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: axis == a ? Colors.white : kTextMuted)),
            ),
          ),
      ]),
    );
  }
}

// ─── Barre de segments : carte par segment (sélectionnable = filtre) ──────────
class StaffSegmentBar extends StatelessWidget {
  const StaffSegmentBar({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
    this.metricLabel = 'ok',
    this.showMetric = true,
  });
  final List<StaffSegment> segments;
  final String? selected; // clé sélectionnée (null = tous)
  final ValueChanged<String?> onSelect;
  final String metricLabel;
  final bool showMetric;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 78,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final s in segments)
          _SegCard(
            seg: s,
            selected: selected == s.key,
            metricLabel: metricLabel,
            showMetric: showMetric,
            onTap: () => onSelect(selected == s.key ? null : s.key),
          ),
      ]),
    );
  }
}

class _SegCard extends StatelessWidget {
  const _SegCard({
    required this.seg,
    required this.selected,
    required this.metricLabel,
    required this.showMetric,
    required this.onTap,
  });
  final StaffSegment seg;
  final bool selected, showMetric;
  final String metricLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 168,
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            decoration: BoxDecoration(
              color: selected ? seg.color.withValues(alpha: 0.10) : Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: selected ? seg.color : kBorder,
                  width: selected ? 1.5 : 1),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: seg.color, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(seg.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${seg.total}',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: seg.color)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('agents',
                          style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                    ),
                    const Spacer(),
                    if (showMetric)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${seg.ok} $metricLabel',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: seg.color)),
                      ),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'action groupée (style discret, icône + libellé).
class StaffBulkButton extends StatelessWidget {
  StaffBulkButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    Color? color,
  }) : color = color ?? kNavy;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.10) : kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: enabled ? color.withValues(alpha: 0.35) : kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: enabled ? color : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled ? color : kTextMuted)),
          ]),
        ),
      ),
    );
  }
}
