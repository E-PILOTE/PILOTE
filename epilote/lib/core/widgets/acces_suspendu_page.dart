import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin_groupe/providers/acces_groupe_provider.dart';
import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PORTE FERMÉE — ce qu'un groupe voit quand son accès est coupé
//
//  ── CE QU'ELLE DOIT FAIRE, DANS L'ORDRE ───────────────────────────────────
//  1. DIRE POURQUOI. Le motif écrit par E-PILOTE Congo, en toutes lettres.
//     Une porte fermée sans explication est un appel téléphonique garanti —
//     et, avec un ministère, une réunion.
//  2. DIRE QUE RIEN N'EST PERDU. C'est la peur immédiate : « nos données ? ».
//     Rien n'est effacé, rien n'est arrêté chez les écoles du réseau, et tout
//     revient à l'identique au rétablissement.
//  3. DIRE PAR OÙ ÇA SE RÈGLE. Un écran qui bloque sans donner la sortie ne
//     fait que retarder le même appel.
//
//  ── ⚠️ CE QU'ELLE NE FAIT PAS ─────────────────────────────────────────────
//  Elle ne reproche rien et ne chiffre aucune dette. Le motif suffit ; le
//  montant se discute entre adultes, pas sur un écran de blocage affiché
//  devant n'importe quel agent du ministère qui ouvre l'application.
//
//  Et elle N'EST PAS la serrure : la vraie coupure est côté serveur (0187,
//  `auth_peut_superviser`). Cet écran explique une porte déjà fermée.
// ════════════════════════════════════════════════════════════════════════════

class AccesSuspenduPage extends ConsumerWidget {
  const AccesSuspenduPage({super.key, required this.acces});

  final AccesGroupe acces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: kSurface,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: kRed.withValues(alpha: 0.28)),
              ),
              child: Icon(Icons.lock_rounded, size: 34, color: kRed),
            ),
            const SizedBox(height: 20),
            Text('Accès suspendu',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'E-PILOTE Congo a suspendu l’accès de votre espace.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5),
            ),
            if (acces.motif != null && acces.motif!.trim().isNotEmpty) ...[
              const SizedBox(height: 22),
              // ── 1. POURQUOI ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: kCardBg,
                  border: Border.all(color: kRed.withValues(alpha: 0.30)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          acces.depuis == null
                              ? 'MOTIF'
                              : 'MOTIF · depuis le ${_date(acces.depuis!)}',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: kTextMuted)),
                      const SizedBox(height: 6),
                      Text(acces.motif!.trim(),
                          style: TextStyle(
                              fontSize: 14,
                              color: kTextPrimary,
                              height: 1.5,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
            ],
            const SizedBox(height: 18),
            // ── 2. RIEN N'EST PERDU ──────────────────────────────────────
            const _Rassurance(
              icone: Icons.inventory_2_rounded,
              titre: 'Vos données sont intactes',
              texte: 'Rien n’a été effacé. Élèves, notes, paiements et '
                  'documents sont conservés et reviennent à l’identique dès le '
                  'rétablissement.',
            ),
            const SizedBox(height: 10),
            const _Rassurance(
              icone: Icons.school_rounded,
              titre: 'Vos établissements continuent de travailler',
              texte: 'Les écoles de votre réseau ne sont pas concernées : '
                  'elles gardent leur accès et leur synchronisation hors '
                  'ligne. Seul l’espace de supervision est fermé.',
            ),
            const SizedBox(height: 18),
            // ── 3. PAR OÙ ÇA SE RÈGLE ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.06),
                border: Border.all(color: kNavy.withValues(alpha: 0.22)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.support_agent_rounded, size: 18, color: kNavy),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comment rétablir',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary)),
                        const SizedBox(height: 3),
                        Text(
                          'Contactez E-PILOTE Congo pour régulariser. '
                          'L’accès est rouvert dès que la situation est '
                          'réglée — il n’y a aucune démarche à faire dans '
                          'l’application.',
                          style: TextStyle(
                              fontSize: 12.5, color: kTextMuted, height: 1.5),
                        ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            // Un seul bouton : revérifier. Il ne « demande » rien au serveur
            // d'autre que l'état — c'est le geste naturel après un appel
            // téléphonique, et il évite de faire redémarrer l'application.
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(accesGroupeProvider),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Vérifier à nouveau'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kNavy.withValues(alpha: 0.35)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Rassurance extends StatelessWidget {
  const _Rassurance(
      {required this.icone, required this.titre, required this.texte});

  final IconData icone;
  final String titre, texte;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 17, color: kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(texte,
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted, height: 1.45)),
                ]),
          ),
        ]),
      );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
