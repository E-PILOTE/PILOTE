import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_rattachement_provider.dart';
import '../widgets/divergence_card.dart';
import '../widgets/origine_chip.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RATTACHEMENT DES NIVEAUX — la carte du référentiel, école par école.
//
//  Depuis la migration 0101, le groupe tarifie « la 6e » une seule fois pour
//  tout le réseau. Chaque poste traduit ce niveau national en son propre niveau
//  par `school_levels.education_level_id`. Toute la chaîne tient à ce
//  rattachement, et RIEN ne le montrait.
//
//  Cet écran ne modifie rien — c'est délibéré. Rattacher un niveau se fait dans
//  la fiche de l'école, avec le reste de son offre éducative ; le faire aussi
//  ici créerait deux chemins pour le même geste. Ici on CONSTATE.
//
//  Il n'est PAS dans la barre latérale : on l'ouvre depuis Frais & tarifs,
//  c'est-à-dire au moment où la question se pose. D'où le retour explicite —
//  sans lui, on arrive dans un écran dont aucune entrée de menu n'est allumée,
//  et le chemin de retour n'existe plus.
// ════════════════════════════════════════════════════════════════════════════
class AdminRattachementScreen extends ConsumerWidget {
  const AdminRattachementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
        title: 'Rattachement des niveaux',
        onBack: () => context.go(Routes.adminFrais),
        child: const _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(adminRattachementProvider).when(
            skipLoadingOnReload: true,
            loading: () => const ListShimmer(),
            error: (e, _) => Center(child: Text(messageErreur(e))),
            data: (v) => _contenu(context, ref, v),
          );

  Widget _contenu(BuildContext context, WidgetRef ref, VueRattachement v) {
    if (v.entrees.isEmpty && v.orphelins.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: AdminEmptyState(
            icon: Icons.account_tree_outlined,
            title: 'Aucun niveau déclaré',
            message:
                'Vos écoles n\'ont pas encore d\'offre éducative. Ouvrez la '
                'fiche d\'un établissement pour déclarer ses cycles et ses '
                'niveaux — c\'est ce qui permettra ensuite de leur adresser un '
                'tarif par niveau.',
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KpiGrid(items: _kpis(v)),
                const SizedBox(height: 20),
                if (v.divergences.isNotEmpty) ...[
                  _titre('À vérifier', Icons.report_problem_rounded,
                      couleur: kListOrange),
                  const SizedBox(height: 10),
                  for (final d in v.divergences) DivergenceCard(divergence: d),
                  const SizedBox(height: 10),
                ],
                if (v.orphelins.isNotEmpty) ...[
                  _titre('Niveaux rattachés à rien', Icons.link_off_rounded,
                      couleur: kRed),
                  const SizedBox(height: 10),
                  _orphelins(v.orphelins),
                  const SizedBox(height: 20),
                ],
                _titre('Le référentiel, tel qu\'il est utilisé',
                    Icons.account_tree_rounded),
                const SizedBox(height: 4),
                Text(
                  '${v.entrees.length} entrée(s) du référentiel portent au moins '
                  'une école. Un tarif réseau par niveau vise l\'une de ces '
                  'lignes.',
                  style: TextStyle(fontSize: 12, color: kTextMuted),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: v.entrees.length,
            itemBuilder: (_, i) =>
                _EntreeTile(key: ValueKey(v.entrees[i].id), entree: v.entrees[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _titre(String texte, IconData icone, {Color? couleur}) => Row(
        children: [
          Icon(icone, size: 17, color: couleur ?? kNavy),
          const SizedBox(width: 8),
          Text(texte,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ],
      );

  /// Un niveau rattaché à rien ne recevra JAMAIS un tarif réseau par niveau.
  /// L'école le verra tarifé « tous niveaux » ou pas du tout — silencieusement.
  Widget _orphelins(List<NiveauEcole> rows) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Ces niveaux ne sont reliés à aucune entrée du référentiel : aucun '
            'tarif réseau visant un niveau ne les atteindra. Ouvrez la fiche de '
            'l\'école et rattachez-les.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
          ),
          const SizedBox(height: 10),
          for (final o in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.link_off_rounded, size: 13, color: kRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${o.schoolName} — ${o.levelName}',
                      style: TextStyle(fontSize: 12, color: kTextPrimary)),
                ),
              ]),
            ),
        ]),
      );

  List<KpiData> _kpis(VueRattachement v) {
    final national = v.niveauxNationaux;
    final groupe = v.niveauxDuGroupe;
    final total = national + groupe;
    final orphelins = v.orphelins.length;
    final div = v.divergences.length;

    return [
      KpiData(
        label: 'Sur le référentiel national',
        value: '$national',
        sub: total == 0 ? '—' : 'niveaux d\'école sur $total',
        icon: Icons.public_rounded,
        color: kNavy,
        progressValue: total == 0 ? 0 : national / total,
        trend: 'socle commun',
      ),
      KpiData(
        label: 'Sur vos propres entrées',
        value: '$groupe',
        sub: groupe == 0
            ? 'aucune entrée propre utilisée'
            : 'créées par votre groupe',
        icon: Icons.workspaces_rounded,
        color: kAccent,
        progressValue: total == 0 ? 0 : groupe / total,
      ),
      KpiData(
        label: 'Rattachés à rien',
        value: '$orphelins',
        sub: orphelins == 0
            ? '✅ tous rattachés'
            : '⛔ hors de portée d\'un tarif',
        icon: Icons.link_off_rounded,
        color: orphelins == 0 ? kGreen : kRed,
        trend: orphelins == 0 ? 'complet' : 'à rattacher',
        trendUp: orphelins == 0,
        progressValue: orphelins == 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Années dédoublées',
        value: '$div',
        sub: div == 0
            ? '✅ une entrée par année'
            : 'écoles réparties sur 2 entrées',
        icon: Icons.call_split_rounded,
        color: div == 0 ? kGreen : kListOrange,
        trend: div == 0 ? 'cohérent' : 'à vérifier',
        trendUp: div == 0,
        progressValue: div == 0 ? 1 : 0,
      ),
    ];
  }
}

/// Une entrée du référentiel, dépliable sur les écoles qui s'y rattachent.
class _EntreeTile extends StatelessWidget {
  const _EntreeTile({super.key, required this.entree});

  final EntreeReferentiel entree;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Icon(Icons.stairs_rounded,
                size: 18, color: entree.duGroupe ? kNavy : kTextMuted),
            title: Row(children: [
              Flexible(
                child: Text(entree.libelle,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              if (entree.duGroupe) ...[
                const SizedBox(width: 8),
                const OrigineChip(),
              ],
            ]),
            trailing: Text(
              '${entree.ecoles.length} école(s)',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kNavy),
            ),
            children: [
              for (final e in entree.ecoles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.account_balance_rounded,
                        size: 13, color: kTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.schoolName,
                          style: TextStyle(fontSize: 12, color: kTextPrimary)),
                    ),
                    // Le nom local diffère souvent du libellé du référentiel :
                    // c'est précisément ce que cet écran sert à montrer.
                    Text(e.levelName,
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
                ),
            ],
          ),
        ),
      );
}
