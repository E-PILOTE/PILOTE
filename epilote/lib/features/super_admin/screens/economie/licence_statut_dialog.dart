part of '../economie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ACTIVER, SUSPENDRE, REPRENDRE, RÉSILIER — le geste, pas la liste déroulante
//
//  ── L'ÉTAT AVANT ──────────────────────────────────────────────────────────
//  Une licence de quarante millions avait UNE action : « Modifier ». Le statut
//  était une liste déroulante au milieu du formulaire, entre le montant et la
//  référence de marché — au même rang qu'une faute de frappe à corriger. On
//  résiliait un marché national en changeant un menu et en cliquant
//  « Enregistrer », sans confirmation, sans motif, sans trace.
//
//  ── CE QUE CE FICHIER CHANGE ──────────────────────────────────────────────
//  Chaque transition devient un GESTE nommé par son verbe (« Suspendre », pas
//  « statut = suspendue »), avec ce qu'il implique écrit devant, et un motif
//  exigé quand on arrête quelque chose.
//
//  ── ⚠️ LA PHRASE QUI COMPTE LE PLUS ───────────────────────────────────────
//  « Cela ne coupe l'accès de personne. » Un fondateur qui suspend un marché
//  doit savoir, AU MOMENT où il clique, que le ministère continuera de
//  travailler normalement. Sinon il croit tenir un levier — et il découvre le
//  contraire le jour où il en a besoin, c'est-à-dire au pire moment.
//  (Contrainte C4 du 0160, garantie par 0183 et 0186.)
// ════════════════════════════════════════════════════════════════════════════

Future<void> _changerStatutLicence(
  BuildContext context,
  WidgetRef ref,
  LicenceTutelle licence,
  String vers,
) async {
  final motif = await showDialog<String?>(
    context: context,
    builder: (_) => _LicenceStatutDialog(licence: licence, vers: vers),
  );
  if (motif == null) return; // annulé
  try {
    await changerStatutLicence(ref,
        licenceId: licence.id, statut: vers, motif: motif.isEmpty ? null : motif);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: couleurStatutLicence(vers),
        content: Text('${licence.groupeNom} — licence '
            '${libelleStatutLicenceOuTiret(vers).toLowerCase()}'),
      ));
    }
  } catch (e) {
    // ⚠️ Le message de la base est affiché mot pour mot : c'est lui qui porte
    // le HINT (chevauchement, terme passé, marché résilié). Le remplacer par
    // « erreur » effacerait la seule explication utile.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: Text(messageErreur(e)),
        duration: const Duration(seconds: 8),
      ));
    }
  }
}

class _LicenceStatutDialog extends StatefulWidget {
  const _LicenceStatutDialog({required this.licence, required this.vers});

  final LicenceTutelle licence;
  final String vers;

  @override
  State<_LicenceStatutDialog> createState() => _LicenceStatutDialogState();
}

class _LicenceStatutDialogState extends State<_LicenceStatutDialog> {
  final _motif = TextEditingController();
  bool _tente = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  bool get _motifRequis => motifObligatoire(widget.vers);
  bool get _motifManque => _motifRequis && _motif.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final l = widget.licence;
    final couleur = couleurStatutLicence(widget.vers);
    final verbe = verbeTransitionLicence(widget.vers, depuis: l.statut);

    return AlertDialog(
      backgroundColor: kCardBg,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kModalRadius)),
      title: Row(children: [
        Icon(_icone, color: couleur, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$verbe la licence',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ce qu'on touche, en toutes lettres : nom du ministère, intitulé,
            // et le MONTANT. On ne suspend pas « une ligne », on suspend un
            // marché de quarante millions.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.groupeNom,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${l.intitule} · ${fmtXaf(l.montantXaf)}'
                        '${l.referenceMarche == null ? '' : ' · ${l.referenceMarche}'}',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _PastilleStatut(statut: l.statut),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 15, color: kTextMuted),
              const SizedBox(width: 8),
              _PastilleStatut(statut: widget.vers),
            ]),
            const SizedBox(height: 12),
            Text(explicationStatutLicence(widget.vers) ?? '',
                style:
                    TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45)),
            const SizedBox(height: 12),
            _ConsequenceReelle(vers: widget.vers, licence: l),
            if (_motifRequis) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _motif,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: adminInputDecoration(
                  'Motif (obligatoire)',
                  icon: Icons.edit_note_rounded,
                  hint: widget.vers == 'suspendue'
                      ? 'Ex. : mandat de paiement en attente au Trésor'
                      : 'Ex. : marché clos par avenant du 12/09/2026',
                ).copyWith(
                  errorText: _tente && _motifManque
                      ? 'Sans motif, cette décision ne se justifiera pas.'
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'Ce texte est lu par le ministère sur sa propre page, et '
                  'conservé au journal.',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton.icon(
          onPressed: () {
            setState(() => _tente = true);
            if (_motifManque) return;
            Navigator.pop(context, _motif.text.trim());
          },
          icon: Icon(_icone, size: 17),
          label: Text(verbe),
          style: FilledButton.styleFrom(
              backgroundColor: couleur, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  IconData get _icone => switch (widget.vers) {
        'active' => widget.licence.statut == 'suspendue'
            ? Icons.play_arrow_rounded
            : Icons.check_circle_rounded,
        'suspendue' => Icons.pause_circle_rounded,
        'echue' => Icons.event_busy_rounded,
        'resiliee' => Icons.gavel_rounded,
        _ => Icons.help_outline_rounded,
      };
}

/// Ce que le geste change VRAIMENT — et ce qu'il ne change pas.
class _ConsequenceReelle extends StatelessWidget {
  const _ConsequenceReelle({required this.vers, required this.licence});

  final String vers;
  final LicenceTutelle licence;

  @override
  Widget build(BuildContext context) {
    final sortDuRevenu = licence.estActive && vers != 'active';
    final entreDansRevenu = !licence.estActive && vers == 'active';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.08),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_user_rounded, size: 15, color: kGreen),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              // ⚠️ LA phrase. Un fondateur qui suspend doit savoir, au moment
              // où il clique, qu'il ne coupe personne.
              'Cela ne coupe l’accès de personne : ni le ministère, ni son '
              'réseau, ni un seul de ses modules.',
              style: TextStyle(
                  fontSize: 11.5,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4),
            ),
          ),
        ]),
        if (sortDuRevenu || entreDansRevenu) ...[
          const SizedBox(height: 7),
          Row(children: [
            Icon(
                sortDuRevenu
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                size: 15,
                color: sortDuRevenu ? kAccent : kGreen),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                sortDuRevenu
                    ? 'Le revenu de licence perd ${fmtXaf(licence.mensuelXaf)} '
                        'par mois : seules les licences ACTIVES y comptent.'
                    : 'Le revenu de licence gagne ${fmtXaf(licence.mensuelXaf)} '
                        'par mois.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _PastilleStatut extends StatelessWidget {
  const _PastilleStatut({required this.statut});

  final String statut;

  @override
  Widget build(BuildContext context) => PuceEconomie(
        texte: libelleStatutLicenceOuTiret(statut).toUpperCase(),
        couleur: couleurStatutLicence(statut),
      );
}
