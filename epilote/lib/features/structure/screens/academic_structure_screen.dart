import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart' show canProvider;
import '../../navigation/widgets/module_scaffold.dart';
import '../../students/widgets/inscription_form_kit.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/academic_year_context.dart';
import '../../../core/utils/message_erreur.dart';

// ═════════════════════════════════════════════════════════════════════════
//  DEUX ÉCRANS ÉCRIVENT `classes`, ET C'EST ASSUMÉ — décidé le 2026-09-10
// ═════════════════════════════════════════════════════════════════════════
//  Cet écran (Structure académique) et l'écran Classes créent tous deux une
//  classe. La question de les fusionner a été posée ; la réponse est NON, et
//  la voici pour qu'on ne la repose pas tous les six mois :
//
//   • ils servent deux gestes différents. Ici, on BÂTIT la structure — cycles,
//     niveaux, puis les classes qui les portent, en une fois, avant la
//     rentrée. Là-bas, on GÈRE une classe qui existe : son effectif, son
//     professeur principal, sa salle, en cours d'année.
//   • ils ne s'adressent pas aux mêmes personnes ni au même moment.
//
//  ⚠️ CE QUI DEVAIT ÊTRE CORRIGÉ L'A ÉTÉ. Le risque n'était pas d'avoir deux
//  formulaires : c'était d'avoir deux ÉCRITURES divergentes. Les deux passent
//  désormais par `createStructuredClass`, la seule qui pose les colonnes
//  dénormalisées (`cycle_code`, `level_code`, `level_order`, `filiere_*`) dont
//  dépendent l'État de rentrée et les KPI d'inscriptions. La fonction amputée
//  qui vivait à côté (`createClass`, sans appelant) a été supprimée.
//
//  Règle : deux portes, une seule serrure. Toute nouvelle porte vers `classes`
//  passe par `createStructuredClass`.
// ═════════════════════════════════════════════════════════════════════════

part 'academic_structure_cycles.dart';
part 'academic_structure_detail.dart';
part 'academic_structure_niveaux.dart';
part 'academic_structure_classes.dart';
part 'academic_structure_class_form.dart';

// ─── Accents par cycle (cohérents avec la page Inscriptions) ─────────────────
Map<String, Color> get _cycleColors => <String, Color>{
  'prescolaire': const Color(0xFFEC4899),
  'primaire': const Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': const Color(0xFFF59E0B),
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
    // ⚠️ DEUX verrous distincts, et l'un manquait entièrement.
    //
    //  `yearReadOnlyProvider` ferme l'écran quand l'année est verrouillée ou
    //  qu'aucune n'est courante. Il ne dit RIEN du droit du membre.
    //
    //  Or ces boutons écrivent dans `classes`, dont la politique RLS
    //  `classes_insert` exige `classes.create`. 38 membres « Secrétariat »
    //  voyaient donc un « + » qui leur renvoyait un `42501` — un code que
    //  PowerSync traite comme fatal : le LOT ENTIER du poste est jeté, avec
    //  les inscriptions, les présences et les paiements de la même fenêtre.
    //  Un bouton qu'on ne peut pas actionner doit être absent, pas punitif.
    //
    //  Le droit interrogé est celui du module `classes` (la table écrite), pas
    //  celui de `niveaux` (le module de l'écran) : on demande à l'écran de
    //  prédire ce que le serveur acceptera.
    final readOnlyYear = ref.watch(yearReadOnlyProvider);
    final canCreateClass =
        ref.watch(canProvider((slug: 'classes', action: 'create')));
    final canUpdateClass =
        ref.watch(canProvider((slug: 'classes', action: 'update')));
    final readOnly = readOnlyYear || !canUpdateClass;
    final canAdd = !readOnlyYear && canCreateClass;

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(messageErreur(e), style: TextStyle(color: kRed)),
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
                            canAdd: canAdd,
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
                    canAdd: canAdd,
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
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = items[i];
          return AdminStatCard(
              label: label,
              value: value,
              icon: icon,
              color: color,
              subtitle: sub);
        },
      );
    });
  }
}
