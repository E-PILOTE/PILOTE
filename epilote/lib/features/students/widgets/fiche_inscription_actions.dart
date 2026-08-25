import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../core/utils/safe_file_name.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../finance/providers/decompte_du_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../providers/inscriptions_data_provider.dart';
import '../services/inscription_fiche_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  OUVRIR LA FICHE — un dossier, ou tout un lot
//
//  Le tirage vivait dans la fiche détail, en méthode privée : il ne pouvait
//  s'appeler que d'un endroit. La famille repartait donc les mains vides à
//  moins qu'un agent n'ouvre le dossier après coup, et une rentrée de quarante
//  inscriptions demandait quarante ouvertures. Le document existait et ne
//  sortait pas.
// ════════════════════════════════════════════════════════════════════════════

/// Au-delà de ce nombre, on demande confirmation avant de composer le lot.
///
/// ⚠️ Ce n'est PAS un plafond : rien n'est tronqué. Le tirage se fait en
/// mémoire, une fiche pesant une page ; à deux cents dossiers, un poste
/// d'école y passerait une minute et l'agent croirait l'application figée.
/// On le lui dit avant, avec le compte exact.
const _kSeuilConfirmation = 40;

/// La fiche d'UN dossier.
Future<void> ouvrirFicheInscription(
  BuildContext context,
  WidgetRef ref,
  InscriptionRow row,
) async {
  await _apercu(
    context,
    ref,
    [row],
    titre: 'Fiche d\'inscription',
    sousTitre: '${row.fullName} · ${row.className}',
    fichier: 'Fiche_inscription_'
        '${safeFileName(row.matricule.isEmpty ? row.lastName : row.matricule)}.pdf',
  );
}

/// La fiche d'un dossier dont on ne connaît que l'identifiant — au sortir de
/// l'assistant, par exemple, où la ligne d'écran n'existe pas encore.
///
/// ⚠️ Lecture DIRECTE, jamais via la liste : celle-ci est un flux dont la
/// première émission peut précéder l'écriture qu'on vient de faire.
Future<void> ouvrirFichePourInscription(
  BuildContext context,
  WidgetRef ref,
  String enrollmentId,
) async {
  final row = await ref.read(inscriptionRowProvider(enrollmentId).future);
  if (!context.mounted) return;
  if (row == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Dossier introuvable — la fiche s\'imprime depuis la '
          'liste des inscriptions.'),
    ));
    return;
  }
  await ouvrirFicheInscription(context, ref, row);
}

/// Les fiches de plusieurs dossiers, dans un seul document à imprimer d'un
/// geste.
Future<void> ouvrirFichesGroupees(
  BuildContext context,
  WidgetRef ref,
  List<InscriptionRow> rows,
) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Aucun dossier sélectionné.'),
    ));
    return;
  }
  if (rows.length == 1) return ouvrirFicheInscription(context, ref, rows.first);

  if (rows.length > _kSeuilConfirmation) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Composer toutes les fiches ?'),
        content: Text(
          '${rows.length} fiches seront composées en un seul document, soit '
          'autant de pages. La préparation peut prendre une trentaine de '
          'secondes sur un poste d\'école : l\'écran paraîtra figé sans l\'être.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Composer les ${rows.length} fiches'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }

  await _apercu(
    context,
    ref,
    rows,
    titre: 'Fiches d\'inscription',
    sousTitre: '${rows.length} dossiers',
    fichier: 'Fiches_inscription_${rows.length}.pdf',
  );
}

Future<void> _apercu(
  BuildContext context,
  WidgetRef ref,
  List<InscriptionRow> rows, {
  required String titre,
  required String sousTitre,
  required String fichier,
}) async {
  final school = ref.read(currentSchoolProvider).valueOrNull;
  final year = ref.read(activeYearProvider)?.label;

  Future<Uint8List> build(PdfPageFormat _) async {
    final entrees = <FicheEntree>[];
    for (final row in rows) {
      final dossier = await ref.read(studentDossierProvider(row.studentId).future);
      // Le décompte est FACULTATIF : s'il échoue, ou si l'école n'a aucun
      // barème publié, la fiche sort sans bloc frais plutôt que pas du tout.
      // Une famille qui repart sans papier est un problème plus grave qu'une
      // famille qui repart sans le détail des frais.
      DecompteDu? frais;
      try {
        frais = await ref.read(decompteDuProvider(row.id).future);
      } catch (_) {
        frais = null;
      }
      entrees.add((row: row, dossier: dossier, frais: frais));
    }
    return InscriptionFicheService.buildLot(
      entrees,
      schoolName: school?['name'] as String?,
      yearLabel: year,
    );
  }

  await showPdfPreviewDialog(
    context,
    title: titre,
    subtitle: sousTitre,
    pdfFileName: fichier,
    build: build,
  );
}
