import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tutelle.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../admin_groupe/providers/referentiel_national_provider.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';
import '../services/tutelle_pdf_service.dart';
import '../widgets/tutelle_ecole_detail.dart';
import '../widgets/tutelle_ecoles_vue.dart';
import '../widgets/tutelle_groupe_detail.dart';
import '../widgets/tutelle_groupes_vue.dart';
import '../widgets/tutelle_message_dialog.dart';

part 'tutelle_reseau_views.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES GROUPES SCOLAIRES SOUS TUTELLE
//
//  ── LA QUESTION À LAQUELLE CET ÉCRAN RÉPOND ───────────────────────────────
//  « Quels groupes scolaires mon ministère agrée-t-il, et que pèsent-ils ? »
//  Le sujet est le GROUPE — la personne morale qu'on agrée, qu'on convoque,
//  à qui on écrit. Les écoles en découlent : elles appartiennent au groupe.
//
//  ── ⚠️ CE QUE CETTE PAGE NE MONTRE PAS, ET C'EST LE POINT ────────────────
//  Les établissements du ministère lui-même. Un ministère porte deux
//  casquettes — EXPLOITANT et TUTELLE — et la plateforme leur doit deux
//  écrans : « Mes écoles » pour les siennes, celui-ci pour celles des autres.
//
//  Tant que les deux périmètres étaient confondus, cette page mentait. Vu à
//  l'écran le 2026-09-02 sur le compte METP : titre « toutes les écoles sous
//  tutelle METP, y compris celles que vous ne gérez pas », contenu réel =
//  12 écoles dans 1 groupe, et ce groupe était le METP. La vue par groupe
//  affichait une carte unique : celle du ministère qui regardait la page.
//  Voir `reseauSuperviseProvider`.
//
//  ── ⚠️ CE QU'UNE TUTELLE PEUT FAIRE, ET RIEN DE PLUS ─────────────────────
//  La politique `groups_select` limite un `admin_groupe` à SON groupe : un
//  ministère ne peut même pas LIRE la ligne `school_groups` d'un groupe tiers
//  autrement que par les RPC `SECURITY DEFINER` de 0158. Il n'a donc aucun
//  droit d'écriture sur les groupes qu'il supervise, et cet écran ne doit pas
//  faire semblant d'en avoir : les actions possibles sont CONSULTER, ÉCRIRE
//  (circulaire) et EXPORTER. Toute action de gestion ajoutée ici échouerait en
//  42501 — ou pire, échouerait en silence sur un UPDATE.
//
//  ── ⚠️ AUCUN NOM D'ÉLÈVE, JAMAIS ─────────────────────────────────────────
//  Les RPC de 0158 ne rendent que des agrégats. Seule donnée nominative : le
//  chef d'établissement, interlocuteur officiel de la tutelle.
// ════════════════════════════════════════════════════════════════════════════

