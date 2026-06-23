import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../students/widgets/inscription_form_kit.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/academic_year_context.dart';

part 'academic_structure_parts.dart';

// ─── Accents par cycle (cohérents avec la page Inscriptions) ─────────────────
const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
};
Color _cycleColor(String code) => _cycleColors[code] ?? kNavy;

// Pluriel français (n + singulier/pluriel).
String _pl(int n, String sing, String plur) => '$n ${n <= 1 ? sing : plur}';

IconData _cycleIcon(String code) => switch (code) {
      'prescolaire' => Icons.child_care_rounded,
      'primaire' => Icons.auto_stories_rounded,
      'college' => Icons.school_rounded,
      'lycee' => Icons.account_balance_rounded,
      'formation_pro' => Icons.engineering_rounded,
      _ => Icons.account_tree_rounded,
    };

class AcademicStructureScreen extends ConsumerWidget {
  const AcademicStructureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'niveaux',
        title: 'Structure académique',
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
  String? _selectedCycle;
  String? _filiere; // filtre filière (cycle courant)

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openClassForm(StructCycle cycle, StructLevel level,
          {StructClass? existing}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ClassFormModal(cycle: cycle, level: level, existing: existing),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(academicStructureProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (st) {
        if (st.cycles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: AdminEmptyState(
                icon: Icons.account_tree_outlined,
                title: 'Aucun cycle configuré',
                message:
                    'Les cycles d\'enseignement de l\'école sont définis par '
                    'l\'administration du groupe. Une fois attribués, ils '
                    'apparaîtront ici avec leurs niveaux.',
              ),
            ),
          );
        }
        // Cycle sélectionné par défaut / validé.
        final codes = st.cycles.map((c) => c.code).toList();
        final selCode =
            (_selectedCycle != null && codes.contains(_selectedCycle))
                ? _selectedCycle!
                : codes.first;
        final cycle = st.cycles.firstWhere((c) => c.code == selCode);

        return LayoutBuilder(builder: (ctx, cns) {
          final wide = cns.maxWidth >= 860;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Kpis(st: st),
                const SizedBox(height: 22),
                if (wide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 248,
                          child: _CycleRail(
                            cycles: st.cycles,
                            selected: selCode,
                            onSelect: (c) => setState(() {
                              _selectedCycle = c;
                              _filiere = null;
                              _search.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _DetailPanel(
                            cycle: cycle,
                            readOnly: readOnly,
                            search: _search,
                            filiere: _filiere,
                            onSearch: (_) => setState(() {}),
                            onFiliere: (v) => setState(() => _filiere = v),
                            onAdd: (lvl) => _openClassForm(cycle, lvl),
                            onEdit: (lvl, c) =>
                                _openClassForm(cycle, lvl, existing: c),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _CycleChips(
                    cycles: st.cycles,
                    selected: selCode,
                    onSelect: (c) => setState(() {
                      _selectedCycle = c;
                      _filiere = null;
                      _search.clear();
                    }),
                  ),
                  const SizedBox(height: 16),
                  _DetailPanel(
                    cycle: cycle,
                    readOnly: readOnly,
                    search: _search,
                    filiere: _filiere,
                    narrow: true,
                    onSearch: (_) => setState(() {}),
                    onFiliere: (v) => setState(() => _filiere = v),
                    onAdd: (lvl) => _openClassForm(cycle, lvl),
                    onEdit: (lvl, c) => _openClassForm(cycle, lvl, existing: c),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }
}

// ─── KPIs (taille plateforme) ────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.st});
  final AcademicStructure st;
  @override
  Widget build(BuildContext context) {
    final occ = st.cycles.fold<int>(0, (s, c) => s + c.capacity);
    final occLabel = occ == 0 ? '—' : '${(st.enrolled / occ * 100).round()} %';
    final items = [
      (Icons.account_tree_outlined, 'Cycles', '${st.cycles.length}', kNavy, null),
      (Icons.stairs_outlined, 'Niveaux', '${st.levelCount}', const Color(0xFF0EA5E9), null),
      (Icons.class_outlined, 'Classes', '${st.classCount}', kGreen, null),
      (Icons.groups_outlined, 'Élèves', '${st.enrolled}', const Color(0xFFF59E0B), null),
      (Icons.pie_chart_outline_rounded, 'Occupation', occLabel, const Color(0xFF8B5CF6),
          occ == 0 ? null : '$occ places'),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 1 ? 4.6 : 2.4,
        children: [
          for (final (icon, label, value, color, sub) in items)
            AdminStatCard(
                label: label,
                value: value,
                icon: icon,
                color: color,
                subtitle: sub),
        ],
      );
    });
  }
}
