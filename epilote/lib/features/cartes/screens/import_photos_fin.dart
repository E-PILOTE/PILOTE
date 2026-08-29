import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/import_photos_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  LES DEUX DERNIERS TEMPS DE L'IMPORT : pendant l'écriture, et après.
//
//  Séparés des deux premiers par la seule frontière qui compte ici : avant, rien
//  n'est écrit et tout se corrige ; à partir d'ici, la base a changé.
// ═════════════════════════════════════════════════════════════════════════════

// ─── 3. Progression ──────────────────────────────────────────────────────────

class ProgressionImport extends StatelessWidget {
  const ProgressionImport({
    super.key,
    required this.rang,
    required this.total,
    required this.eleve,
    required this.annule,
  });

  final int rang, total;
  final String eleve;
  final bool annule;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminProgressBar(value: rang, max: total == 0 ? 1 : total),
            const SizedBox(height: 16),
            Text('$rang / $total',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(height: 6),
            Text(annule ? 'Arrêt après la photo en cours…' : eleve,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: kTextMuted)),
            const SizedBox(height: 18),
            Text(
              'Chaque photo est réduite puis mise en file. Le réseau n’est pas '
              'requis : ce qui ne part pas maintenant partira au retour de la '
              'connexion.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
            ),
          ],
        ),
      );
}

// ─── 4. Rapport ──────────────────────────────────────────────────────────────

class RapportImport extends StatelessWidget {
  const RapportImport({super.key, required this.rapport});
  final RapportImportPhotos rapport;

  @override
  Widget build(BuildContext context) {
    final echecs = rapport.echecs;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      children: [
        Row(children: [
          Icon(
              echecs.isEmpty
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: echecs.isEmpty ? kGreen : kAccent,
              size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${rapport.reussis} photo${rapport.reussis > 1 ? 's' : ''} '
              'enregistrée${rapport.reussis > 1 ? 's' : ''}'
              '${echecs.isEmpty ? '.' : ', ${echecs.length} en échec.'}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kNavy),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (echecs.isEmpty)
          Text(
            'Les cartes de ces élèves porteront leur visage. Les fichiers '
            'montent vers le serveur en arrière-plan.',
            style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
          )
        else ...[
          // Nommer CE QUI a échoué, pas « des erreurs » : l'agent doit pouvoir
          // reprendre exactement ces fichiers-là.
          Text('Ces photos n’ont pas été enregistrées :',
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          const SizedBox(height: 8),
          for (final e in echecs)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${e.eleve} — ${e.fichier} : ${e.echec}',
                  style: TextStyle(fontSize: 12, color: kRed, height: 1.4)),
            ),
        ],
      ],
    );
  }
}
