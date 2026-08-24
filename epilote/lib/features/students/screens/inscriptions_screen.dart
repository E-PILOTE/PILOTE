import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/utils/sortie_motif.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/class_model.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../finance/providers/decompte_du_provider.dart'
    show DecompteDu, decompteDuProvider;
import '../../finance/providers/paiements_provider.dart'
    show kPaymentMethods, paymentMethodLabel, savePayment;
import '../../finance/services/obligation.dart' show EtatObligation;
import '../../finance/services/recu_pdf_service.dart'
    show RecuPaiement, construireRecuPaiement;
import '../widgets/exoneration_card.dart';
import '../widgets/fiche_inscription_actions.dart';
import '../widgets/inscription_form_kit.dart';
import '../widgets/monthly_evolution_card.dart';
import '../widgets/scope_drilldown_panel.dart';
import '../widgets/tuteur_edit_card.dart';
import '../providers/documents_provider.dart' show kRequiredDocTypes;
import '../providers/frais_inscription_provider.dart';
import '../providers/inscriptions_data_provider.dart';
import '../models/eleve_libelles.dart';
import '../models/tutor_draft.dart';
import '../providers/students_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../services/edition_eleve_garde.dart';
import '../services/inscriptions_csv.dart';
import '../services/inscriptions_pdf_service.dart';
import 'add_inscription_screen.dart';
import 'import_eleves_dialog.dart';
import '../../../core/utils/message_erreur.dart';

