import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../providers/inscriptions_data_provider.dart';
import 'add_inscription_screen.dart';

part 'inscriptions_list_parts.dart';

// ─── Accents de cycle ─────────────────────────────────────────────────────────
const _kBlue = Color(0xFF0EA5E9);
const _kPink = Color(0xFFEC4899);

Color _cycleColor(String code) => switch (code) {
      'prescolaire' => _kPink,
      'primaire' => _kBlue,
      'college' => kGreen,
      'lycee' => kNavy,
      'fp' => kAccent,
      _ => kTextMuted,
    };

enum _SortBy { nom, classe, date }

// ════════════════════════════════════════════════════════════════════════════
//  PAGE INSCRIPTIONS — une seule page (design plateforme admin_groupe) :
//  KPI → cycles → évolution → filtres (avec « Inscrire ») → table / cartes.
//  Le statut « En attente » est un FILTRE (pas un onglet) ; validation/rejet
//  via les actions de ligne et la fiche détail.
// ════════════════════════════════════════════════════════════════════════════
class InscriptionsScreen extends ConsumerWidget {
  const InscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ModuleScaffold(
      slug: 'inscriptions',
      title: 'Inscriptions',
      child: _InscriptionsBody(),
    );
  }
}

class _InscriptionsBody extends ConsumerStatefulWidget {
  const _InscriptionsBody();
  @override
  ConsumerState<_InscriptionsBody> createState() => _InscriptionsBodyState();
}

class _InscriptionsBodyState extends ConsumerState<_InscriptionsBody> {
  final _searchCtrl = TextEditingController();
  String? _cycle;
  String? _type;
  String _status = 'all'; // all | active | pending_validation | rejected
  bool _isTable = true;
  _SortBy _sort = _SortBy.nom;
  bool _sortAsc = true;
  String _dim = 'cycle'; // dimension de la répartition : cycle|niveau|classe|filiere

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InscriptionRow> _apply(List<InscriptionRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = all.where((r) {
      if (_cycle != null && r.cycle.code != _cycle) return false;
      if (_type != null && r.inscriptionType != _type) return false;
      if (_status != 'all' && r.status != _status) return false;
      if (q.isEmpty) return true;
      return r.fullName.toLowerCase().contains(q) ||
          r.matricule.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = switch (_sort) {
          _SortBy.nom => a.lastFirst.toLowerCase().compareTo(b.lastFirst.toLowerCase()),
          _SortBy.classe => a.className.compareTo(b.className),
          _SortBy.date => (a.enrollmentDate ?? DateTime(2000))
              .compareTo(b.enrollmentDate ?? DateTime(2000)),
        };
        return _sortAsc ? c : -c;
      });
    return out;
  }

  void _resetFilters() => setState(() {
        _searchCtrl.clear();
        _cycle = _type = null;
        _status = 'all';
      });

