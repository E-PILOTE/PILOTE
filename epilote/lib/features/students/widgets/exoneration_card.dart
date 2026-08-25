import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/frais_inscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'EXONÉRATION DE SCOLARITÉ, AU DOSSIER DE L'ÉLÈVE (migration 0109)
//
//  ── CE QUE CETTE CARTE RÉPARE ──────────────────────────────────────────────
//  `students.has_scholarship` était demandé à la famille, stocké, synchronisé
//  et affiché en pastille — sans entrer dans aucun calcul. Un boursier à 100 %
//  ressortait « Impayé » comme une famille qui ne règle pas, et la caisse le
//  relançait.
//
//  ── DEUX FAITS DISTINCTS, ET C'EST VOULU ───────────────────────────────────
//  « Élève boursier » est une SITUATION (elle vaut pour les statistiques
//  sociales et suit l'enfant). « Exonéré de 50 % cette année » est une
//  DÉCISION FINANCIÈRE, qui se reconduit — ou ne se reconduit pas — chaque
//  rentrée. Les fondre en un seul champ aurait fait traîner indéfiniment une
//  bourse de 2024.
//
//  L'écart entre les deux est ce que cette carte montre en premier : un élève
//  déclaré boursier SANS taux saisi doit encore la scolarité entière, et
//  personne ne s'en douterait.
//
//  ⚠️ On n'en déduit JAMAIS un taux. « Boursier » ne dit pas de combien : un
//  défaut à 100 % offrirait la scolarité, un défaut à 50 % inventerait un
//  chiffre. L'absence de décision reste une absence de décision — même
//  doctrine que la zone de délibération du passage.
// ════════════════════════════════════════════════════════════════════════════

class ExonerationCard extends ConsumerWidget {
  const ExonerationCard({
    super.key,
    required this.enrollmentId,
    this.modifiable = true,
  });

  final String enrollmentId;

  /// Une inscription rejetée ou une année archivée se consultent sans se
  /// modifier : la carte reste lisible, les actions disparaissent.
  final bool modifiable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(exonerationProvider(enrollmentId)).valueOrNull;
    if (e == null) return const SizedBox.shrink();

    final accordee = (e.taux ?? 0) > 0;
    final ecart = e.boursierDeclare && !accordee;

    // Rien à dire : ni bourse déclarée, ni exonération. On n'occupe pas la
    // fiche avec une carte vide — l'action reste accessible par le menu.
    if (!accordee && !ecart && !modifiable) return const SizedBox.shrink();

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.volunteer_activism_outlined, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Exonération de scolarité',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          if (accordee)
            AdminBadge('${e.taux} % remis', color: kGreen)
          else if (ecart)
            AdminBadge('À régulariser', color: kAccent)
          else
            AdminBadge('Aucune', color: kTextMuted),
        ]),
        const SizedBox(height: 10),
        if (accordee)
          _Ligne(
            icone: Icons.check_circle_outline_rounded,
            couleur: kGreen,
            texte: e.taux == 100
                ? 'La scolarité est remise en totalité. Les frais d\'examen et '
                    'les frais annexes restent dus.'
                : 'L\'élève ne doit que ${100 - e.taux!} % de sa scolarité. Les '
                    'frais d\'examen et les frais annexes restent dus en entier.',
          )
        else if (ecart)
          _Ligne(
            icone: Icons.error_outline_rounded,
            couleur: kAccent,
            // Le message dit ce qui se passe MAINTENANT, pas ce qui devrait se
            // passer : c'est le montant réclamé aujourd'hui qui est en jeu.
            texte: 'Cet élève est déclaré boursier, mais aucun taux n\'est '
                'saisi : il doit donc la scolarité ENTIÈRE, et la caisse le '
                'relancera comme les autres.',
          )
        else
          _Ligne(
            icone: Icons.info_outline_rounded,
            couleur: kTextMuted,
            texte: 'Aucune remise sur cette inscription. La scolarité est due '
                'en entier.',
          ),
        if (accordee && (e.motif ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Motif : ${e.motif!.trim()}',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: kTextMuted)),
        ],
        if (modifiable) ...[
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => _editer(context, ref, e),
              icon: Icon(
                  accordee ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 16),
              label: Text(accordee ? 'Modifier' : 'Accorder une exonération'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kNavy.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (accordee) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _enregistrer(context, ref, null, ''),
                style: TextButton.styleFrom(foregroundColor: kRed),
                child: const Text('Retirer'),
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  Future<void> _editer(
    BuildContext context,
    WidgetRef ref,
    ExonerationDossier actuel,
  ) async {
    final saisie = await _demanderTaux(context, actuel);
    if (saisie == null || !context.mounted) return;
    final (taux, motif) = saisie;
    await _enregistrer(context, ref, taux, motif);
  }

  Future<void> _enregistrer(
    BuildContext context,
    WidgetRef ref,
    int? taux,
    String motif,
  ) async {
    if (writeRefusedForLicense(context)) return;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    try {
      await setEnrollmentExemption(
        enrollmentId: enrollmentId,
        taux: taux,
        motif: motif,
        actorName: profile?.fullName ?? 'un agent',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(taux == null
              ? 'Exonération retirée — la scolarité redevient due en entier.'
              : 'Exonération de $taux % enregistrée.'),
          backgroundColor: taux == null ? kTextMuted : kGreen,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(messageErreur(e)), backgroundColor: kRed));
      }
    }
  }

  /// Taux et motif. Le motif est exigé ICI, pas au serveur : un refus de
  /// contrainte ferait abandonner à PowerSync le lot entier des écritures de la
  /// fenêtre, en silence (cf. `setEnrollmentExemption`).
  Future<(int, String)?> _demanderTaux(
    BuildContext context,
    ExonerationDossier actuel,
  ) {
    var taux = (actuel.taux ?? 50).toDouble();
    final motif = TextEditingController(text: actuel.motif ?? '');
    var erreur = false;

    return showDialog<(int, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Exonération de scolarité'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Slider(
                    value: taux,
                    min: 5,
                    max: 100,
                    // Pas de 5 % : personne n'accorde une bourse à 37 %, et un
                    // curseur au point près donnerait des montants impossibles
                    // à annoncer à une famille.
                    divisions: 19,
                    label: '${taux.round()} %',
                    onChanged: (v) => setSt(() => taux = v),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${taux.round()} %',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kNavy)),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: motif,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  hintText: 'Bourse d\'État · Cas social · Fratrie · Personnel',
                  helperText: 'Une remise sans justification écrite est '
                      'indéfendable devant un contrôle.',
                  helperMaxLines: 2,
                  errorText: erreur ? 'Le motif est obligatoire' : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (erreur) setSt(() => erreur = false);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kNavy),
              onPressed: () {
                final m = motif.text.trim();
                if (m.isEmpty) {
                  setSt(() => erreur = true);
                  return;
                }
                Navigator.pop(ctx, (taux.round(), m));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    ).whenComplete(motif.dispose);
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(
      {required this.icone, required this.couleur, required this.texte});
  final IconData icone;
  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: kTextPrimary)),
          ),
        ],
      );
}
