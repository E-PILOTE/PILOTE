import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../providers/registre_matricule_provider.dart';
import '../services/registre_matricule_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE MATRICULE — consultation et édition du grand livre
//
//  L'écran ne fait presque rien : il compte, il avertit, il imprime. Tout ce
//  qui compte est dans les deux chiffres du haut — le nombre d'inscrits depuis
//  l'ouverture, et le nombre de lignes que ce poste NE VOIT PAS.
//
//  ── POURQUOI LES LACUNES SONT EN HAUT, EN ROUGE, AVANT LE BOUTON ──────────
//  Parce qu'un registre incomplet imprimé de bonne foi est le pire résultat
//  possible : il a l'air d'un document réglementaire, il en porte l'en-tête, et
//  il ment. L'écran refuse donc de présenter l'impression comme un geste neutre
//  tant que le compte n'est pas à zéro.
// ════════════════════════════════════════════════════════════════════════════
class RegistreMatriculeScreen extends ConsumerWidget {
  const RegistreMatriculeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ModuleScaffold(
        slug: 'documents',
        title: 'Registre matricule',
        onBack: () => Navigator.of(context).maybePop(),
        child: const _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  Future<void> _imprimer(
      BuildContext context, WidgetRef ref, Registre registre) async {
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final nom = (school?['name'] as String?)?.trim();
    final year = ref.read(activeYearProvider);

    await showPdfPreviewDialog(
      context,
      title: 'Registre matricule',
      subtitle: '${registre.lignes.length} élève'
          '${registre.lignes.length > 1 ? 's' : ''} inscrit'
          '${registre.lignes.length > 1 ? 's' : ''}'
          '${registre.complet ? '' : ' · INCOMPLET'}',
      pdfFileName: 'registre_matricule.pdf',
      build: (_) => RegistreMatriculePdfService.build(
        registre: registre,
        schoolName: nom == null || nom.isEmpty ? 'Établissement' : nom,
        city: (school?['city'] as String?) ?? (school?['department'] as String?),
        yearLabel: year?.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registreMatriculeProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: AdminErrorBanner(message: '$e'),
      ),
      data: (r) {
        if (r.lignes.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Le registre est vide',
            message: 'Le grand livre se remplit tout seul : chaque élève '
                'inscrit y prend sa ligne, et il la garde même après son '
                'départ.',
          );
        }

        final sortis = r.lignes.where((l) => l.sorti).length;
        final archives = r.lignes.where((l) => l.archive).length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!r.complet) ...[
              _AlerteLacunes(lacunes: r.lacunes),
              const SizedBox(height: 16),
            ],
            _Entete(
              total: r.lignes.length,
              presents: r.lignes.length - sortis,
              sortis: sortis,
              archives: archives,
              complet: r.complet,
              onImprimer: () => _imprimer(context, ref, r),
            ),
            const SizedBox(height: 18),
            const AdminSectionTitle(
              'Extrait',
              icon: Icons.menu_book_rounded,
              subtitle: 'Les cinquante premières lignes — le document complet '
                  "s'obtient par l'impression",
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < r.lignes.length && i < 50; i++)
              _Ligne(rang: i + 1, ligne: r.lignes[i]),
            if (r.lignes.length > 50)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '… et ${r.lignes.length - 50} autres lignes.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlerteLacunes extends StatelessWidget {
  const _AlerteLacunes({required this.lacunes});
  final int lacunes;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kRed.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.report_gmailerrorred_rounded, color: kRed, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registre incomplet sur ce poste',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kRed)),
                const SizedBox(height: 4),
                Text(
                  '$lacunes inscription${lacunes > 1 ? 's' : ''} ne '
                  "trouve${lacunes > 1 ? 'nt' : ''} pas son élève sur cet "
                  'appareil. Les lignes existent au serveur — ce poste ne les '
                  'a pas reçues. Reconnectez-le et laissez la synchronisation '
                  "se terminer avant d'imprimer : un registre réglementaire "
                  'auquel il manque une ligne engage l’établissement.',
                  style: TextStyle(
                      fontSize: 12.5, color: kTextMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _Entete extends StatelessWidget {
  const _Entete({
    required this.total,
    required this.presents,
    required this.sortis,
    required this.archives,
    required this.complet,
    required this.onImprimer,
  });

  final int total, presents, sortis, archives;
  final bool complet;
  final VoidCallback onImprimer;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.menu_book_rounded, color: kNavy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Le grand livre',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kNavy)),
                    Text(
                      'Tous les élèves inscrits depuis l’ouverture, dans '
                      'l’ordre des matricules — y compris ceux qui sont partis.',
                      style: TextStyle(fontSize: 12.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onImprimer,
                style: FilledButton.styleFrom(
                    backgroundColor: complet ? kNavy : kRed),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(complet ? 'Éditer le registre' : 'Éditer malgré tout'),
              ),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Chiffre('$total', 'inscrits au total', kNavy),
              _Chiffre('$presents', 'encore présents', kGreen),
              _Chiffre('$sortis', 'sortis des effectifs', kAccent),
              if (archives > 0)
                _Chiffre('$archives', 'archivés (gardés au livre)', kTextMuted),
            ]),
          ],
        ),
      );
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

class _Ligne extends StatelessWidget {
  const _Ligne({required this.rang, required this.ligne});
  final int rang;
  final LigneRegistre ligne;

  static final _jour = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 34,
            child: Text('$rang',
                style: TextStyle(
                    fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 110,
            child: Text(ligne.matricule,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.nomComplet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                Text(
                  [
                    if (ligne.entreeLe != null)
                      'entré le ${_jour.format(ligne.entreeLe!)}',
                    if (ligne.classeEntree != null) ligne.classeEntree!,
                    if (ligne.sortieLe != null)
                      'sorti le ${_jour.format(ligne.sortieLe!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          if (ligne.archive)
            AdminBadge('Archivé', color: kTextMuted)
          else if (ligne.sorti)
            AdminBadge('Sorti', color: kAccent),
        ]),
      );
}
