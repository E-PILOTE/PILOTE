import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/annuaire_filter_bar.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../communication/widgets/user_avatar.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart'
    show scopeCycleName, scopeCycleOrder;
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/agent_creation_provider.dart';
import '../providers/staff_directory_provider.dart';
import '../providers/staff_dossier_provider.dart'
    show employmentStatusLabel, kEmploymentStatuses;
import '../services/personnel_export_service.dart';
import '../widgets/staff_kit.dart';
import 'agent_creation_dialog.dart';
import 'agent_fiche_dialog.dart';
import 'personnel_dossier_sheet.dart';
import '../../../core/utils/message_erreur.dart';

part 'personnel_views.dart';
part 'personnel_cycle_kpis.dart';

const _kSlug = 'personnel';

// ════════════════════════════════════════════════════════════════════════════
//  PERSONNEL — l'annuaire de l'établissement
//
//  ── L'ORDRE DE LA PAGE, ET POURQUOI ────────────────────────────────────────
//  1. les chiffres d'ensemble (effectif, actifs, enseignants, fonctionnaires) ;
//  2. les enseignants PAR CYCLE — la question que pose un chef d'établissement
//     avant toute autre : « ai-je de quoi couvrir le collège ? » ;
//  3. la répartition par axe, cliquable, qui sert de premier filtre ;
//  4. LA BARRE D'OUTILS, juste au-dessus de la liste : chercher, filtrer,
//     basculer cartes/tableau, exporter, enregistrer un agent ;
//  5. la liste.
//
//  ⚠️ Rien de ce qui agit sur la liste ne remonte dans l'en-tête de page. Un
//  bouton posé loin de ce qu'il modifie oblige l'œil à faire l'aller-retour
//  pour comprendre ce qui vient de changer. Les widgets de la barre sont ceux
//  de l'annuaire admin groupe (`core/widgets/annuaire_filter_bar.dart`) — un
//  agent qui passe d'un espace à l'autre retrouve les mêmes gestes.
//
//  ── CE QUE L'ÉCOLE PEUT, ET CE QU'ELLE NE PEUT PAS ─────────────────────────
//  Elle CONSTATE une arrivée (avec son acte), elle CORRIGE une fiche, elle
//  ANNULE une saisie qui n'a rien produit. Elle ne mute pas, ne transfère pas,
//  ne radie pas : ce sont des actes de l'autorité de tutelle, et ils vivent
//  dans l'espace admin groupe. Aucun de ces boutons n'existe ici — ce que
//  l'école ne peut pas faire ne doit pas s'afficher.
// ════════════════════════════════════════════════════════════════════════════
class PersonnelScreen extends ConsumerWidget {
  const PersonnelScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Personnel',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  // ── L'état de filtrage, entier ────────────────────────────────────────────
  // Un seul jeu de filtres : chaque bloc POSE le filtre correspondant au lieu
  // d'en tenir un second en parallèle. Deux filtres pour une même dimension
  // donnent des listes qu'on ne sait plus expliquer.
  //
  // ⚠️ LA BARRE DE SEGMENTS NE PORTE PLUS QU'UN AXE, ET C'EST VOLONTAIRE.
  // Elle était pilotée par une bascule « Répartir par : Catégorie · Statut ·
  // Cycle ». Or le statut est déjà montré par les cartes « Personnel par
  // statut » ET filtré par le menu Statut de la barre d'outils ; le cycle de
  // même. La page posait donc TROIS fois la même question, et cliquer une
  // carte faisait basculer la bascule — le même choix apparaissait
  // sélectionné à deux endroits, sans qu'on sache lequel commandait.
  //
  // Reste la CATÉGORIE (direction, enseignement, administratif…), la seule
  // dimension qui n'existe nulle part ailleurs : la barre s'y tient.
  static const _axis = StaffAxis.categorie;
  final _search = TextEditingController();
  String _q = '';
  StaffCategory? _categorie;
  String? _fonction;
  String? _statutEmploi;
  String? _cycle;
  String _actif = 'all'; // all | active | inactive
  bool _table = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtre =>
      _categorie != null ||
      _fonction != null ||
      _statutEmploi != null ||
      _cycle != null ||
      _actif != 'all' ||
      _q.trim().isNotEmpty;

  void _reinitialiser() => setState(() {
        _search.clear();
        _q = '';
        _categorie = null;
        _fonction = null;
        _statutEmploi = null;
        _cycle = null;
        _actif = 'all';
      });

  String? get _schoolName =>
      ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;

  /// La catégorie posée — pour que la barre de segments montre la même chose
  /// que la liste en dessous.
  String? get _segmentActif => _categorie?.name;

  void _poserSegment(String? key) => setState(() {
        _categorie = key == null
            ? null
            : StaffCategory.values.firstWhere((c) => c.name == key,
                orElse: () => StaffCategory.autres);
      });