  void _openAdd() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: AddInscriptionScreen(),
        ),
      );

  void _openDetail(InscriptionRow r) => showDialog(
        context: context,
        builder: (_) => _InscriptionDetailModal(
          row: r,
          onOpenStudent: () {
            Navigator.of(context).pop();
            context.push(Routes.eleveDetail.replaceFirst(':id', r.studentId));
          },
          onValidate: r.status == 'pending_validation'
              ? () { Navigator.of(context).pop(); _validate(r); }
              : null,
          onReject: r.status == 'pending_validation'
              ? () { Navigator.of(context).pop(); _reject(r); }
              : null,
        ),
      );

  Future<void> _validate(InscriptionRow r) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    try {
      await validateEnrollment(enrollmentId: r.id, validatedBy: me);
      _snack('Inscription validée', kGreen);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _reject(InscriptionRow r) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Rejeter l\'inscription'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex. : Dossier incomplet, quota atteint…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    try {
      await rejectEnrollment(
        enrollmentId: r.id,
        rejectionReason:
            ctrl.text.trim().isEmpty ? 'Aucun motif précisé' : ctrl.text.trim(),
        validatedBy: me,
      );
      _snack('Inscription rejetée', kTextMuted);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
    ctrl.dispose();
  }

  Future<void> _export(List<InscriptionRow> rows) async {
    if (rows.isEmpty) return;
    try {
      final path = await exportInscriptionsCsv(rows);
      _snack('Export CSV : ${rows.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack('Erreur export : $e', kRed);
    }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inscriptionsDataProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const _InscriptionsSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final st = ref.watch(inscriptionStatsProvider);
        final filtered = _apply(all);
        final cyclesPresent = <String, String>{
          for (final r in all) r.cycle.code: r.cycle.label,
        };

        return LayoutBuilder(builder: (ctx, cns) {
          final w = cns.maxWidth.isFinite
              ? cns.maxWidth
              : MediaQuery.of(ctx).size.width;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KpiSection(st: st),
                  const SizedBox(height: 26),
                  _BreakdownCard(
                    st: st,
                    dim: _dim,
                    onDim: (d) => setState(() => _dim = d),
                  ),
                  const SizedBox(height: 26),
                  if (st.evolution.length >= 2) ...[
                    const AdminSectionTitle('Évolution des inscriptions',
                        icon: Icons.show_chart_rounded),
                    const SizedBox(height: 12),
                    _EvolutionCard(points: st.evolution),
                    const SizedBox(height: 22),
                  ],
                  _FilterBar(
                    width: w - 48,
                    searchCtrl: _searchCtrl,
                    cycle: _cycle,
                    type: _type,
                    status: _status,
                    isTable: _isTable,
                    readOnly: readOnly,
                    cyclesPresent: cyclesPresent,
                    onSearch: (_) => setState(() {}),
                    onCycle: (v) => setState(() => _cycle = v),
                    onType: (v) => setState(() => _type = v),
                    onStatus: (v) => setState(() => _status = v),
                    onToggleView: () => setState(() => _isTable = !_isTable),
                    onReset: _resetFilters,
                    onAdd: _openAdd,
                    onExport: () => _export(filtered),
                  ),
                  const SizedBox(height: 16),
                  _ResultHeader(total: all.length, filtered: filtered.length),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: AdminEmptyState(
                        icon: Icons.how_to_reg_outlined,
                        title: 'Aucune inscription cette année',
                        message:
                            'Inscrivez le premier élève pour démarrer le suivi des effectifs.',
                        actionLabel: readOnly ? null : 'Inscrire un élève',
                        onAction: readOnly ? null : _openAdd,
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: AdminEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Aucun résultat',
                        message: 'Ajustez la recherche ou les filtres.',
                      ),
                    )
                  else if (_isTable)
                    _InscritsTable(
                      rows: filtered,
                      sort: _sort,
                      sortAsc: _sortAsc,
                      onSort: (f) => setState(() {
                        if (_sort == f) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sort = f;
                          _sortAsc = true;
                        }
                      }),
                      onView: _openDetail,
                      onValidate: _validate,
                      onReject: _reject,
                      readOnly: readOnly,
                    )
                  else
                    _InscritsCards(
                      rows: filtered,
                      onView: _openDetail,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// ─── Section KPI générale (cartes pleine taille, comme le Tableau de bord) ────
class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.st});
  final InscriptionStats st;

  @override
  Widget build(BuildContext context) {
    final tot = st.boys + st.girls;
    final cards = <Widget>[
      AdminStatCard(
        label: 'Total inscrits',
        value: '${st.total}',
        icon: Icons.groups_rounded,
        color: kNavy,
        subtitle: 'Dossiers vivants',
      ),
      AdminStatCard(
        label: 'Validées',
        value: '${st.active}',
        icon: Icons.verified_rounded,
        color: kGreen,
        subtitle: st.total > 0
            ? '${(st.active * 100 / st.total).round()} % du total'
            : '—',
      ),
      AdminStatCard(
        label: 'En attente',
        value: '${st.pending}',
        icon: Icons.hourglass_top_rounded,
        color: kAccent,
        subtitle: 'À valider',
      ),
      AdminStatCard(
        label: 'Filles',
        value: '${st.girls}',
        icon: Icons.female_rounded,
        color: _kPink,
        subtitle: tot > 0 ? '${(st.girls * 100 / tot).round()} % des effectifs' : '—',
      ),
      AdminStatCard(
        label: 'Garçons',
        value: '${st.boys}',
        icon: Icons.male_rounded,
        color: _kBlue,
        subtitle: tot > 0 ? '${(st.boys * 100 / tot).round()} % des effectifs' : '—',
      ),
      AdminStatCard(
        label: 'Taux de remplissage',
        value: st.capacityTotal > 0
            ? '${(st.fillRatio * 100).round()} %'
            : '—',
        icon: Icons.donut_large_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: st.capacityTotal > 0
            ? '${st.total} / ${st.capacityTotal} places'
            : 'Capacités non définies',
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

// ─── Carte « Répartition des effectifs » (1 seule, dimension au choix) ───────
// Au lieu d'empiler 4 grilles identiques (cycle/niveau/classe/filière) — qui
// rendaient la distinction illisible — une SEULE carte avec un sélecteur de
// dimension. C'est la MÊME donnée vue à des granularités différentes :
//   Cycle ⊃ Niveau ⊃ Classe   (la filière = spécialité du lycée/FP).
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard(
      {required this.st, required this.dim, required this.onDim});
  final InscriptionStats st;
  final String dim;
  final ValueChanged<String> onDim;

  static const _help = <String, String>{
    'cycle':
        'Grands ensembles pédagogiques de l\'école (préscolaire, primaire, collège, lycée, formation pro.).',
    'niveau':
        'Subdivisions d\'un cycle — ex. le collège contient les niveaux 6ᵉ, 5ᵉ, 4ᵉ et 3ᵉ.',
    'classe':
        'Salles concrètes où les élèves sont inscrits — effectif et taux de remplissage de chaque classe.',
    'filiere':
        'Spécialités du lycée / formation professionnelle (séries, métiers).',
  };

  @override
  Widget build(BuildContext context) {
    final hasFiliere = st.byProgram.isNotEmpty;
    // dimension effective (garde-fou si la filière disparaît)
    final d = (dim == 'filiere' && !hasFiliere) ? 'cycle' : dim;

    Widget content() {
      switch (d) {
        case 'niveau':
          return st.byLevel.isEmpty
              ? const _BreakdownEmpty(
                  'Aucun niveau défini',
                  'Les niveaux apparaîtront dès qu\'une classe sera rattachée à un niveau.')
              : _LevelSection(byLevel: st.byLevel);
        case 'classe':
          return st.byClass.isEmpty
              ? const _BreakdownEmpty('Aucune classe',
                  'Créez une classe dans le module Classes pour démarrer les inscriptions.')
              : _ClassSection(byClass: st.byClass);
        case 'filiere':
          return _ProgramSection(byProgram: st.byProgram);
        default:
          return st.byCycle.isEmpty
              ? const _BreakdownEmpty('Aucun cycle',
                  'Les cycles apparaissent dès qu\'une classe existe pour l\'école.')
              : _CycleSection(byCycle: st.byCycle);
      }
    }

    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 720;
            const title = Row(children: [
              Icon(Icons.insights_rounded, size: 20, color: kNavy),
              SizedBox(width: 8),
              Text('Répartition des effectifs',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ]);
            final toggle = _DimToggle(
              dim: d,
              hasFiliere: hasFiliere,
              counts: {
                'cycle': st.byCycle.length,
                'niveau': st.byLevel.length,
                'classe': st.byClass.length,
                'filiere': st.byProgram.length,
              },
              onDim: onDim,
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: toggle),
                ],
              );
            }
            return Row(children: [
              const Expanded(child: title),
              toggle,
            ]);
          }),
          const SizedBox(height: 10),
          Text(_help[d] ?? '',
              style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          const SizedBox(height: 18),
          content(),
        ],
      ),
    );
  }
}

