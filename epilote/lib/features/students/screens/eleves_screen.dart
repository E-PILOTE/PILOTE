import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/photo_avatar.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/class_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/students_provider.dart';
import '../models/eleve_libelles.dart';
import '../models/tutor_draft.dart';
import '../providers/students_registry_provider.dart';
import '../providers/transfers_provider.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../services/attestation_actions.dart';
import '../services/capacite_classe.dart';
import '../services/filtre_eleves.dart';
import '../services/edition_eleve_garde.dart';
import '../services/attestations_pdf_service.dart';
import '../services/students_pdf_service.dart';
import '../widgets/monthly_evolution_card.dart';
import '../widgets/scope_drilldown_panel.dart';
import '../widgets/transfer_destination_picker.dart';
import '../widgets/inscription_form_kit.dart';
import '../widgets/tuteur_edit_card.dart';
import 'add_inscription_screen.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/write_identity.dart';
import '../../../core/utils/sortie_motif.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../services/powersync/avatar_upload.dart'
    show queueAvatarUpload;


part 'eleves_parts.dart';
part 'eleves_liste_parts.dart';
part 'eleves_drawer.dart';
part 'eleves_actions_parts.dart';
part 'eleves_edit.dart';
part 'eleves_kpi_parts.dart';

// ─── Référentiel cycles (couleur / nom / ordre) ──────────────────────────────
Map<String, Color> get _cycleColors => <String, Color>{
  'prescolaire': const Color(0xFFEC4899),
  'primaire': const Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': const Color(0xFFF59E0B),
  'fp': const Color(0xFFF59E0B),
};
const _cycleNames = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Pro.',
  'fp': 'Formation Pro.',
};
Color _cycColor(String? code) => _cycleColors[code ?? ''] ?? kTextMuted;
String _cycName(String? code) => _cycleNames[code ?? ''] ?? 'Non classé';

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ÉLÈVES — l'effectif VALIDÉ de l'école (inscriptions actives ; les
//  dossiers en attente restent dans Inscriptions). Design plateforme : KPI →
//  graphes (cycle/niveau) → filtres → table/cartes (sélection + actions
//  groupées) → tiroir détail (dossier + cycle de vie : changer de classe,
//  annuler l'inscription, transférer/radier, désactiver). Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class ElevesScreen extends ConsumerWidget {
  const ElevesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'eleves',
        title: 'Élèves',
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
  String? _gender; // M | F
  String? _particularite; // interne | affecte | boursier | aide_sociale | …
  ScopeSel _scope = const ScopeSel(); // cycle/niveau/classe (panneau répartition)
  bool _isTable = true;
  bool _sortAsc = true;
  final Set<String> _selected = {}; // ids d'élèves (= enrollmentId) sélectionnés

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _gender = null;
        _particularite = null;
        _scope = const ScopeSel();
      });

  /// Le tri et les filtres vivent dans `services/filtre_eleves.dart` — c'est là
  /// qu'ils se testent, et c'est là qu'on a ajouté ce qui manquait : le filtre
  /// par particularité (la page annonçait « 42 internes » sans jamais pouvoir
  /// en donner la liste) et la recherche par identifiant national.
  List<StudentRow> _apply(List<StudentRow> all) => filtrerEleves(
        all,
        recherche: _search.text,
        sexe: _gender,
        particularite: _particularite,
        cycle: _scope.cycle,
        niveau: _scope.level,
        classeId: _scope.classId,
        triAscendant: _sortAsc,
      );

  // ── Sélection ──────────────────────────────────────────────────────────────
  void _toggle(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
  void _toggleAll(List<StudentRow> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((r) => r.enrollmentId!));
        } else {
          _selected.removeAll(rows.map((r) => r.enrollmentId!));
        }
      });
  void _clearSel() => setState(_selected.clear);

  void _openAdd() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: AddInscriptionScreen(),
        ),
      );

  void _openDrawer(StudentRow s) => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.centerRight,
          child: _StudentDrawer(row: s),
        ),
        transitionBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  // ── Actions groupées ───────────────────────────────────────────────────────
  /// Rend compte d'une action groupée SANS mentir.
  ///
  /// ⚠️ Les deux boucles ci-dessous avalaient chaque exception dans un
  /// `catch (_) {}` puis affichaient « n élève(s) réaffecté(s) » en VERT. Sur
  /// vingt élèves dont aucun ne passait, l'agent lisait « 0 élève(s)
  /// réaffecté(s) » sur fond vert, sans un mot sur la cause, et n'avait aucune
  /// raison de recommencer. Un échec total se présentait comme un succès.
  void _rendreCompte(int reussites, int total, String verbe, String? erreur) {
    if (erreur != null && reussites == 0) {
      _snack('Aucun élève $verbe — $erreur', kRed);
    } else if (erreur != null) {
      _snack('$reussites / $total élève(s) $verbe. '
          'Les autres ont échoué — $erreur', kAccent);
    } else {
      _snack('$reussites élève(s) $verbe', kGreen);
    }
  }

  Future<void> _bulkChangeClass(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    if (targets.isEmpty) return;
    final classId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClassChooserDialog(
          title: 'Changer de classe',
          subtitle: '${targets.length} élève(s) sélectionné(s)'),
    );
    if (classId == null || !mounted) return;
    if (!await _confirmeDebordement(classId, targets.length)) return;
    var n = 0;
    String? erreur;
    for (final r in targets) {
      try {
        await changeEnrollmentClass(
            enrollmentId: r.enrollmentId!, newClassId: classId);
        n++;
      } catch (e) {
        erreur ??= messageErreur(e);
      }
    }
    ref.invalidate(studentsRegistryProvider);
    _clearSel();
    _rendreCompte(n, targets.length, 'réaffecté(s)', erreur);
  }

  /// Prévient si la classe visée débordera, et laisse l'école trancher.
  ///
  /// Le sélecteur affiche « 6e A (24/25) » — l'état AVANT. Déplacer trente
  /// élèves la portait à cinquante-quatre sans un mot, et la surcharge se
  /// découvrait dans la salle le jour de la rentrée.
  Future<bool> _confirmeDebordement(String classId, int aDeplacer) async {
    final classes = ref.read(classesProvider).valueOrNull;
    final cible = classes?.where((c) => c.id == classId).firstOrNull;
    if (cible == null) return true;
    final d = debordementApresDeplacement(
      className: cible.name,
      effectifActuel: cible.studentCount ?? 0,
      capacite: cible.capacity,
      aDeplacer: aDeplacer,
    );
    if (d == null) return true;
    if (!mounted) return false;
    final ok = await _confirm(
      'Cette classe va déborder',
      '${d.message}\n\nC\'est possible, et fréquent. Confirmez si c\'est '
          'bien ce que vous voulez faire.',
      'Déplacer quand même',
      kAccent,
    );
    return ok == true;
  }

  Future<void> _bulkRevert(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    if (targets.isEmpty) return;
    final ok = await _confirm(
      'Annuler l\'inscription de ${targets.length} élève(s) ?',
      'Ils repartiront dans la page Inscriptions (statut « en attente »).',
      'Annuler l\'inscription',
      kAccent,
    );
    if (ok != true) return;
    var n = 0;
    String? erreur;
    for (final r in targets) {
      try {
        await revertEnrollmentToValidation(r.enrollmentId!);
        n++;
      } catch (e) {
        erreur ??= messageErreur(e);
      }
    }
    ref.invalidate(studentsRegistryProvider);
    _clearSel();
    _rendreCompte(n, targets.length, 'renvoyé(s) au pipeline', erreur);
  }

  Future<void> _bulkExport(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    final list = targets.isEmpty ? rows : targets;
    if (list.isEmpty) return;
    try {
      final path = await exportStudentsCsv(list);
      _snack('Export CSV : ${list.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack(messageErreur(e, contexte: 'Export'), kRed);
    }
  }

  void _previewPdf(List<StudentRow> rows) {
    if (rows.isEmpty) return;
    final year = ref.read(activeYearProvider)?.label;
    // ⚠️ LE NOM DE L'ÉCOLE MANQUAIT. Le service l'attend, personne ne le
    // passait : la liste officielle des effectifs — celle qui part au
    // ministère, celle qu'on archive — s'intitulait « Liste des élèves par
    // classe », sans dire de quel établissement. Le seul document de cette page
    // destiné à sortir de l'école ne la nommait pas.
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final schoolName = (school?['name'] as String?)?.trim();
    showPdfPreviewDialog(
      context,
      title: 'Effectif élèves',
      subtitle: '${rows.length} élève${rows.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Eleves.pdf',
      build: (format) => StudentsPdfService.buildPdf(
          rows: rows, yearLabel: year, schoolName: schoolName),
      onDownload: () => StudentsPdfService.downloadDoc(
          rows: rows, yearLabel: year, schoolName: schoolName),
    );
  }

  Future<bool?> _confirm(String title, String body, String ok, Color c) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Retour')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      );

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentsRegistryProvider('eleves'));
    final readOnly = ref.watch(yearReadOnlyProvider);

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
      data: (all) {
        final filtered = _apply(all);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(
                students: all,
                active: _particularite,
                // Le chiffre annonce, la liste répond : cliquer sur « Internes »
                // restreint l'effectif aux 42 que la carte compte. Sans cela, la
                // page affichait un nombre dont elle refusait de donner les noms.
                onSelect: (code) => setState(
                    () => _particularite = _particularite == code ? null : code),
              ),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 22),
                ScopeDrilldownPanel(
                  title: 'Répartition de l\'effectif',
                  metricLabel: '',
                  selected: _scope,
                  onSelect: (s) => setState(() => _scope = s),
                  units: [
                    for (final s in all)
                      ScopeUnit(
                        cycleCode: s.cycleCode,
                        levelCode: s.levelCode,
                        levelOrder: s.levelOrder,
                        classId: s.classId,
                        className: s.className,
                        ok: s.hasPrimaryTutor,
                      ),
                  ],
                ),
              ],
              if (all.length >= 3) ...[
                const SizedBox(height: 22),
                const AdminSectionTitle('Évolution de l\'effectif',
                    icon: Icons.show_chart_rounded,
                    subtitle:
                        'Élèves entrés par mois (barres) et effectif cumulé (courbe)'),
                const SizedBox(height: 12),
                const _EffectifEvolution(),
              ],
              const SizedBox(height: 22),
              _ElevesFilterBar(
                searchCtrl: _search,
                gender: _gender,
                particularite: _particularite,
                isTable: _isTable,
                readOnly: readOnly,
                onSearch: (_) => setState(() {}),
                onGender: (v) => setState(() => _gender = v),
                onParticularite: (v) => setState(() => _particularite = v),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _resetFilters,
                onAdd: _openAdd,
              ),
              if (_scope.active) ...[
                const SizedBox(height: 12),
                _ScopeChip(
                  label: _scope.label,
                  onClear: () => setState(() => _scope = const ScopeSel()),
                ),
              ],
              const SizedBox(height: 16),
              if (_selected.isNotEmpty && !readOnly)
                _BulkBar(
                  count: _selected.length,
                  onChangeClass: () => _bulkChangeClass(filtered),
                  onRevert: () => _bulkRevert(filtered),
                  onExport: () => _bulkExport(filtered),
                  onClear: _clearSel,
                )
              else
                _ResultHeader(
                  total: all.length,
                  filtered: filtered.length,
                  onExportPdf:
                      filtered.isEmpty ? null : () => _previewPdf(filtered),
                ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Aucun élève dans l\'effectif',
                    message:
                        'Les élèves apparaissent ici une fois leur inscription '
                        'VALIDÉE (depuis la page Inscriptions).',
                    actionLabel: readOnly ? null : 'Nouvel élève',
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
                _StudentTable(
                  rows: filtered,
                  sortAsc: _sortAsc,
                  selected: _selected,
                  readOnly: readOnly,
                  onSort: () => setState(() => _sortAsc = !_sortAsc),
                  onSelect: _toggle,
                  onSelectAll: (v) => _toggleAll(filtered, v),
                  onOpen: _openDrawer,
                )
              else
                _StudentCards(
                  rows: filtered,
                  selected: _selected,
                  readOnly: readOnly,
                  onSelect: _toggle,
                  onOpen: _openDrawer,
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
