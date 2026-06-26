import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/student_tutor_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/annuaire_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../services/annuaire_pdf_service.dart';
import '../widgets/scope_drilldown_panel.dart';

part 'annuaire_parts.dart';
part 'annuaire_detail.dart';
part 'annuaire_form.dart';

const _kSlug = 'annuaire';

Color _relColor(String rel) => switch (rel) {
      'pere' => kNavy,
      'mere' => const Color(0xFFEC4899),
      'tuteur' => const Color(0xFF0EA5E9),
      _ => kTextMuted,
    };

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ANNUAIRE — répertoire des familles (élève ▸ tuteurs/contacts). Outil de
//  contact terrain + pilotage de la couverture (élèves sans contact). Design
//  plateforme : KPI → couverture par cycle/niveau/classe (drill-down) → filtres
//  → cartes/table → détail famille (tuteurs + CRUD gardé permissions).
//  Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class AnnuaireScreen extends ConsumerWidget {
  const AnnuaireScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Annuaire',
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
  bool _isTable = true;
  bool _onlyGaps = false; // n'afficher que les élèves sans contact
  ScopeSel _scope = const ScopeSel();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  void _reset() => setState(() {
        _search.clear();
        _onlyGaps = false;
        _scope = const ScopeSel();
      });

  bool _inScope(FamilyRow f) {
    if (_scope.cycle != null && f.student.cycleCode != _scope.cycle) {
      return false;
    }
    if (_scope.level != null && f.student.levelCode != _scope.level) {
      return false;
    }
    if (_scope.classId != null && f.student.classId != _scope.classId) {
      return false;
    }
    return true;
  }

  List<FamilyRow> _apply(List<FamilyRow> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((f) {
      if (!_inScope(f)) return false;
      if (_onlyGaps && f.hasContact) return false;
      if (q.isEmpty) return true;
      if (f.student.fullName.toLowerCase().contains(q)) return true;
      if (f.student.matricule.toLowerCase().contains(q)) return true;
      if ((f.student.className ?? '').toLowerCase().contains(q)) return true;
      for (final t in f.tutors) {
        if (t.fullName.toLowerCase().contains(q)) return true;
        if (t.phonePrimary.contains(q)) return true;
        if ((t.phoneSecondary ?? '').contains(q)) return true;
      }
      return false;
    }).toList();
  }

  void _openFamily(FamilyRow f) => showDialog(
        context: context,
        builder: (_) => _FamilyDetail(family: f),
      );

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri)) _snack('Appel impossible', kAccent);
  }

  void _previewPdf(List<FamilyRow> fams) {
    if (fams.isEmpty) {
      _snack('Aucune famille à exporter', kTextMuted);
      return;
    }
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Annuaire des familles',
      subtitle: '${fams.length} élève${fams.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Annuaire.pdf',
      build: (_) => AnnuairePdfService.buildPdf(families: fams, yearLabel: year),
      onDownload: () =>
          AnnuairePdfService.downloadDoc(families: fams, yearLabel: year),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familiesProvider);
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
      data: (allFams) {
        final st = ref.watch(annuaireStatsProvider);
        final filtered = _apply(allFams);
        final hasAny = allFams.isNotEmpty;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(st: st),
              if (hasAny) ...[
                const SizedBox(height: 16),
                ScopeDrilldownPanel(
                  title: 'Couverture contacts',
                  greenHint: 'part d\'élèves avec contact',
                  units: [
                    for (final f in allFams)
                      ScopeUnit(
                        cycleCode: f.student.cycleCode,
                        levelCode: f.student.levelCode,
                        levelOrder: f.student.levelOrder,
                        classId: f.student.classId,
                        className: f.student.className,
                        ok: f.hasContact,
                      ),
                  ],
                  onChanged: (s) => setState(() => _scope = s),
                ),
              ],
              const SizedBox(height: 22),
              _FilterBar(
                searchCtrl: _search,
                isTable: _isTable,
                onlyGaps: _onlyGaps,
                onSearch: (_) => setState(() {}),
                onToggleGaps: () => setState(() => _onlyGaps = !_onlyGaps),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _reset,
              ),
              const SizedBox(height: 16),
              _ResultHeader(
                count: filtered.length,
                total: allFams.length,
                onExportPdf:
                    filtered.isEmpty ? null : () => _previewPdf(filtered),
              ),
              if (_scope.active) ...[
                const SizedBox(height: 10),
                _ActiveFilterChip(
                  label: _scope.label,
                  onClear: () => setState(() => _scope = const ScopeSel()),
                ),
              ],
              const SizedBox(height: 12),
              if (!hasAny)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.contacts_outlined,
                    title: 'Aucun élève inscrit',
                    message:
                        'L\'annuaire des familles se remplit dès que des élèves '
                        'sont inscrits. Les tuteurs s\'ajoutent depuis la fiche '
                        'élève ou ce module.',
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
                _FamilyTable(rows: filtered, onOpen: _openFamily, onCall: _call)
              else
                _FamilyCards(rows: filtered, onOpen: _openFamily, onCall: _call),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.st});
  final AnnuaireStats st;
  @override
  Widget build(BuildContext context) {
    final pct = st.students == 0
        ? 0
        : (st.withContact * 100 / st.students).round();
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.groups_2_rounded, 'Familles', '${st.students}', kNavy,
          'élèves actifs'),
      (Icons.contact_phone_rounded, 'Avec contact', '${st.withContact}',
          kGreen, '$pct% de couverture'),
      (Icons.person_off_rounded, 'Sans contact', '${st.withoutContact}',
          st.withoutContact > 0 ? kRed : kTextMuted, 'à compléter'),
      (Icons.diversity_3_rounded, 'Tuteurs', '${st.tutors}',
          const Color(0xFF0EA5E9),
          st.emergency > 0 ? '${st.emergency} contact(s) urgence' : null),
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
