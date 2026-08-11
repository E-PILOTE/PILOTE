import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/utils/sortie_motif.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/class_model.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../widgets/inscription_form_kit.dart';
import '../widgets/scope_drilldown_panel.dart';
import '../providers/documents_provider.dart' show kRequiredDocTypes;
import '../providers/inscriptions_data_provider.dart';
import '../models/tutor_draft.dart';
import '../providers/students_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../services/inscription_fiche_service.dart';
import '../services/inscriptions_pdf_service.dart';
import 'add_inscription_screen.dart';
import 'import_eleves_dialog.dart';
import '../../../core/utils/message_erreur.dart';

part 'inscriptions_list_parts.dart';
part 'inscriptions_page_parts.dart';
part 'inscriptions_modals.dart';

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

  // ── Verrou LICENCE ─────────────────────────────────────────────────────────
  // Les gestes ci-dessous portent déjà leur propre `try` et leur propre
  // bandeau : on ne peut pas les passer par `runModuleWrite` sans afficher deux
  // messages pour un seul échec. On pose donc le MÊME verrou à la main, en tête
  // de chaque geste — avant la boîte de dialogue, pour ne pas faire saisir un
  // motif de rejet qui sera refusé ensuite.
  //
  // Il manquait ici, et ici seulement : le tiroir élève, l'annuaire, les
  // transferts et les dossiers passaient par `runModuleWrite`. Une école dont
  // l'abonnement avait expiré continuait donc d'inscrire, de valider et de
  // rejeter des dossiers — c'est-à-dire de faire entrer des élèves — pendant
  // que le reste de l'application était en lecture seule.

  Future<void> _changeClass(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final classes = ref.read(classesProvider).valueOrNull ?? const <ClassModel>[];
    final others = classes.where((c) => c.id != r.classId).toList();
    if (others.isEmpty) {
      _snack('Aucune autre classe disponible.', kTextMuted);
      return;
    }
    final picked = await showDialog<ClassModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Réaffecter ${r.fullName}'),
        children: [
          for (final c in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.name)),
                  Text('${c.studentCount ?? 0}'
                      '${c.capacity != null ? '/${c.capacity}' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: kTextMuted)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await changeEnrollmentClass(enrollmentId: r.id, newClassId: picked.id);
      _snack('Élève réaffecté dans ${picked.name}', kGreen);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  Future<void> _withdraw(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final ctrl = TextEditingController();
    // Le motif normalisé est OBLIGATOIRE : c'est lui qui se compte. Le champ
    // libre reste à côté, pour le cas particulier. Sans catégorie, cette
    // sortie deviendrait une ligne de plus dans un total qu'on ne sait pas
    // ventiler — et la déperdition scolaire ne se lit nulle part ailleurs.
    String? motif;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer de la classe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: motif,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Motif *'),
            items: [
              for (final m in motifsPour(transfert: false))
                DropdownMenuItem(value: m.code, child: Text(m.label)),
            ],
            onChanged: (v) => setLocal(() => motif = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Précision (facultatif)',
              hintText: 'Ce que la catégorie ne dit pas',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed:
                motif == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
        ),
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    try {
      await withdrawStudent(
        enrollmentId: r.id,
        motif: motif!,
        reason: ctrl.text.trim().isEmpty ? '' : ctrl.text.trim(),
      );
      _snack('Élève retiré de la classe', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
    ctrl.dispose();
  }

  Future<void> _delete(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer l\'inscription ?'),
        content: Text(
            'L\'inscription de ${r.fullName} pour cette année sera définitivement '
            'supprimée. La fiche élève (identité, tuteurs) est conservée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteEnrollment(r.id);
      _snack('Inscription supprimée', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  /// Pièces obligatoires manquantes au dossier de l'élève, en clair.
  ///
  /// Valider une inscription, c'est faire entrer l'élève dans l'effectif —
  /// et c'est le dernier moment où l'on regarde son dossier. On pouvait le
  /// faire sans acte de naissance ni certificat médical, sans qu'aucun écran
  /// ne le signale ; le manque ne se découvrait qu'au contrôle, des mois plus
  /// tard. On avertit, sans interdire : un dossier se complète souvent après
  /// la rentrée, et bloquer l'entrée d'un enfant pour une photo serait pire
  /// que le mal.
  List<String> _missingRequiredDocs(String studentId) {
    final docs = ref.read(studentDocumentsProvider(studentId)).valueOrNull;
    if (docs == null) return const []; // pas encore lu : on ne présume rien
    final present = {for (final d in docs) d.documentType};
    return [
      for (final t in kRequiredDocTypes)
        if (!present.contains(t)) docTypeLabel(t),
    ];
  }

  /// `true` si l'on peut poursuivre (dossier complet, ou l'agent assume).
  Future<bool> _confirmIncompleteDossier(InscriptionRow r) async {
    final missing = _missingRequiredDocs(r.studentId);
    if (missing.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Dossier incomplet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Il manque au dossier de ${r.fullName} :',
                style: TextStyle(color: kTextPrimary)),
            const SizedBox(height: 8),
            for (final m in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Icon(Icons.circle, size: 6, color: kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(m, style: TextStyle(color: kTextPrimary))),
                ]),
              ),
            const SizedBox(height: 10),
            Text(
              'Vous pouvez valider quand même — la pièce restera signalée '
              'manquante dans le module Documents.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider quand même'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _validate(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    if (!await _confirmIncompleteDossier(r)) return;
    final me = _actorOrComplain();
    if (me == null) return;
    try {
      await validateEnrollment(enrollmentId: r.id, validatedBy: me);
      _snack('Inscription validée', kGreen);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  Future<void> _reject(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
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
    final me = _actorOrComplain();
    if (me == null) { ctrl.dispose(); return; }
    try {
      await rejectEnrollment(
        enrollmentId: r.id,
        rejectionReason:
            ctrl.text.trim().isEmpty ? 'Aucun motif précisé' : ctrl.text.trim(),
        validatedBy: me,
      );
      _snack('Inscription rejetée', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
    ctrl.dispose();
  }

  Future<void> _export(List<InscriptionRow> rows) async {
    if (rows.isEmpty) return;
    try {
      final path = await exportInscriptionsCsv(rows);
      _snack('Export CSV : ${rows.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack(messageErreur(e, contexte: 'Export'), kRed);
    }
  }

  void _previewPdf(List<InscriptionRow> rows) {
    if (rows.isEmpty) return;
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Inscriptions',
      subtitle: '${rows.length} inscription${rows.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Inscriptions.pdf',
      build: (format) =>
          InscriptionsPdfService.buildPdf(rows: rows, yearLabel: year),
      onDownload: () =>
          InscriptionsPdfService.downloadDoc(rows: rows, yearLabel: year),
    );
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  /// L'agent qui valide, ou `null` si son identité n'est pas résolue.
  ///
  /// `class_enrollments.validated_by` est un `uuid` NOT NULL avec clé étrangère
  /// vers `profiles`. Le motif `?? ''` qui régnait ici écrivait une chaîne vide :
  /// SQLite l'accepte, le badge passait « Validée », puis le serveur répondait
  /// `22P02` et PowerSync abandonnait le LOT ENTIER. L'inscription restait « en
  /// attente » partout ailleurs et l'élève n'entrait jamais dans l'effectif — en
  /// emportant au passage tout ce qui avait été saisi dans la même fenêtre.
  /// En validation groupée, la même chaîne vide partait sur N lignes d'un coup.
  String? _actorOrComplain() {
    final id = ref.read(authNotifierProvider).valueOrNull?.id;
    if (isUsableId(id)) return id!.trim();
    _snack(writeIdentityMessage(const ['agent']), kRed);
    return null;
  }

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

  Future<void> _bulkValidate(List<InscriptionRow> rows) async {
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
        firstError ??= '$e';
      }
    }
    if (mounted) setState(() => _selected.clear());
    final ko = targets.length - ok;
    // On ne barre pas la route d'une validation groupée pour un acte de
    // naissance manquant — mais on ne laisse pas non plus croire que les
    // dossiers étaient complets.
    final incomplets = targets
        .where((t) => _missingRequiredDocs(t.studentId).isNotEmpty)
        .length;
    _snack(
      ko == 0
          ? '$ok inscription(s) validée(s)'
              '${incomplets > 0 ? ' · $incomplets dossier(s) incomplet(s)' : ''}'
          : '$ok validée(s) · $ko en échec — $firstError',
      ko == 0 ? kGreen : kRed,
    );
  }

  Future<void> _bulkReject(List<InscriptionRow> rows) async {
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
        firstError ??= '$e';
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
        final filtered = _apply(all);
        // Filières OFFERTES par l'école (depuis la structure, même à 0 inscrit)
        // → le filtre est visible pour toute école technique/professionnelle.
        final filieresPresent = [for (final p in st.byProgram) p.label]..sort();

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
                  _KpiSection(
                    st: st,
                    year: ref.watch(yearInscriptionTotalsProvider).valueOrNull ??
                        const YearInscriptionTotals(),
                  ),
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
                  if (st.evolution.length >= 2) ...[
                    const AdminSectionTitle('Rythme des inscriptions',
                        icon: Icons.show_chart_rounded,
                        subtitle:
                            'Nouvelles inscriptions par mois (barres) et effectif cumulé (courbe)'),
                    const SizedBox(height: 12),
                    _EvolutionCard(points: st.evolution),
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
                  if (_selected.isNotEmpty)
                    _BulkBar(
                      count: _selected.length,
                      onValidate: () => _bulkValidate(filtered),
                      onReject: () => _bulkReject(filtered),
                      onExport: () {
                        _export(filtered
                            .where((r) => _selected.contains(r.id))
                            .toList());
                      },
                      onClear: _clearSelection,
                    )
                  else
                    _ResultHeader(
                      total: all.length,
                      filtered: filtered.length,
                      onExportPdf: filtered.isEmpty
                          ? null
                          : () => _previewPdf(filtered),
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
