import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _say(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  /// Enregistre la pièce hors de la plateforme. Une archive dont on ne peut
  /// pas ressortir le document n'est qu'une base de données.
  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await ref.read(archiveActionsProvider).fileBytes(pub);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la publication',
        fileName: pub.fileName,
        bytes: bytes,
      );
      if (path == null) return;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
      if (context.mounted) _say(context, 'Enregistré : $path');
    } catch (e) {
      if (context.mounted) _say(context, 'Échec de l\'enregistrement : $e');
    }
  }

  /// Recalcule l'empreinte et la compare à celle du dépôt. C'est ce qui
  /// distingue « on a un fichier » de « on a LA pièce ».
  Future<void> _verify(BuildContext context, WidgetRef ref) async {
    if (pub.sha256 == null) {
      return _say(context, 'Aucune empreinte enregistrée pour cette pièce.');
    }
    _say(context, 'Vérification en cours…');
    try {
      final ok = await ref.read(archiveActionsProvider).verifyIntegrity(pub);
      if (!context.mounted) return;
      _say(
          context,
          ok
              ? 'Intègre — le document est identique à celui déposé.'
              : '⚠ ALTÉRÉ — le fichier stocké diffère de celui déposé.');
    } catch (e) {
      if (context.mounted) _say(context, 'Vérification impossible : $e');
    }
  }

  /// Renvoie l'avis aux chefs d'établissement — utile quand une école déclare
  /// n'avoir rien reçu.
  Future<void> _notify(BuildContext context, WidgetRef ref) async {
    try {
      final n = await ref.read(archiveActionsProvider).notify(
            publicationId: pub.id,
            scope: pub.scope,
            title: pub.title,
            department: pub.department,
            schoolId: pub.schoolId,
            examShortName: pub.examShortName,
            yearLabel: pub.yearLabel,
          );
      if (context.mounted) {
        _say(context,
            n == 0 ? 'Aucun destinataire sur ce périmètre.' : '$n avis envoyé(s).');
      }
    } catch (e) {
      if (context.mounted) _say(context, 'Envoi impossible : $e');
    }
  }

  /// Retrait d'une pièce — jamais sans confirmation : ce qui part d'une
  /// archive ne se retrouve pas.
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        title: Text('Retirer cette pièce ?',
            style: TextStyle(fontSize: 16, color: kTextPrimary)),
        content: Text(
          'Le document « ${pub.title} » et son fichier seront supprimés. '
          'Les chiffres officiels relevés dessus perdront leur source : ils '
          'resteront affichés, mais sans pièce pour les appuyer.',
          style: TextStyle(fontSize: 13, color: kTextMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(archiveActionsProvider).removePublication(pub);
      if (context.mounted) _say(context, 'Pièce retirée de l\'archive.');
    } catch (e) {
      if (context.mounted) _say(context, 'Retrait impossible : $e');
    }
  }

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
        PopupMenuButton<String>(
          tooltip: 'Actions',
          icon: Icon(Icons.more_vert_rounded, size: 18, color: kTextMuted),
          onSelected: (v) => switch (v) {
            'dl' => _download(context, ref),
            'check' => _verify(context, ref),
            'notify' => _notify(context, ref),
            'copy' => Clipboard.setData(ClipboardData(text: pub.sha256 ?? ''))
                .then((_) => context.mounted
                    ? _say(context, 'Empreinte copiée.')
                    : null),
            _ => _remove(context, ref),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'dl', child: Text('Télécharger')),
            const PopupMenuItem(
                value: 'check', child: Text('Vérifier l\'intégrité')),
            const PopupMenuItem(
                value: 'notify', child: Text('Renvoyer l\'avis aux écoles')),
            if (pub.sha256 != null)
              const PopupMenuItem(
                  value: 'copy', child: Text('Copier l\'empreinte')),
            const PopupMenuDivider(),
            PopupMenuItem(
                value: 'rm',
                child: Text('Retirer de l\'archive',
                    style: TextStyle(color: kRed))),
          ],
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