class TutelleReseauScreen extends ConsumerWidget {
  const TutelleReseauScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const AppShell(
        title: 'Réseau sous tutelle',
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
  FiltreReseau _f = const FiltreReseau();

  /// ⚠️ VRAI par défaut : le sujet de la page est le GROUPE scolaire. La liste
  /// d'établissements reste accessible, mais elle est le second niveau — une
  /// tutelle agrée des personnes morales, pas des bâtiments.
  bool _parGroupe = true;
  bool _export = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(FiltreReseau f) => setState(() => _f = f);

  @override
  Widget build(BuildContext context) {
    // Garde d'écran : la RPC refuse déjà (42501), mais un utilisateur ne doit
    // pas découvrir un droit manquant par un message d'erreur technique.
    //
    // ⚠️ LE CHARGEMENT N'EST PAS UN REFUS. Avec `valueOrNull ?? false`, un
    // ministre légitime lisait « Réservé aux ministères de tutelle » le temps
    // de l'aller-retour — un écran qui commence par accuser à tort.
    final droit = ref.watch(groupeAdministreReferentielProvider);
    if (droit.isLoading) return const ListShimmer();
    if (!(droit.valueOrNull ?? false)) return const _PasDeTutelle();

    final async = ref.watch(reseauSuperviseProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      // ⚠️ Pas de repli sur une liste vide : « 0 groupe » à cause d'une panne
      // réseau se lirait comme un réseau vide.
      error: (e, _) => _ErreurReseau(
        message: messageErreur(e, contexte: 'Réseau sous tutelle'),
        onRetry: () => ref.invalidate(tutelleReseauProvider),
      ),
      data: _contenu,
    );
  }

  Widget _contenu(ReseauSupervise d) {
    final tutelle = ref.watch(tutelleDuGroupeProvider).valueOrNull;

    // Rien à superviser : on le DIT, on n'affiche pas un tableau vide sous des
    // KPI à zéro.
    if (d.estVide) {
      return _AucunGroupeSupervise(
        tutelle: tutelle,
        nbEcolesPropres: d.nbEcolesPropres,
      );
    }

    final ecoles = filtrerEcoles(d.ecoles, _f);
    final bilan = BilanReseau.de(ecoles);
    final selection = descriptionDesFiltres(_f, nomGroupe: _nomGroupe(d));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnTeteTutelle(
            tutelle: tutelle,
            nbGroupes: d.groupes.length,
            nbEcoles: d.ecoles.length,
            nbEcolesPropres: d.nbEcolesPropres,
            exportEnCours: _export,
            onActualiser: () => ref.invalidate(tutelleReseauProvider),
            onExporter: () => _exporterEtat(d, ecoles, bilan, tutelle),
          ),
          const SizedBox(height: 20),
          KpiGrid(items: _kpis(bilan, d, ecoles)),
          const SizedBox(height: 20),
          ListFilterBar(
            searchCtrl: _search,
            searchHint:
                'Rechercher un groupe, un établissement, un code, une ville…',
            isTableView: !_parGroupe,
            addLabel: '',
            addIcon: Icons.add,
            // ⚠️ `null` : une tutelle ne CRÉE pas le groupe d'un tiers, et
            // `groups_insert` est réservé au super_admin. Le bouton n'a pas à
            // exister.
            onAdd: null,
            onToggleView: () => setState(() => _parGroupe = !_parGroupe),
            onSearchChange: (v) => _set(_f.copyWith(recherche: v)),
            onReset: _reinitialiser,
            filters: _filtres(d.ecoles),
          ),
          if (selection != null) ...[
            const SizedBox(height: 12),
            _RappelSelection(texte: selection, onEffacer: _reinitialiser),
          ],
          const SizedBox(height: 16),
          _enTeteResultat(d, ecoles),
          const SizedBox(height: 12),
          if (_parGroupe)
            TutelleGroupesVue(
              groupes: d.groupes,
              ecoles: ecoles,
              onOuvrirFiche: (g, sesEcoles) => _ouvrirGroupe(g, sesEcoles, tutelle),
              onVoirEcoles: _voirLesEcolesDe,
              onEcrire: _ecrireA,
            )
          else
            TutelleEcolesVue(
              ecoles: ecoles,
              onOuvrir: (e) => ouvrirFicheEcole(context, e, tutelle: tutelle),
            ),
        ],
      ),
    );
  }

  Widget _enTeteResultat(ReseauSupervise d, List<TutelleEcole> ecoles) {
    if (!_parGroupe) {
      return ListResultHeader(
          total: d.ecoles.length, filtered: ecoles.length, noun: 'école');
    }
    // En vue groupes, on compte les GROUPES retenus : afficher « 11 écoles sur
    // 11 » au-dessus de cinq cartes de groupe ne dit pas ce qu'on regarde.
    final retenus = ecolesParGroupe(ecoles).keys.length;
    return ListResultHeader(
      total: d.groupes.length,
      filtered: retenus,
      noun: 'groupe scolaire',
      nounPlural: 'groupes scolaires',
    );
  }

  void _reinitialiser() {
    _search.clear();
    _set(const FiltreReseau());
  }

  void _voirLesEcolesDe(TutelleGroupe g) => setState(() {
        _parGroupe = false;
        _f = _f.copyWith(groupId: g.id);
      });

  void _ouvrirGroupe(
    TutelleGroupe g,
    List<TutelleEcole> sesEcoles,
    String? tutelle,
  ) =>
      ouvrirFicheGroupe(
        context,
        g,
        ecoles: sesEcoles,
        tutelle: tutelle,
        onVoirDansLaListe: () => _voirLesEcolesDe(g),
        onEcrire: () => _ecrireA(g),
      );

  /// Écrire au groupe [g] — par la messagerie, pas par un canal dédié.
  ///
  /// La plateforme portait déjà trois canaux (annonces, messagerie, tickets) ;
  /// la circulaire de tutelle en ajoutait un quatrième pour un objet dont la
  /// base ne comptait aucune ligne. Un ministère écrit à un groupe comme il
  /// écrit à n'importe qui — le geste ne s'apprend qu'une fois.
  void _ecrireA(TutelleGroupe g) => ouvrirMessageGroupe(context, g);

  /// Le nom du groupe filtré, pour que la phrase de sélection le NOMME — un
  /// identifiant technique dans un document officiel n'apprend rien.
  String? _nomGroupe(ReseauSupervise d) {
    final id = _f.groupId;
    if (id == null) return null;
    for (final g in d.groupes) {
      if (g.id == id) return g.nom;
    }
    return null;
  }

  // ── L'état du réseau, en document ────────────────────────────────────────
  //  Construit UNE FOIS : les mêmes octets alimentent l'aperçu et le fichier
  //  déposé, donc la référence et l'heure lues à l'écran sont celles du
  //  document remis.
  Future<void> _exporterEtat(
    ReseauSupervise d,
    List<TutelleEcole> ecoles,
    BilanReseau bilan,
    String? tutelle,
  ) async {
    if (_export) return;
    setState(() => _export = true);
    final messenger = ScaffoldMessenger.of(context);
    final selection = descriptionDesFiltres(_f, nomGroupe: _nomGroupe(d));
    try {
      final octets = await TutelleReseauPdfService.buildReseau(
        groupes: d.groupes,
        ecoles: ecoles,
        bilan: bilan,
        tutelle: tutelle,
        selection: selection,
      );
      if (!mounted) return;
      await showPdfPreviewDialog(
        context,
        title: 'État du réseau sous tutelle',
        subtitle: '${sigleTutelleOuTiret(tutelle)} · '
            '${bilan.nbGroupes} groupe(s) · '
            '${bilan.nbEcoles} établissement(s)',
        pdfFileName: 'Etat_du_reseau.pdf',
        accent: couleurTutelle(tutelle),
        build: (_) async => octets,
        onDownload: () => TutelleReseauPdfService.enregistrerReseau(
          groupes: d.groupes,
          ecoles: ecoles,
          bilan: bilan,
          tutelle: tutelle,
          selection: selection,
          bytes: octets,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'État du réseau')),
        backgroundColor: kRed,
      ));
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  List<ListFilterDropdown> _filtres(List<TutelleEcole> toutes) {
    final depts = departementsDe(toutes);
    final types = typesEtablissementDe(toutes);
    return [
      ListFilterDropdown(
        icon: Icons.account_balance_rounded,
        label: 'Secteur',
        value: _f.secteur ?? 'tous',
        items: const {
          'tous': 'Public et privé',
          'public': 'Public',
          'prive': 'Privé'
        },
        onChanged: (v) => _set(_f.copyWith(secteur: v == 'tous' ? null : v)),
      ),
      ListFilterDropdown(
        icon: Icons.map_rounded,
        label: 'Département',
        value: _f.departement ?? 'tous',
        items: {'tous': 'Tous', for (final d in depts) d: d},
        onChanged: (v) => _set(_f.copyWith(departement: v == 'tous' ? null : v)),
      ),
      // N'apparaît que si au moins une école est typée : proposer un filtre
      // qui ne rendrait jamais rien est pire que ne rien proposer.
      if (types.isNotEmpty)
        ListFilterDropdown(
          icon: Icons.school_rounded,
          label: 'Type',
          value: _f.typeEtablissement ?? 'tous',
          items: {'tous': 'Tous', for (final t in types) t: t},
          onChanged: (v) =>
              _set(_f.copyWith(typeEtablissement: v == 'tous' ? null : v)),
        ),
      ListFilterDropdown(
        icon: Icons.verified_outlined,
        label: 'Agrément',
        value: switch (_f.agrement) {
          FiltreAgrement.tous => 'tous',
          FiltreAgrement.declare => 'declare',
          FiltreAgrement.nonDeclare => 'non',
        },
        // ⚠️ « non déclaré », jamais « non agréé » : la plateforme enregistre
        // une mention, elle n'instruit aucun dossier.
        items: const {
          'tous': 'Tous',
          'declare': 'Numéro déclaré',
          'non': 'Non déclaré',
        },
        onChanged: (v) => _set(_f.copyWith(
          agrement: switch (v) {
            'declare' => FiltreAgrement.declare,
            'non' => FiltreAgrement.nonDeclare,
            _ => FiltreAgrement.tous,
          },
        )),
      ),
      // Le filtre existait dans `FiltreReseau` sans commande pour l'actionner.
      // Un établissement fermé pèse sur les totaux d'un état de rentrée : la
      // tutelle doit pouvoir l'écarter, et VOIR qu'elle l'a écarté.
      ListFilterDropdown(
        icon: Icons.toggle_on_outlined,
        label: 'Activité',
        value: _f.actifSeulement ? 'actifs' : 'tous',
        items: const {
          'tous': 'Actifs et inactifs',
          'actifs': 'Établissements actifs',
        },
        onChanged: (v) => _set(_f.copyWith(actifSeulement: v == 'actifs')),
      ),
    ];
  }

  /// ⚠️ Le PREMIER indicateur est le nombre de GROUPES, pas d'écoles : c'est
  /// le sujet de la page. Et le partage public/privé se compte en GROUPES —
  /// un ministère agrée des personnes morales, il ne compte pas des bâtiments
  /// pour savoir combien d'opérateurs privés il supervise.
  List<KpiData> _kpis(
      BilanReseau b, ReseauSupervise d, List<TutelleEcole> retenues) {
    final part = b.partFilles;
    final occ = b.tauxOccupation;
    final ids = ecolesParGroupe(retenues).keys.toSet();
    final vus = [
      for (final g in d.groupes)
        if (ids.contains(g.id)) g,
    ];
    final prives = vus.where((g) => !g.estPublic).length;

    return [
      KpiData(
        label: 'Groupes scolaires',
        value: fmtInt(vus.length),
        sub: '$prives privé${prives > 1 ? 's' : ''} · '
            '${vus.length - prives} public${vus.length - prives > 1 ? 's' : ''}',
        icon: Icons.corporate_fare_rounded,
        color: kNavy,
      ),
      KpiData(
        label: 'Établissements',
        value: fmtInt(b.nbEcoles),
        sub: '${fmtInt(b.nbPrive)} privé(s) · ${fmtInt(b.nbPublic)} public(s)',
        icon: Icons.account_balance_rounded,
        color: kAccent,
      ),
      KpiData(
        label: 'Élèves',
        value: fmtInt(b.nbEleves),
        sub: part == null ? 'aucun effectif' : '${part.round()} % de filles',
        icon: Icons.groups_rounded,
        color: kGreen,
        progressValue: part == null ? null : part / 100,
      ),
      KpiData(
        label: 'Personnel',
        value: fmtInt(b.nbPersonnel),
        sub: '${fmtInt(b.nbClasses)} classes',
        icon: Icons.badge_rounded,
        color: const Color(0xFF0EA5E9),
      ),
      KpiData(
        label: 'Agrément déclaré',
        value: '${fmtInt(b.nbAgrementDeclare)} / ${fmtInt(b.nbEcoles)}',
        // ⚠️ Ne dit PAS « non agréées ». Un numéro absent n'est pas un
        // établissement en infraction : c'est une case vide.
        sub: 'écoles ayant saisi un numéro',
        icon: Icons.verified_outlined,
        color: const Color(0xFF7C3AED),
        progressValue: b.nbEcoles == 0 ? null : b.nbAgrementDeclare / b.nbEcoles,
      ),
      KpiData(
        label: 'Occupation',
        value: occ == null ? '—' : '${occ.round()} %',
        // La complétude est DITE : un taux calculé sur la moitié des écoles
        // n'est pas le taux du réseau.
        sub: b.capaciteComplete
            ? 'capacité connue partout'
            : '${b.nbCapaciteConnue} / ${b.nbEcoles} écoles renseignées',
        icon: Icons.event_seat_rounded,
        color: const Color(0xFFFF6B35),
        progressValue: occ == null ? null : (occ / 100).clamp(0.0, 1.0),
      ),
    ];
  }
}