  List<StaffMember> _appliquer(List<StaffMember> all) {
    final q = _q.trim().toLowerCase();
    return [
      for (final a in all)
        if ((_categorie == null || staffCategory(a.role) == _categorie) &&
            (_fonction == null || a.role == _fonction) &&
            (_statutEmploi == null ||
                staffSegKey(a, StaffAxis.statut) == _statutEmploi) &&
            (_cycle == null || staffSegKey(a, StaffAxis.cycle) == _cycle) &&
            (_actif == 'all' ||
                (_actif == 'active' && a.isActive) ||
                (_actif == 'inactive' && !a.isActive)) &&
            (q.isEmpty || a.searchBlob.contains(q)))
          a
    ];
  }

  void _exportPdf(List<StaffMember> agents) => showPdfPreviewDialog(
        context,
        title: 'Annuaire du personnel',
        subtitle: '${agents.length} agents',
        pdfFileName: 'Annuaire_personnel.pdf',
        build: (_) => PersonnelExportService.buildPdf(
            agents: agents, schoolName: _schoolName),
        onDownload: () => PersonnelExportService.downloadPdf(
            agents: agents, schoolName: _schoolName),
      );

  /// Enregistrer un agent qui se présente avec son acte d'affectation.
  ///
  /// Seul geste EN LIGNE de cet écran : un identifiant de connexion vit sur le
  /// serveur, il ne peut pas être fabriqué hors ligne. Le dialogue le dit
  /// plutôt que d'échouer sans explication.
  Future<void> _enregistrerAgent() async {
    if (await showAgentCreationDialog(context) && mounted) {
      ref.invalidate(staffDirectoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agent enregistré — remettez-lui ses identifiants')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffDirectoryProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (all) {
        final segs = staffSegments(all, _axis, okOf: (a) => a.isActive);
        final agents = _appliquer(all);

        final actifs = all.where((a) => a.isActive).length;
        final enseignants = all.where((a) => a.role == 'enseignant').length;
        // ⚠️ « 0 fonctionnaire » et « on ne sait pas » ne sont pas la même
        // chose. Les agents repris de l'existant n'ont aucun statut : afficher
        // zéro titulaire dans un lycée d'État serait un contresens, et le
        // ministère le lirait comme tel. Tant qu'il en manque, la carte dit ce
        // qui reste à faire — et redevient un compteur une fois le travail
        // terminé.
        final sansStatut =
            all.where((a) => (a.employmentStatus ?? '').isEmpty).length;

        // Les fonctions réellement présentes — proposer « Infirmier » à une
        // école qui n'en a pas produit une liste vide et un doute.
        final fonctions = {for (final a in all) a.role}.toList()
          ..sort((x, y) => staffRoleLabel(x).compareTo(staffRoleLabel(y)));
        final statuts = {
          for (final a in all)
            if ((a.employmentStatus ?? '').isNotEmpty) a.employmentStatus!
        }.toList()
          ..sort();
        final cycles = {
          for (final a in all)
            if ((a.teachingCycle ?? '').isNotEmpty) a.teachingCycle!
        }.toList()
          ..sort((x, y) => scopeCycleOrder(x).compareTo(scopeCycleOrder(y)));

        final peutEnregistrer =
            ref.watch(contexteCreationAgentProvider).valueOrNull?.autorise ??
                false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ⚠️ Pas de carte de titre ici. La barre d'application affiche
            // déjà « Personnel » deux centimètres plus haut : une carte qui le
            // répète coûte une hauteur d'écran entière et n'apprend rien. La
            // page commence donc par ce qu'on vient y chercher — les chiffres.
            VsHeroKpis(cards: [
              (Icons.groups_2_rounded, 'Effectif', '${all.length}', kNavy,
                  'agents'),
              (Icons.verified_user_rounded, 'Actifs', '$actifs', kGreen,
                  '${all.length - actifs} inactifs'),
              (Icons.school_rounded, 'Enseignants', '$enseignants',
                  const Color(0xFF0EA5E9), 'corps enseignant'),
              // ⚠️ Une TÂCHE, pas un compteur : « combien de fonctionnaires »
              // est déjà répondu par les cartes « Personnel par statut » juste
              // en dessous. Cette carte ne paraît que tant qu'il reste des
              // statuts à saisir, et disparaît le travail fini.
              if (sansStatut > 0)
                (Icons.badge_outlined, 'Statut à renseigner', '$sansStatut',
                    kAccent, 'sur ${all.length} agents'),
            ]),
            const SizedBox(height: 18),
            _EnseignantsParCycle(
              agents: all,
              selected: _cycle,
              onSelect: (c) => setState(() => _cycle = _cycle == c ? null : c),
            ),
            const SizedBox(height: 18),
            // Qui est fonctionnaire, qui ne l'est pas : la question que le
            // ministère posera, lisible sans cliquer sur un onglet.
            _PersonnelParStatut(
              agents: all,
              selected: _statutEmploi,
              onSelect: (s) =>
                  setState(() => _statutEmploi = _statutEmploi == s ? null : s),
            ),
            const SizedBox(height: 18),
            const VsSectionLabel(
                icon: Icons.category_rounded, text: 'Personnel par catégorie'),
            const SizedBox(height: 12),
            StaffSegmentBar(
              segments: segs,
              selected: _segmentActif,
              onSelect: _poserSegment,
              metricLabel: 'actifs',
            ),
            const SizedBox(height: 14),
            _DistributionBar(segments: segs),
            const SizedBox(height: 18),
            // ── Tout ce qui agit sur la liste, juste au-dessus d'elle ───────
            AnnuaireFilterBar(
              searchCtrl: _search,
              searchHint:
                  'Rechercher un agent (nom, matricule) parmi ${all.length}…',
              onSearchChange: (v) => setState(() => _q = v),
              isTableView: _table,
              onToggleView: () => setState(() => _table = !_table),
              onReset: _reinitialiser,
              hasActiveFilters: _filtre,
              actions: [
                AnnuaireIconAction(
                  icon: Icons.picture_as_pdf_outlined,
                  tooltip: agents.isEmpty
                      ? 'Rien à exporter'
                      : 'Exporter l\'annuaire en PDF',
                  onTap: agents.isEmpty ? null : () => _exportPdf(agents),
                  color: const Color(0xFF7C3AED),
                ),
              ],
              primaryAction: peutEnregistrer
                  ? AnnuairePrimaryAction(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Enregistrer un agent',
                      onTap: _enregistrerAgent,
                    )
                  : null,
              filters: [
                AnnuaireDropdown<String?>(
                  icon: Icons.badge_outlined,
                  label: 'Fonction',
                  value: _fonction,
                  active: _fonction != null,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Toutes les fonctions')),
                    for (final r in fonctions)
                      DropdownMenuItem(
                          value: r,
                          child: Text(staffRoleLabel(r),
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _fonction = v),
                ),
                AnnuaireDropdown<String?>(
                  icon: Icons.work_outline_rounded,
                  label: 'Statut',
                  value: _statutEmploi,
                  active: _statutEmploi != null,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tous les statuts')),
                    for (final s in statuts)
                      DropdownMenuItem(
                          value: s,
                          child: Text(employmentStatusLabel(s),
                              overflow: TextOverflow.ellipsis)),
                    if (all.any((a) => (a.employmentStatus ?? '').isEmpty))
                      const DropdownMenuItem(
                          value: '—', child: Text('Statut non renseigné')),
                  ],
                  onChanged: (v) => setState(() => _statutEmploi = v),
                ),
                AnnuaireDropdown<String?>(
                  icon: Icons.school_outlined,
                  label: 'Cycle',
                  value: _cycle,
                  active: _cycle != null,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tous les cycles')),
                    for (final c in cycles)
                      DropdownMenuItem(
                          value: c, child: Text(scopeCycleName(c))),
                    // Nommé, jamais tu : un enseignant sans classe affectée
                    // n'apparaît dans aucun cycle et doit rester trouvable.
                    const DropdownMenuItem(
                        value: '—', child: Text('Hors enseignement')),
                  ],
                  onChanged: (v) => setState(() => _cycle = v),
                ),
                AnnuaireStatusSegment(
                    value: _actif, onChanged: (v) => setState(() => _actif = v)),
              ],
            ),
            const SizedBox(height: 16),
            AnnuaireResultHeader(
                total: all.length, filtered: agents.length, unit: 'agent'),
            const SizedBox(height: 12),
            if (agents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: AdminEmptyState(
                  icon: Icons.person_search_outlined,
                  title: all.isEmpty ? 'Aucun agent' : 'Aucun résultat',
                  message: all.isEmpty
                      ? 'Enregistrez les agents affectés à votre établissement.'
                      : 'Aucun agent ne correspond à ces filtres.',
                  actionLabel: all.isEmpty ? null : 'Réinitialiser les filtres',
                  onAction: all.isEmpty ? null : _reinitialiser,
                ),
              )
            else if (_table)
              _PersonnelTable(
                  agents: agents,
                  onOpen: _ouvrir,
                  onCorriger: peutEnregistrer ? _corriger : null)
            else
              _PersonnelCards(
                  agents: agents,
                  onOpen: _ouvrir,
                  onCorriger: peutEnregistrer ? _corriger : null),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }

  void _ouvrir(StaffMember a) => showStaffDossier(context, a.id);

  Future<void> _corriger(StaffMember a) async {
    if (await showAgentFicheDialog(context, a) && mounted) {
      ref.invalidate(staffDirectoryProvider);
    }
  }
}