part 'inscriptions_list_parts.dart';
part 'inscriptions_kpi_parts.dart';
part 'inscriptions_filtres_parts.dart';
part 'inscriptions_page_parts.dart';
part 'inscriptions_actions.dart';
part 'inscriptions_dossier.dart';
part 'inscriptions_frais_card.dart';
part 'inscriptions_edit.dart';
part 'inscriptions_edit_parts.dart';

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
  ScopeSel _scope = const ScopeSel(); // cycle/niveau/classe (panneau répartition)
  String? _filiere;
  String? _type;
  String _status = 'all'; // all | active | pending_validation | rejected
  bool _isTable = true;
  _SortBy _sort = _SortBy.nom;
  bool _sortAsc = true;
  final Set<String> _selected = {}; // ids d'inscriptions sélectionnées (actions groupées)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InscriptionRow> _apply(List<InscriptionRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = all.where((r) {
      if (_scope.cycle != null && r.cycle.code != _scope.cycle) return false;
      if (_scope.level != null && (r.levelCode ?? '') != _scope.level) {
        return false;
      }
      if (_scope.classId != null && r.classId != _scope.classId) return false;
      if (_filiere != null && r.filiereLabel != _filiere) return false;
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
        _scope = const ScopeSel();
        _filiere = _type = null;
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

  void _openDetail(InscriptionRow r) {
    final readOnly = ref.read(yearReadOnlyProvider);
    showDialog(
      context: context,
      builder: (_) => _InscriptionDetailModal(
        row: r,
        readOnly: readOnly,
        onEdit: () {
          Navigator.of(context).pop();
          _openEdit(r);
        },
        onValidate: r.status == 'pending_validation' && !readOnly
            ? () { Navigator.of(context).pop(); _validate(r); }
            : null,
        onReject: r.status == 'pending_validation' && !readOnly
            ? () { Navigator.of(context).pop(); _reject(r); }
            : null,
        onChangeClass: readOnly
            ? null
            : () { Navigator.of(context).pop(); _changeClass(r); },
        onWithdraw: readOnly
            ? null
            : () { Navigator.of(context).pop(); _withdraw(r); },
        onDelete: readOnly
            ? null
            : () { Navigator.of(context).pop(); _delete(r); },
      ),
    );
  }

  void _openEdit(InscriptionRow r) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditStudentModal(row: r),
      );

  // ── Sélection / actions groupées ───────────────────────────────────────────
  void _toggleSelect(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });

  void _toggleSelectAll(List<InscriptionRow> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((r) => r.id));
        } else {
          _selected.removeAll(rows.map((r) => r.id));
        }
      });

  void _clearSelection() => setState(_selected.clear);

  /// Année clôturée : on refuse avant la boucle. Cacher les boutons suffit à
  /// l'usage, mais une action groupée écrit N lignes — le garde vaut son coût.
  bool _refuseAnneeVerrouillee() {
    if (!ref.read(yearReadOnlyProvider)) return false;
    _snack('Année verrouillée — aucune modification possible', kAccent);
    return true;
  }

  Future<void> _bulkValidate(List<InscriptionRow> rows) async {
    if (_refuseAnneeVerrouillee()) return;
    if (writeRefusedForLicense(context)) return;
    final targets = rows
        .where((r) => _selected.contains(r.id) && r.status == 'pending_validation')
        .toList();
    if (targets.isEmpty) {
      _snack('Aucune inscription « en attente » dans la sélection', kTextMuted);
      return;
    }
    final me = _actorOrComplain();
    if (me == null) return;
    var ok = 0;
    String? firstError;
    for (final r in targets) {
      try {
        await validateEnrollment(enrollmentId: r.id, validatedBy: me);
        ok++;
      } catch (e) {
        // Sur trente lignes sélectionnées, un `catch (_) {}` laissait douze
        // échecs invisibles derrière un « 18 validée(s) » satisfaisant.
        firstError ??= messageErreur(e);
      }
    }
    if (mounted) setState(() => _selected.clear());
    final ko = targets.length - ok;
    // On ne barre pas la route d'une validation groupée pour un acte de
    // naissance manquant — mais on ne laisse pas non plus croire que les
    // dossiers étaient complets.
    //
    // ⚠️ Le comptage se faisait dans un `.where()` SYNCHRONE sur une lecture
    // qui, elle, ne l'est pas : `_missingRequiredDocs` rendait toujours une
    // liste vide, donc `incomplets` valait toujours zéro et la mention ne
    // pouvait pas s'afficher. Trente dossiers validés d'un coup passaient pour
    // trente dossiers complets.
    var incomplets = 0;
    for (final t in targets) {
      if ((await _missingRequiredDocs(t.studentId)).isNotEmpty) incomplets++;
    }
    _snack(
      ko == 0
          ? '$ok inscription(s) validée(s)'
              '${incomplets > 0 ? ' · $incomplets dossier(s) incomplet(s)' : ''}'
          : '$ok validée(s) · $ko en échec — $firstError',
      ko == 0 ? kGreen : kRed,
    );
  }

  Future<void> _bulkReject(List<InscriptionRow> rows) async {
    if (_refuseAnneeVerrouillee()) return;
    if (writeRefusedForLicense(context)) return;
    final targets = rows
        .where((r) => _selected.contains(r.id) && r.status == 'pending_validation')
        .toList();
    if (targets.isEmpty) {
      _snack('Aucune inscription « en attente » dans la sélection', kTextMuted);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Rejeter ${targets.length} inscription(s) ?'),
        content: const Text(
            'Les dossiers « en attente » sélectionnés seront rejetés (motif générique).'),
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
    if (ok != true) return;
    final me = _actorOrComplain();
    if (me == null) return;
    var n = 0;
    String? firstError;
    for (final r in targets) {
      try {
        await rejectEnrollment(
            enrollmentId: r.id,
            rejectionReason: 'Rejet groupé',
            validatedBy: me);
        n++;
      } catch (e) {
        firstError ??= messageErreur(e);
      }
    }
    if (mounted) setState(() => _selected.clear());
    final ko = targets.length - n;
    _snack(
      ko == 0
          ? '$n inscription(s) rejetée(s)'
          : '$n rejetée(s) · $ko en échec — $firstError',
      ko == 0 ? kTextMuted : kRed,
    );
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
          child: Text(messageErreur(e), style: TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final st = ref.watch(inscriptionStatsProvider);
        final year = ref.watch(yearInscriptionTotalsProvider).valueOrNull ??
            const YearInscriptionTotals();
        final filtered = _apply(all);
        // Filières OFFERTES par l'école (depuis la structure, même à 0 inscrit)
        // → le filtre est visible pour toute école technique/professionnelle.
        final filieresPresent = st.filieres;
        // Les dossiers encore en attente se lisent dans la colonne du mois où
        // ils ont été déposés, mais PAS dans le cumul — qui ne compte que les
        // validés. Sans un mot, l'écart entre la hauteur des colonnes et la
        // pente de la courbe passe pour une erreur de calcul.
        final enAttenteDatee =
            year.evolution.fold<int>(0, (s, p) => s + p.pending);

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
                  _KpiSection(st: st, year: year),
                  const SizedBox(height: 14),
                  // Dire ce que la page montre. Sans cette ligne, « 2 dossiers »
                  // sous un titre « Inscriptions » se lit comme « cette école a
                  // deux inscriptions » — alors qu'elle en a soixante et une,
                  // toutes validées, et que c'est justement pour ça qu'elles
                  // n'apparaissent pas ici.
                  const _PipelineNotice(),
                  const SizedBox(height: 12),
                  // Presque toutes les écoles tiennent déjà leurs listes sur
                  // Excel ou sur papier. Retaper trois cents noms un par un
                  // dans un formulaire, c'est deux jours de travail — et c'est
                  // le moment où l'on renonce au système.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final fait = await showImportElevesDialog(context);
                        if (fait && mounted) {
                          _snack('Import terminé — les inscriptions attendent '
                              'votre validation', kGreen);
                        }
                      },
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: BorderSide(color: kNavy.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                      ),
                      label: const Text('Importer une liste d\'élèves'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // L'effectif VALIDÉ (cycle/niveau/classe) vit dans la page
                  // Élèves. Ici = guichet des admissions : rythme global +
                  // pipeline par dimension (dossiers en cours). Zéro doublon.
                  // ⚠️ `year.evolution` et NON `st.evolution` : le second se
                  // calculait sur le guichet (`status != 'active'`), donc une
                  // école ayant inscrit puis validé trois cents élèves voyait
                  // une courbe plate sous le titre « Rythme des inscriptions ».
                  //
                  // La section ne DISPARAÎT plus sous deux mois d'historique :
                  // elle s'effaçait sans un mot, et une école de rentrée
                  // cherchait un graphe qu'on lui avait montré ailleurs. Le
                  // widget porte son propre état « pas encore assez ».
                  if (year.evolution.isNotEmpty) ...[
                    const AdminSectionTitle('Rythme des inscriptions',
                        icon: Icons.show_chart_rounded,
                        // « Dossiers reçus » aurait englobé les rejets, qui ne
                        // sont pas tracés : on nomme les deux segments.
                        subtitle:
                            'Entrées validées et dossiers en attente, mois par '
                            'mois (colonnes) — effectif cumulé (aire)'),
                    const SizedBox(height: 12),
                    MonthlyEvolutionCard(
                      points: [
                        for (final p in year.evolution)
                          EvoPoint(p.label, p.count, p.cumul, stack: p.pending),
                      ],
                      barLabel: 'Entrées validées',
                      // La couleur est celle de la carte KPI « En attente » :
                      // le même chiffre porte la même teinte partout sur la
                      // page, on n'a pas à relire la légende.
                      stackLabel: 'En attente de validation',
                      lineLabel: 'Effectif cumulé',
                      note: enAttenteDatee == 0
                          ? null
                          : enAttenteDatee == 1
                              ? 'Un dossier reçu cette année attend encore '
                                  'd\'être validé : il apparaît dans la colonne '
                                  'de son mois de dépôt, pas dans l\'effectif '
                                  'cumulé.'
                              : '$enAttenteDatee dossiers reçus cette année '
                                  'attendent encore d\'être validés : ils '
                                  'apparaissent dans la colonne de leur mois de '
                                  'dépôt, pas dans l\'effectif cumulé.',
                      emptyMessage: 'Pas encore assez d\'historique pour '
                          'tracer un rythme : il faut au moins deux mois '
                          'portant une date d\'inscription.',
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (all.isNotEmpty)
                    ScopeDrilldownPanel(
                      title: 'Dossiers en cours, par classe',
                      metricLabel: '',
                      // Ce panneau compte des DOSSIERS à traiter, pas des
                      // élèves : « 2 élèves » sous un guichet qui en scolarise
                      // soixante et un se lit comme un effectif.
                      unitNoun: 'dossiers',
                      selected: _scope,
                      onSelect: (s) => setState(() => _scope = s),
                      units: [
                        for (final r in all)
                          ScopeUnit(
                            cycleCode: r.cycle.code,
                            levelCode: r.levelCode,
                            levelOrder: r.levelOrder,
                            classId: r.classId,
                            className: r.className,
                            ok: false,
                          ),
                      ],
                    ),
                  const SizedBox(height: 22),
                  _FilterBar(
                    width: w - 48,
                    searchCtrl: _searchCtrl,
                    filiere: _filiere,
                    type: _type,
                    status: _status,
                    isTable: _isTable,
                    readOnly: readOnly,
                    filieresPresent: filieresPresent,
                    onSearch: (_) => setState(() {}),
                    onFiliere: (v) => setState(() => _filiere = v),
                    onType: (v) => setState(() => _type = v),
                    onStatus: (v) => setState(() => _status = v),
                    onToggleView: () => setState(() => _isTable = !_isTable),
                    onReset: _resetFilters,
                    onAdd: _openAdd,
                    onExport: () => _export(filtered),
                  ),
                  if (_scope.active) ...[
                    const SizedBox(height: 12),
                    _ScopeChip(
                      label: _scope.label,
                      onClear: () =>
                          setState(() => _scope = const ScopeSel()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // La bascule sélection ↔ compteur se fait sous les yeux de
                  // l'agent : un fondu court dit que la barre a REMPLACÉ
                  // l'en-tête, là où une substitution sèche donne l'impression
                  // que la page a sauté.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOut,
                    child: _selected.isNotEmpty
                        ? _BulkBar(
                            // La clé porte le COMPTE : sans elle, le fondu ne
                            // rejouerait qu'à l'apparition de la barre et le
                            // nombre changerait sans que rien ne bouge.
                            key: ValueKey(_selected.length),
                            count: _selected.length,
                            readOnly: readOnly,
                            onValidate: () => _bulkValidate(filtered),
                            onReject: () => _bulkReject(filtered),
                            onExport: () {
                              _export(filtered
                                  .where((r) => _selected.contains(r.id))
                                  .toList());
                            },
                            onFiches: () => ouvrirFichesGroupees(
                                context,
                                ref,
                                filtered
                                    .where((r) => _selected.contains(r.id))
                                    .toList()),
                            onClear: _clearSelection,
                          )
                        : _ResultHeader(
                            key: const ValueKey('resultats'),
                            total: all.length,
                            filtered: filtered.length,
                            onExportPdf: filtered.isEmpty
                                ? null
                                : () => _previewPdf(filtered),
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      // Cette page ne liste que les dossiers NON validés. Une
                      // école dont toutes les inscriptions sont traitées y
                      // lisait « Aucune inscription cette année » alors qu'elle
                      // en compte cinq cents — le pire message possible devant
                      // un visiteur. On nomme donc ce que la page montre.
                      child: AdminEmptyState(
                        icon: Icons.task_alt_rounded,
                        title: 'Aucun dossier en instance',
                        message:
                            'Toutes les inscriptions de l\'année sont traitées. '
                            'Les effectifs se consultent dans « Élèves ».',
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
                      selected: _selected,
                      onSelect: _toggleSelect,
                      onSelectAll: (v) => _toggleSelectAll(filtered, v),
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
                      onReopen: _reopen,
                      readOnly: readOnly,
                    )
                  else
                    _InscritsCards(
                      rows: filtered,
                      selected: _selected,
                      onSelect: _toggleSelect,
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

/// Bandeau expliquant que la liste ne contient QUE les dossiers à traiter.
