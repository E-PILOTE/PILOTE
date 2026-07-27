import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_publication_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS & ARCHIVES — le second temps du cycle des examens.
//
//  La page « Examens nationaux » suivait jusqu'ici la préparation : dossiers,
//  candidats, transmission à la DEC. Il lui manquait le retour : ce que la DEC
//  a publié, et qui n'existait nulle part ailleurs qu'en boîte mail.
//
//  Un chiffre officiel ne s'affiche JAMAIS sans sa source. Un chiffre sans
//  pièce jointe est signalé comme tel — c'est la différence entre une archive
//  et une note de service.
// ════════════════════════════════════════════════════════════════════════════
class ExamArchivesSection extends ConsumerWidget {
  const ExamArchivesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubs = ref.watch(examPublicationsProvider);
    final figures = ref.watch(officialFiguresProvider).valueOrNull ?? const [];

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle(
              'Résultats & archives',
              icon: Icons.inventory_2_rounded,
              subtitle: 'Publications de la DEC conservées par la DSIC',
            ),
          ),
          FilledButton.icon(
            onPressed: () => showExamPublicationDialog(context),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Déposer'),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
          ),
        ]),
        const SizedBox(height: 6),
        const _Rule(),
        const SizedBox(height: 14),
        pubs.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('$e',
              style: TextStyle(fontSize: 12.5, color: kRed)),
          data: (list) => list.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Aucune publication archivée',
                  message: 'La DEC proclame les résultats et publie ses listes ; '
                      'la plateforme ne les calcule pas. Déposez ici les '
                      'documents reçus : ils deviennent la mémoire opposable '
                      'du réseau, examen par examen et année par année.',
                )
              : Column(
                  children: [
                    for (final p in list)
                      _PublicationTile(
                        pub: p,
                        figure: _figureFor(figures, p),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }

  /// Rapproche une pièce de son chiffre officiel — même session, même
  /// périmètre. Un rapprochement plus lâche associerait le taux d'un
  /// département à la liste d'une école.
  static OfficialFigure? _figureFor(
      List<OfficialFigure> figures, ExamPublication p) {
    for (final f in figures) {
      if (f.sessionId != p.sessionId || f.scope != p.scope) continue;
      if (f.department != p.department) continue;
      if (f.schoolId != p.schoolId) continue;
      return f;
    }
    return null;
  }
}

// ─── Une pièce archivée ─────────────────────────────────────────────────────
class _PublicationTile extends ConsumerWidget {
  const _PublicationTile({required this.pub, this.figure});

  final ExamPublication pub;
  final OfficialFigure? figure;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(archiveActionsProvider).signedUrl(pub);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document indisponible : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = figure?.passRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.picture_as_pdf_rounded, size: 19, color: kNavy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pub.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Tag('${pub.examShortName ?? '—'} · ${pub.yearLabel ?? '—'}',
                    kNavy),
                _Tag(pub.scopeLabel, kGreen),
                if (pub.filiereLabel != null) _Tag(pub.filiereLabel!, kTextMuted),
                if (pub.decSchoolCode != null)
                  _Tag('code ${pub.decSchoolCode}', kTextMuted),
              ]),
              const SizedBox(height: 5),
              Text(
                [
                  if (pub.publishedAt != null)
                    'publié le ${_d(pub.publishedAt!)}'
                  else
                    'date de publication non renseignée',
                  'reçu le ${_d(pub.receivedAt)}',
                  if (pub.fileSize != null) '${(pub.fileSize! / 1024).round()} Ko',
                ].join('  ·  '),
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Le chiffre officiel s'affiche à côté de SA pièce, jamais seul.
        if (rate != null)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${rate.toStringAsFixed(2)} %',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: kGreen)),
            Text(
              figure!.hasCounts
                  ? '${figure!.admitted} / ${figure!.present} présents'
                  : 'taux publié',
              style: TextStyle(fontSize: 10.5, color: kTextMuted),
            ),
            Text('OFFICIEL DEC',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: kTextMuted)),
          ])
        else
          Text('chiffres\nnon relevés',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Ouvrir le document',
          onPressed: () => _open(context, ref),
          icon: Icon(Icons.open_in_new_rounded, size: 18, color: kNavy),
        ),
      ]),
    );
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

// ─── Ce que la plateforme fait et ne fait pas ───────────────────────────────
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Text(
        'La plateforme transmet la liste des candidats à la DEC ; la DEC '
        'organise l\'épreuve, proclame les admis et publie ses documents — par '
        'examen, par département et par établissement. Aucun taux national '
        'n\'est calculé ici : les chiffres officiels sont relevés sur la '
        'publication et restent attachés à elle.',
        style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
      );
}