class _BreakdownEmpty extends StatelessWidget {
  const _BreakdownEmpty(this.title, this.message);
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          const Icon(Icons.inbox_rounded, size: 30, color: kTextMuted),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

class _DimToggle extends StatelessWidget {
  const _DimToggle({
    required this.dim,
    required this.hasFiliere,
    required this.counts,
    required this.onDim,
  });
  final String dim;
  final bool hasFiliere;
  final Map<String, int> counts;
  final ValueChanged<String> onDim;

  @override
  Widget build(BuildContext context) {
    Widget seg(String key, IconData icon, String label) {
      final sel = dim == key;
      final n = counts[key] ?? 0;
      return GestureDetector(
        onTap: () => onDim(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextMuted)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.white.withValues(alpha: 0.22)
                    : kTextMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : kTextMuted)),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('cycle', Icons.account_tree_rounded, 'Cycle'),
        seg('niveau', Icons.layers_rounded, 'Niveau'),
        seg('classe', Icons.meeting_room_rounded, 'Classe'),
        if (hasFiliere) seg('filiere', Icons.workspaces_rounded, 'Filière'),
      ]),
    );
  }
}

// ─── Grille de répartition (même taille que les KPI généraux) ────────────────
// Palette de couleurs distinctes : chaque niveau / classe / filière reçoit sa
// propre couleur (index → couleur), pour les différencier d'un coup d'œil.
const _distribPalette = <Color>[
  Color(0xFF1E3A5F), // navy
  Color(0xFF009A44), // vert
  Color(0xFF0EA5E9), // bleu ciel
  Color(0xFFEC4899), // rose
  Color(0xFFB8860B), // or
  Color(0xFF7C3AED), // violet
  Color(0xFF0D9488), // sarcelle
  Color(0xFFEA580C), // orange
  Color(0xFF4F46E5), // indigo
  Color(0xFF65A30D), // lime
  Color(0xFFDB2777), // magenta
  Color(0xFF0891B2), // cyan
];
Color _distribColor(int i) => _distribPalette[i % _distribPalette.length];

