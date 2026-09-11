import 'package:flutter/material.dart';

import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SORTIR UN ÉTAT — et cesser de faire choisir entre un document et un fichier
//
//  ── LE DÉFAUT QUE CETTE BARRE CORRIGE ──────────────────────────────────────
//  ⚠️ « Export CSV » était posé À CÔTÉ de « Exporter PDF », avec le même poids
//  visuel et sans un mot sur ce qui les distingue. Une secrétaire qui doit
//  afficher la répartition des classes au mur, la remettre à l'inspection ou
//  la joindre à une demande de poste n'a aucune raison de savoir ce qu'est un
//  CSV — et elle en repartait avec un fichier qu'aucun de ces trois gestes
//  n'accepte. Un tableur n'a ni en-tête d'établissement, ni date d'édition,
//  ni pagination, et il s'ouvre différemment sur chaque poste.
//
//  ── POURQUOI LE CSV RESTE, MALGRÉ TOUT ─────────────────────────────────────
//  ⚠️ Ce n'est PAS un format de développeur ici, et le supprimer casserait un
//  geste d'école. Deux tests du dépôt — `inscriptions_csv_aller_retour_test`
//  et `eleves_csv_aller_retour_test` — existent précisément pour garantir que
//  notre propre export se relit par notre propre import. C'est le geste de fin
//  d'année et celui du transfert : une école sort ses effectifs, les envoie à
//  une autre école ou corrige trois cents lignes dans un tableur, puis les
//  réinjecte. Un PDF ne rentre nulle part.
//
//  Le CSV cesse donc d'avoir l'air d'un document : il descend dans le menu
//  « ⋯ », et son intitulé DIT à quoi il sert. Un libellé qui nomme la
//  technique (« CSV ») laisse l'agent deviner ; un libellé qui nomme l'usage
//  (« pour réimporter ou corriger en masse ») ne se trompe pas de lecteur.
//
//  ── L'ORDRE EST UNE HIÉRARCHIE, PAS UN ALIGNEMENT ──────────────────────────
//  Aperçu PDF d'abord — c'est ce qu'on imprime et ce qu'on signe. Word ensuite,
//  et seulement là où un document s'AMENDE avant signature : un rapport, une
//  attestation, un courrier. Pour une liste de trois cents élèves, Word serait
//  pire que le PDF. Les données en dernier, dans le menu.
// ════════════════════════════════════════════════════════════════════════════

/// La barre de sortie d'un état : le document d'abord, les données ensuite.
///
/// [onApercuPdf] est requis — un écran qui ne sait pas produire de document
/// n'a rien à faire avec cette barre, et c'était précisément le défaut de
/// l'écran Classes et du journal d'audit.
class BarreExport extends StatelessWidget {
  const BarreExport({
    super.key,
    required this.onApercuPdf,
    this.onWord,
    this.onDonnees,
    this.libellePdf = 'Aperçu PDF',
    this.libelleDonnees = 'Fichier de données (CSV)',
    this.aQuoiServentLesDonnees =
        'Pour réimporter ailleurs, ou corriger en masse dans un tableur',
    this.compact = false,
  });

  /// Ouvre l'aperçu avant impression. L'aperçu n'est pas une option : c'est
  /// ce qui évite d'imprimer trois cents pages pour découvrir une colonne
  /// coupée.
  final VoidCallback onApercuPdf;

  /// Document Word modifiable. `null` quand l'état n'a pas vocation à être
  /// amendé — la plupart des listes.
  final VoidCallback? onWord;

  /// Export de données. `null` quand l'état ne se réimporte nulle part.
  final VoidCallback? onDonnees;

  final String libellePdf, libelleDonnees, aQuoiServentLesDonnees;

  /// Sur une barre déjà chargée (sélection multiple), on retire les libellés
  /// et on ne garde que les icônes.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final secondaires = onDonnees != null;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      AdminPdfButton(onTap: onApercuPdf, label: compact ? 'PDF' : libellePdf),
      if (onWord != null) ...[
        const SizedBox(width: 8),
        _BoutonWord(onTap: onWord!, compact: compact),
      ],
      if (secondaires) ...[
        const SizedBox(width: 4),
        _MenuDonnees(
          onDonnees: onDonnees!,
          libelle: libelleDonnees,
          aQuoiCaSert: aQuoiServentLesDonnees,
        ),
      ],
    ]);
  }
}

class _BoutonWord extends StatelessWidget {
  const _BoutonWord({required this.onTap, required this.compact});
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Le bleu de Word, volontairement : l'agent reconnaît le format avant de
    // lire le libellé, et ne confond pas les deux documents.
    const bleuWord = Color(0xFF2B579A);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bleuWord.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bleuWord.withValues(alpha: 0.24)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.description_outlined,
                size: 15, color: bleuWord),
            const SizedBox(width: 6),
            Text(
              compact ? 'Word' : 'Word (modifiable)',
              style: const TextStyle(
                color: bleuWord,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Le menu « ⋯ » où descend ce qui n'est pas un document.
class _MenuDonnees extends StatelessWidget {
  const _MenuDonnees({
    required this.onDonnees,
    required this.libelle,
    required this.aQuoiCaSert,
  });

  final VoidCallback onDonnees;
  final String libelle, aQuoiCaSert;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: 'Autres sorties',
        icon: Icon(Icons.more_horiz_rounded, size: 20, color: kTextMuted),
        position: PopupMenuPosition.under,
        onSelected: (_) => onDonnees(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            value: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.table_chart_outlined, size: 17, color: kTextMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libelle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // ⚠️ La phrase n'est pas une aide en ligne : c'est ce
                        // qui empêche un agent de repartir avec un tableur
                        // quand il lui fallait un document.
                        Text(
                          aQuoiCaSert,
                          style: TextStyle(
                            fontSize: 11,
                            color: kTextMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
