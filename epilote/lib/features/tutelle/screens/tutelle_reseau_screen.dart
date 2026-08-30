import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tutelle.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../admin_groupe/providers/referentiel_national_provider.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';

part 'tutelle_reseau_views.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RÉSEAU DE LA TUTELLE
//
//  ── LA QUESTION À LAQUELLE CET ÉCRAN RÉPOND ───────────────────────────────
//  « Combien d'élèves y a-t-il dans les écoles de MON ministère ? » — y compris
//  celles que le ministère ne possède pas. Aucun écran n'y répondait : « Mes
//  écoles » ne montre que les établissements du groupe, et le MEPSA n'en
//  possède que 14 sur les 25 placées sous sa tutelle.
//
//  ── ⚠️ DEUX NOMBRES QUI NE S'ADDITIONNENT PAS ─────────────────────────────
//  Un ministère porte deux casquettes : EXPLOITANT (ses écoles) et TUTELLE
//  (toutes les écoles de son ministère). Cet écran affiche la SECONDE, et le
//  dit dans son sous-titre. Les confondre produirait un chiffre plausible et
//  faux — le genre qui finit dans un état ministériel.
//
//  ── ⚠️ CE QUE CET ÉCRAN NE MONTRERA JAMAIS ────────────────────────────────
//  Aucun nom d'élève, aucune note, aucune absence, aucun paiement. Les RPC de
//  la migration 0158 ne les rendent pas, et c'est délibéré : un ministère
//  supervise des établissements, il ne tient pas le registre nominatif du pays.
//  Seule exception, administrative : le chef d'établissement.
//
//  Rien non plus sur les abonnements. Ce qu'un groupe privé paie à E-PILOTE ne
//  regarde pas son ministère.
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
  bool _parGroupe = false;

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
    final peut =
        ref.watch(groupeAdministreReferentielProvider).valueOrNull ?? false;
    if (!peut) return const _PasDeTutelle();

    final async = ref.watch(tutelleReseauProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      // ⚠️ Pas de repli sur une liste vide : « 0 école » à cause d'une panne
      // réseau se lirait comme un réseau vide.
      error: (e, _) => _ErreurReseau(
        message: messageErreur(e, contexte: 'Réseau sous tutelle'),
        onRetry: () => ref.invalidate(tutelleReseauProvider),
      ),
      data: (d) {
        final ecoles = filtrerEcoles(d.ecoles, _f);
        final bilan = BilanReseau.de(ecoles);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EnTeteTutelle(
                tutelle: ref.watch(tutelleDuGroupeProvider).valueOrNull,
                nbGroupes: d.groupes.length,
                nbEcoles: d.ecoles.length,
              ),
              const SizedBox(height: 20),
              KpiGrid(items: _kpis(bilan)),
              const SizedBox(height: 20),
              ListFilterBar(
                searchCtrl: _search,
                searchHint: 'Rechercher une école, un code, une ville, un groupe…',
                isTableView: !_parGroupe,
                addLabel: '',
                addIcon: Icons.add,
                // ⚠️ `null` : une tutelle ne CRÉE pas l'école d'un autre
                // groupe. Le bouton n'a pas à exister.
                onAdd: null,
                onToggleView: () => setState(() => _parGroupe = !_parGroupe),
                onSearchChange: (v) => _set(_f.copyWith(recherche: v)),
                onReset: () {
                  _search.clear();
                  _set(const FiltreReseau());
                },
                filters: _filtres(d.ecoles),
              ),
              const SizedBox(height: 16),
              ListResultHeader(
                total: d.ecoles.length,
                filtered: ecoles.length,
                noun: 'école',
              ),
              const SizedBox(height: 12),
              if (_parGroupe)
                TutelleGroupesVue(
                  groupes: d.groupes,
                  ecoles: ecoles,
                  onVoirEcoles: (g) => setState(() {
                    _parGroupe = false;
                    _f = _f.copyWith(groupId: g.id);
                  }),
                )
              else
                TutelleEcolesVue(ecoles: ecoles),
            ],
          ),
        );
      },
    );
  }

  List<ListFilterDropdown> _filtres(List<TutelleEcole> toutes) {
    final depts = departementsDe(toutes);
    final types = typesEtablissementDe(toutes);
    return [
      ListFilterDropdown(
        icon: Icons.account_balance_rounded,
        label: 'Secteur',
        value: _f.secteur ?? 'tous',
        items: const {'tous': 'Public et privé', 'public': 'Public', 'prive': 'Privé'},
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
    ];
  }

  List<KpiData> _kpis(BilanReseau b) {
    final part = b.partFilles;
    final occ = b.tauxOccupation;
    return [
      KpiData(
        label: 'Écoles',
        value: fmtInt(b.nbEcoles),
        sub: '${b.nbGroupes} groupe${b.nbGroupes > 1 ? 's' : ''}',
        icon: Icons.account_balance_rounded,
        color: kNavy,
      ),
      KpiData(
        label: 'Élèves',
        value: fmtInt(b.nbEleves),
        sub: part == null
            ? 'aucun effectif'
            : '${part.round()} % de filles',
        icon: Icons.groups_rounded,
        color: kGreen,
        progressValue: part == null ? null : part / 100,
      ),
      KpiData(
        label: 'Public / Privé',
        value: '${fmtInt(b.nbPublic)} / ${fmtInt(b.nbPrive)}',
        sub: 'écoles',
        icon: Icons.balance_rounded,
        color: kAccent,
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
        progressValue:
            b.nbEcoles == 0 ? null : b.nbAgrementDeclare / b.nbEcoles,
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