/// Grille responsive identique à celle des KPI généraux (1→6 colonnes,
/// hauteur fixe 168) : toutes les cartes de répartition ont la MÊME taille.
class _DistribGrid extends StatelessWidget {
  const _DistribGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
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

/// Carte de répartition unifiée (cycle / niveau / classe / filière) — même
/// gabarit que `AdminStatCard`, couleur propre, barre de progression + filles/
/// garçons. `infoLabel` = ligne de contexte (% du total ou « X/Y places »).
class _DistribCard extends StatelessWidget {
  const _DistribCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.title,
    required this.girls,
    required this.boys,
    required this.ratio,
    this.infoLabel,
    this.over = false,
  });
  final IconData icon;
  final Color color;
  final int value, girls, boys;
  final String title;
  final double ratio;
  final String? infoLabel;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final barColor = over ? kRed : color;
    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const Spacer(),
            Text('$value',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 12),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.04, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (infoLabel != null)
              Flexible(
                child: Text(infoLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: over ? kRed : kTextMuted)),
              ),
            const Spacer(),
            const Icon(Icons.female_rounded, size: 13, color: _kPink),
            const SizedBox(width: 2),
            Text('$girls',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _kPink)),
            const SizedBox(width: 9),
            const Icon(Icons.male_rounded, size: 13, color: _kBlue),
            const SizedBox(width: 2),
            Text('$boys',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _kBlue)),
          ]),
        ],
      ),
    );
  }
}

String _pctLabel(int part, int whole) =>
    whole > 0 ? '${(part * 100 / whole).round()} % du total' : '—';

// ─── Section cycles (couleur sémantique par cycle) ───────────────────────────
class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.byCycle});
  final List<CycleCount> byCycle;

  @override
  Widget build(BuildContext context) {
    final grand = byCycle.fold<int>(0, (s, c) => s + c.total);
    return _DistribGrid(cards: [
      for (final c in byCycle)
        _DistribCard(
          icon: Icons.school_rounded,
          color: _cycleColor(c.cycle.code),
          value: c.total,
          title: c.cycle.label,
          girls: c.girls,
          boys: c.boys,
          ratio: grand > 0 ? c.total / grand : 0,
          infoLabel: _pctLabel(c.total, grand),
        ),
    ]);
  }
}

// ─── Section niveaux (6e, 5e, 4e… — couleur distincte par niveau) ────────────
class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.byLevel});
  final List<LevelCount> byLevel;

  @override
  Widget build(BuildContext context) {
    final grand = byLevel.fold<int>(0, (s, l) => s + l.total);
    return _DistribGrid(cards: [
      for (var i = 0; i < byLevel.length; i++)
        _DistribCard(
          icon: Icons.layers_rounded,
          color: _distribColor(i),
          value: byLevel[i].total,
          title: byLevel[i].code,
          girls: byLevel[i].girls,
          boys: byLevel[i].boys,
          ratio: grand > 0 ? byLevel[i].total / grand : 0,
          infoLabel: _pctLabel(byLevel[i].total, grand),
        ),
    ]);
  }
}

