import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../finance/providers/paiements_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/rapports_provider.dart';
import '../services/rapport_pdf_service.dart';
import 'rapports_parts.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RAPPORTS DE L'ÉTABLISSEMENT
//
//  Cette page était un écran « bientôt disponible » : un chef d'établissement
//  n'avait AUCUN état imprimable de son école. Ce que réclame une direction
//  départementale — l'effectif arrêté à une date, le recouvrement — se
//  reconstituait à la main, classe par classe, sur un cahier.
//
//  ⚠️ PAGE DE DIRECTION. Elle lit l'école ENTIÈRE, hors du périmètre de classes
//  de l'agent (cf. `rapports_provider.dart`). La contrepartie tient en deux
//  verrous qui doivent rester tous les deux : la sidebar ne l'affiche que pour
//  `AppConstants.directionRoles`, et le routeur renvoie les autres au tableau
//  de bord. Un seul des deux laisserait l'URL ouverte à tout le personnel.
//
//  ── CE QUI N'EST PAS ICI, ET POURQUOI ──────────────────────────────────────
//  Pas de graphiques : ces documents se signent et se transmettent. Une courbe
//  ne se contresigne pas, et un histogramme photocopié en noir et blanc ne dit
//  plus rien. L'analyse visuelle vit sur le tableau de bord.
// ════════════════════════════════════════════════════════════════════════════

class RapportsScreen extends ConsumerWidget {
  const RapportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annee = ref.watch(activeYearProvider)?.label;
    final effectifs = ref.watch(etatEffectifsProvider);
    final recouvrement = ref.watch(etatRecouvrementProvider);
    final overview = ref.watch(paymentsOverviewProvider).valueOrNull;
    final personnel = ref.watch(etatPersonnelProvider);

    return AppShell(
      title: 'Rapports',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          RapportsEntete(annee: annee),
          const SizedBox(height: 20),

          // ── État des effectifs ───────────────────────────────────────────
          RapportCard(
            icone: Icons.groups_rounded,
            couleur: kNavy,
            titre: 'État des effectifs',
            resume: effectifs == null
                ? null
                : '${effectifs.total.total} élève(s) inscrit(s) · '
                    '${effectifs.classes.length} classe(s)',
            contient: const [
              'Effectif par classe, filles et garçons',
              'Internes et boursiers',
              'Sous-total par cycle et total établissement',
            ],
            exclut: 'Les dossiers en attente de validation, les élèves retirés '
                'et les transférés.',
            alerte: _alerteEffectifs(effectifs),
            pret: effectifs != null && effectifs.total.total > 0,
            messageVide: effectifs == null
                ? 'Chargement des inscriptions…'
                : 'Aucun élève inscrit sur l\'année active.',
            onApercu: effectifs == null
                ? null
                : () => showPdfPreviewDialog(
                      context,
                      title: 'État des effectifs',
                      subtitle: annee,
                      pdfFileName: 'etat-effectifs.pdf',
                      build: (_) => RapportPdfService.etatEffectifs(
                          etat: effectifs, anneeLabel: annee),
                    ),
          ),
          const SizedBox(height: 14),

          // ── État de recouvrement ─────────────────────────────────────────
          RapportCard(
            icone: Icons.payments_rounded,
            couleur: kGreen,
            titre: 'État de recouvrement',
            resume: overview == null
                ? null
                : '${overview.aJour} élève(s) à jour · '
                    '${overview.classesTotal} classe(s)',
            contient: const [
              'Dû à ce jour, encaissé et reste, par classe',
              'Nombre d\'élèves à jour',
              'Total établissement',
            ],
            exclut: 'Les frais d\'examen, qui relèvent du module Examens et '
                'ne sont dus que par les candidats.',
            // ⚠️ Le dire AVANT l'aperçu : sans barème le document sort avec des
            // dûs nuls, ce qui se lirait « tout est réglé » alors que rien
            // n'est tarifé. Une trentaine d'écoles publiques sont dans ce cas.
            alerte: overview != null && overview.sansBareme
                ? 'Aucun barème publié pour cette année : le dû ne peut pas '
                    'être établi. Seuls les montants encaissés seront exacts.'
                : null,
            pret: recouvrement != null && recouvrement.isNotEmpty,
            messageVide: recouvrement == null
                ? 'Chargement des paiements…'
                : 'Aucune classe sur l\'année active.',
            onApercu: recouvrement == null
                ? null
                : () => showPdfPreviewDialog(
                      context,
                      title: 'État de recouvrement',
                      subtitle: annee,
                      pdfFileName: 'etat-recouvrement.pdf',
                      accent: kGreen,
                      build: (_) => RapportPdfService.etatRecouvrement(
                        lignes: recouvrement,
                        anneeLabel: annee,
                        sansBareme: overview?.sansBareme ?? true,
                      ),
                    ),
          ),
          const SizedBox(height: 14),

          // ── État du personnel ────────────────────────────────────────────
          RapportCard(
            icone: Icons.badge_rounded,
            couleur: kAccent,
            titre: 'État du personnel',
            resume: personnel == null
                ? null
                : '${personnel.total.enFonction} agent(s) en poste · '
                    '${personnel.categories.length} catégorie(s)',
            contient: const [
              'Effectif par catégorie métier (direction, administration…)',
              'Répartition par statut d\'emploi',
              'Comptes désactivés, comptés à part',
            ],
            exclut: 'Les élèves et les parents : ce sont des usagers, pas du '
                'personnel.',
            // ⚠️ Une école sans direction en fonction ne peut pas faire signer
            // ses états. Le dire ici, pas après l'impression.
            alerte: personnel != null && !personnel.directionEnPoste
                ? 'Aucun agent de direction en fonction : à corriger avant '
                    'transmission, cet état doit être signé.'
                : null,
            pret: personnel != null && personnel.total.enFonction > 0,
            messageVide: personnel == null
                ? 'Chargement de l\'annuaire…'
                : 'Aucun agent rattaché à cette école.',
            onApercu: personnel == null
                ? null
                : () => showPdfPreviewDialog(
                      context,
                      title: 'État du personnel',
                      subtitle: annee,
                      pdfFileName: 'etat-personnel.pdf',
                      accent: kAccent,
                      build: (_) => RapportPdfService.etatPersonnel(
                          etat: personnel, anneeLabel: annee),
                    ),
          ),
        ],
      ),
    );
  }

  /// Un état des effectifs porte deux anomalies possibles, et toutes deux
  /// doivent se voir AVANT l'impression : une fois le document signé, plus
  /// personne ne les cherche.
  static String? _alerteEffectifs(EtatEffectifs? e) {
    if (e == null) return null;
    final motifs = <String>[];
    if (e.total.sexeInconnu > 0) {
      motifs.add('${e.total.sexeInconnu} élève(s) sans sexe renseigné');
    }
    final orphelines =
        e.classes.where((l) => l.className == kSansClasseLibelle).length;
    if (orphelines > 0) {
      motifs.add('des inscriptions actives sans classe');
    }
    return motifs.isEmpty
        ? null
        : 'À corriger avant transmission : ${motifs.join(' · ')}.';
  }
}
