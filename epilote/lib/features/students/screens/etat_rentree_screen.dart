import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../providers/etat_rentree_provider.dart';
import '../services/etat_rentree_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT STATISTIQUE DE RENTRÉE — l'écran
//
//  Il montre à l'écran exactement ce que le PDF portera, et dans le même
//  ordre : la date de référence des âges, les données manquantes, puis les
//  totaux. Un écran qui présenterait des chiffres plus flatteurs que le
//  document remonté serait la pire des interfaces — celle qui rassure avant de
//  faire signer.
// ════════════════════════════════════════════════════════════════════════════
class EtatRentreeScreen extends ConsumerWidget {
  const EtatRentreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ModuleScaffold(
        slug: 'documents',
        title: 'État statistique de rentrée',
        onBack: () => Navigator.of(context).maybePop(),
        child: const _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  Future<void> _editer(
      BuildContext context, WidgetRef ref, EtatRentree etat) async {
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final year = ref.read(activeYearProvider);
    final nom = (school?['name'] as String?)?.trim();

    await showPdfPreviewDialog(
      context,
      title: 'État statistique de rentrée',
      subtitle: '${etat.totalEleves} élèves · ${etat.totalClasses} classes · '
          '${etat.totalPersonnel} agents',
      pdfFileName: 'etat_rentree_${year?.label ?? ''}.pdf'.replaceAll(' ', '_'),
      build: (_) => EtatRentreePdfService.build(
        etat: etat,
        yearLabel: year?.label ?? '',
        etablissement: EnTeteEtablissement(
          nom: nom == null || nom.isEmpty ? 'Établissement' : nom,
          code: school?['school_code'] as String?,
          type: school?['school_type'] as String?,
          tutelle: school?['tutelle'] as String?,
          departement: school?['department'] as String?,
          arrondissement: school?['arrondissement'] as String?,
          ville: school?['city'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(etatRentreeProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: AdminErrorBanner(message: '$e'),
      ),
      data: (etat) {
        if (etat == null) {
          return const AdminEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Aucune année scolaire active',
            message: 'Un état de rentrée porte sur une année : sans elle, il '
                'ne se rapporte à rien.',
          );
        }
        if (etat.totalEleves == 0) {
          return const AdminEmptyState(
            icon: Icons.query_stats_rounded,
            title: 'Aucune inscription active cette année',
            message: "L'état de rentrée compte les inscriptions actives de "
                "l'année en cours. Commencez par les inscriptions.",
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Reference(quand: etat.dateReference),
            const SizedBox(height: 12),
            if (!etat.lacunes.aucune) ...[
              _Lacunes(l: etat.lacunes),
              const SizedBox(height: 14),
            ],
            _Totaux(etat: etat, onEditer: () => _editer(context, ref, etat)),
            const SizedBox(height: 18),
            const AdminSectionTitle(
              'Effectifs par niveau',
              icon: Icons.stairs_rounded,
              subtitle: 'Ce que le document remontera, ligne pour ligne',
            ),
            const SizedBox(height: 8),
            for (final n in etat.niveaux) _LigneNiveauTuile(n: n),
          ],
        );
      },
    );
  }
}

class _Reference extends StatelessWidget {
  const _Reference({required this.quand});
  final DateTime quand;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.event_available_rounded, size: 16, color: kTextMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Âges calculés au ${DateFormat('dd MMMM yyyy', 'fr').format(quand)} '
            "— l'ouverture de l'année. Le même état réédité en juin donnera les "
            'mêmes chiffres qu’en octobre.',
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
          ),
        ),
      ]);
}

class _Lacunes extends StatelessWidget {
  const _Lacunes({required this.l});
  final LacunesEtat l;

  @override
  Widget build(BuildContext context) {
    final points = <String>[
      if (l.sansSexe > 0) '${l.sansSexe} sans sexe renseigné',
      if (l.sansDateNaissance > 0)
        '${l.sansDateNaissance} sans date de naissance',
      if (l.sansClasse > 0) '${l.sansClasse} sans classe rattachée',
      if (l.sansEleve > 0) '${l.sansEleve} inscription sans dossier élève',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.rule_rounded, color: kAccent, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Données manquantes : ${points.join(' · ')}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
              const SizedBox(height: 4),
              Text(
                'Ces élèves sont COMPTÉS dans les totaux — ils manquent '
                'seulement dans les colonnes qui exigent la donnée absente. '
                'Les compléter avant de remonter l’état évite une correction '
                'demandée par la circonscription.',
                style:
                    TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Totaux extends StatelessWidget {
  const _Totaux({required this.etat, required this.onEditer});
  final EtatRentree etat;
  final VoidCallback onEditer;

  @override
  Widget build(BuildContext context) {
    final part = etat.partFilles;
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.query_stats_rounded, color: kNavy, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("L'état de la rentrée",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kNavy)),
                  Text(
                    'Inscriptions actives de l’année en cours — un élève radié '
                    'en novembre n’a pas fait la rentrée.',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onEditer,
              style: FilledButton.styleFrom(backgroundColor: kNavy),
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text("Éditer l'état"),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _Chiffre('${etat.totalEleves}', 'élèves', kNavy),
            _Chiffre('${etat.totalGarcons}', 'garçons', kGreen),
            _Chiffre('${etat.totalFilles}', 'filles', kAccent),
            if (part != null)
              _Chiffre('${part.toStringAsFixed(1)} %', 'de filles', kAccent),
            _Chiffre('${etat.totalClasses}', 'classes', kNavy),
            _Chiffre('${etat.totalRedoublants}', 'redoublants', kRed),
            _Chiffre('${etat.totalNouveaux}', 'nouveaux inscrits', kGreen),
            _Chiffre('${etat.totalPersonnel}', 'agents', kNavy),
          ]),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.valeur, this.label, this.couleur);
  final String valeur, label;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

class _LigneNiveauTuile extends StatelessWidget {
  const _LigneNiveauTuile({required this.n});
  final LigneNiveau n;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.levelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(
                  '${n.cycleName} · ${n.classes} classe'
                  '${n.classes > 1 ? 's' : ''}'
                  '${n.classes == 0 ? '' : ' · ${n.parClasse.toStringAsFixed(1)} par classe'}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              AdminBadge('${n.garcons} G', color: kGreen),
              AdminBadge('${n.filles} F', color: kAccent),
              // La colonne « non renseigné » ne s'affiche que si elle existe,
              // mais elle ne se fond jamais dans une autre.
              if (n.sexeInconnu > 0)
                AdminBadge('${n.sexeInconnu} non rens.', color: kRed),
              if (n.redoublants > 0)
                AdminBadge('${n.redoublants} redoub.', color: kTextMuted),
            ]),
          ),
          SizedBox(
            width: 54,
            child: Text('${n.total}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kNavy)),
          ),
        ]),
      );
}