// ─── Section filières (lycée / FP — couleur distincte par filière) ───────────
class _ProgramSection extends StatelessWidget {
  const _ProgramSection({required this.byProgram});
  final List<ProgramCount> byProgram;

  @override
  Widget build(BuildContext context) {
    final grand = byProgram.fold<int>(0, (s, p) => s + p.total);
    return _DistribGrid(cards: [
      for (var i = 0; i < byProgram.length; i++)
        _DistribCard(
          icon: Icons.workspaces_rounded,
          // décalage de teinte pour distinguer des niveaux
          color: _distribColor(i + 4),
          value: byProgram[i].total,
          title: byProgram[i].label,
          girls: byProgram[i].girls,
          boys: byProgram[i].boys,
          ratio: grand > 0 ? byProgram[i].total / grand : 0,
          infoLabel: _pctLabel(byProgram[i].total, grand),
        ),
    ]);
  }
}

// ─── Section classes (couleur distincte par classe + taux de remplissage) ────
class _ClassSection extends StatelessWidget {
  const _ClassSection({required this.byClass});
  final List<ClassCount> byClass;

  @override
  Widget build(BuildContext context) {
    return _DistribGrid(cards: [
      for (var i = 0; i < byClass.length; i++)
        () {
          final c = byClass[i];
          final hasCap = c.capacity > 0;
          final color = _distribColor(i);
          return _DistribCard(
            icon: Icons.meeting_room_rounded,
            color: color,
            value: c.total,
            title: c.name,
            girls: c.girls,
            boys: c.boys,
            ratio: hasCap ? c.fillRatio : 0,
            over: c.fillRatio > 1,
            infoLabel: hasCap
                ? '${c.total}/${c.capacity} places'
                : 'Capacité non définie',
          );
        }(),
    ]);
  }
}

// ─── Évolution ───────────────────────────────────────────────────────────────
class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.points});
  final List<(String, int)> points;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 8),
      child: SizedBox(
        height: 230,
        child: SfCartesianChart(
          margin: EdgeInsets.zero,
          primaryXAxis: const CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          primaryYAxis: const NumericAxis(
            axisLine: AxisLine(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<(String, int), String>>[
            SplineAreaSeries<(String, int), String>(
              dataSource: points,
              xValueMapper: (p, _) => p.$1,
              yValueMapper: (p, _) => p.$2,
              borderColor: kGreen,
              borderWidth: 2.5,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGreen.withValues(alpha: 0.28),
                  kGreen.withValues(alpha: 0.02),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.cycle,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.cyclesPresent,
    required this.onSearch,
    required this.onCycle,
    required this.onType,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.onExport,
  });
  final double width;
  final TextEditingController searchCtrl;
  final String? cycle, type;
  final String status;
  final bool isTable, readOnly;
  final Map<String, String> cyclesPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCycle, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters => cycle != null || type != null || status != 'all';

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
                hintText: 'Rechercher (nom, matricule)…',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
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
        Row(children: [
          _FilterDropdown<String?>(
            icon: Icons.account_tree_outlined,
            value: cycle,
            active: cycle != null,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les cycles')),
              for (final e in cyclesPresent.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: onCycle,
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            icon: Icons.category_outlined,
            value: type,
            active: type != null,
            items: const [
              DropdownMenuItem(value: null, child: Text('Tous les types')),
              DropdownMenuItem(value: 'new', child: Text('Nouvelles')),
              DropdownMenuItem(value: 'reinscription', child: Text('Réinscriptions')),
              DropdownMenuItem(value: 'transfer', child: Text('Transferts')),
            ],
            onChanged: onType,
          ),
          const SizedBox(width: 8),
          _StatusSegment(value: status, onChanged: onStatus),
          const Spacer(),
          if (_hasFilters)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                    SizedBox(width: 4),
                    Text('Réinitialiser',
                        style: TextStyle(
                            color: kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
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
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
          SizedBox(width: 6),
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
        seg('active', 'Validées'),
        seg('pending_validation', 'En attente'),
        seg('rejected', 'Rejetées'),
      ]),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered inscrit${filtered > 1 ? 's' : ''}',
            style: const TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: const TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ]);
}

// ─── Skeleton de chargement (shimmer, calqué sur la vraie page) ──────────────
class _InscriptionsSkeleton extends StatelessWidget {
  const _InscriptionsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
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
