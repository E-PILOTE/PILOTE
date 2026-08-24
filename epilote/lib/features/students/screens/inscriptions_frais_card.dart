part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ARGENT, AU GUICHET DES INSCRIPTIONS.
//
//  Le dossier disait tout de l'élève et rien de ce qu'il doit. Le chef validait
//  donc une inscription sans savoir si elle était payée — alors que dans une
//  école privée congolaise, c'est le versement qui FAIT l'inscription.
//
//  Cette carte montre le seul frais dont le guichet d'admission a besoin :
//  l'INSCRIPTION. La mensualité se recouvre au fil de l'année dans le module
//  Paiements ; la rappeler ici transformerait un guichet d'admission en écran
//  de recouvrement. Le décompte complet, lui, part sur la fiche imprimée.
//
//  ⚠️ On avertit, on ne BLOQUE jamais. Barrer l'entrée d'un enfant pour un
//  versement en retard ferait du module un outil de sélection par l'argent —
//  même doctrine que pour les pièces manquantes du dossier.
// ════════════════════════════════════════════════════════════════════════════


class _FraisInscriptionCard extends ConsumerWidget {
  const _FraisInscriptionCard({required this.row});
  final InscriptionRow row;

  Color _couleur(EtatObligation e) => switch (e) {
        EtatObligation.aJour => kGreen,
        EtatObligation.exonere => kGreen,
        EtatObligation.partiel => kAccent,
        EtatObligation.impaye => kRed,
        EtatObligation.sansBareme => kTextMuted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fraisInscriptionProvider(row.id));
    final f = async.valueOrNull;

    // Tant que le barème charge, on n'affiche rien plutôt qu'un « 0 F dû » qui
    // se lirait comme « rien à payer ».
    if (f == null) return const SizedBox.shrink();

    if (!f.baremeDefini) {
      return const ResumeCard(
        title: 'Frais d\'inscription',
        icon: Icons.payments_outlined,
        rows: [
          (
            'Barème',
            'Aucun tarif d\'inscription n\'est défini pour ce niveau',
          ),
          (
            'Encaissement',
            'Impossible tant que le groupe n\'a pas publié de barème',
          ),
        ],
      );
    }

    final couleur = _couleur(f.etat);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.payments_outlined, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(f.libelle ?? 'Frais d\'inscription',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          AdminBadge(f.libelleEtat, color: couleur),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Montant(label: 'Dû', valeur: f.du, couleur: kTextPrimary),
          _Montant(label: 'Versé', valeur: f.verse, couleur: kGreen),
          _Montant(
              label: 'Reste',
              valeur: f.reste,
              couleur: f.reste > 0 ? kRed : kGreen),
        ]),
        // Un dû plus bas que le tarif annoncé à la famille, sans explication,
        // se lit comme un bug et part au support. On dit d'où vient l'écart.
        if (f.estExonere) ...[
          const SizedBox(height: 8),
          Text(
            'Tarif ${f.montantBareme} F · exonération de ${f.exoneration} % '
            '(−${f.montantExonere} F)',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ],
        if (f.reste > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _encaisser(context, ref, f),
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('Encaisser et éditer le reçu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kNavy.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _encaisser(
    BuildContext context,
    WidgetRef ref,
    FraisInscription f,
  ) async {
    if (writeRefusedForLicense(context)) return;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);

    // Les identifiants de rattachement sont exigés AVANT d'ouvrir la boîte : un
    // paiement sans `group_id`/`school_id` est refusé au serveur, et PowerSync
    // abandonne alors le LOT ENTIER — le versement ET tout ce qui a été saisi
    // dans la même fenêtre disparaîtraient sans message.
    final manquants = missingWriteIds(
      groupId: profile?.groupId,
      schoolId: profile?.schoolId,
      actorId: profile?.id,
    );
    if (manquants.isNotEmpty || yearId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(manquants.isEmpty
            ? 'Aucune année scolaire active — encaissement impossible.'
            : writeIdentityMessage(manquants)),
        backgroundColor: kRed,
      ));
      return;
    }

    final saisie = await _demanderMontant(context, f);
    if (saisie == null || !context.mounted) return;
    final (montant, methode) = saisie;

    try {
      final recu = await savePayment(
        groupId: profile!.groupId!,
        schoolId: profile.schoolId!,
        academicYearId: yearId,
        studentId: row.studentId,
        enrollmentId: row.id,
        feeStructureId: f.feeStructureId,
        amount: montant,
        date: DateTime.now().toIso8601String().substring(0, 10),
        method: methode,
        status: 'confirmed',
        recordedBy: profile.id,
      );
      ref.invalidate(fraisInscriptionProvider(row.id));
      if (!context.mounted) return;
      // ── LE REÇU SORT ICI, DEVANT LA FAMILLE ────────────────────────────────
      // Il fallait auparavant ressortir de l'écran, ouvrir Paiements et
      // retrouver l'élève : autant dire que personne ne le faisait, et que la
      // famille repartait sans preuve de son versement. Au Congo, le reçu EST
      // la preuve du paiement.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$montant F encaissés'
            '${recu == null ? '' : ' — reçu $recu'}.'),
        backgroundColor: kGreen,
      ));
      if (recu != null) {
        await _imprimerRecu(context, ref, recu: recu, montant: montant,
            methode: methode, libelle: f.libelle);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(messageErreur(e)),
          backgroundColor: kRed,
        ));
      }
    }
  }

  /// Ouvre l'aperçu du reçu tout juste émis.
  ///
  /// ⚠️ Le solde vient du DÉCOMPTE, pas du seul frais d'inscription : c'est le
  /// reste de scolarité que la famille veut connaître, et l'imprimer à partir
  /// d'une seule ligne annoncerait « soldé » à un élève qui doit encore neuf
  /// mois. Inconnu ⇒ la ligne est omise (cf. `RecuPaiement.resteDu`).
  Future<void> _imprimerRecu(
    BuildContext context,
    WidgetRef ref, {
    required String recu,
    required int montant,
    required String methode,
    String? libelle,
  }) async {
    final acteur =
        ref.read(authNotifierProvider).valueOrNull?.fullName ?? 'Le caissier';
    // ⚠️ `decompteDuProvider` est un `StreamProvider.autoDispose.family`, et
    // cette carte ne l'écoute pas — elle écoute `fraisInscriptionProvider`.
    // Lu sans attendre, il rendait donc TOUJOURS `null`, et le reçu remis à la
    // famille sortait systématiquement sans sa ligne « reste dû ». Le champ
    // existait, le service savait l'imprimer, il n'était jamais rempli.
    DecompteDu? d;
    try {
      d = await ref.read(decompteDuProvider(row.id).future);
    } catch (_) {
      d = null; // décompte illisible : le reçu sort sans la ligne, pas faux.
    }
    if (!context.mounted) return;
    showPdfPreviewDialog(
      context,
      title: 'Reçu de paiement',
      subtitle: recu,
      pdfFileName: '$recu.pdf',
      build: (_) => construireRecuPaiement(
        recu: RecuPaiement(
          numero: recu,
          eleve: row.fullName,
          matricule: row.matricule,
          classe: row.className,
          montant: montant,
          date: DateTime.now(),
          methode: paymentMethodLabel(methode),
          encaissePar: acteur,
          motifFrais: libelle ?? 'Frais d\'inscription',
          resteDu: (d == null || d.vide) ? null : d.reste,
        ),
      ),
    );
  }

  /// Montant et moyen de paiement. Le reste dû est proposé, jamais imposé :
  /// l'avance partielle est la norme, pas l'exception.
  Future<(int, String)?> _demanderMontant(
    BuildContext context,
    FraisInscription f,
  ) {
    final ctrl = TextEditingController(text: '${f.reste}');
    var methode = 'especes';
    return showDialog<(int, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Encaisser les frais d\'inscription'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant reçu (FCFA)',
                helperText: 'Reste dû : ${f.reste} F sur ${f.du} F',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: methode,
              decoration: const InputDecoration(
                labelText: 'Moyen de paiement',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in kPaymentMethods)
                  DropdownMenuItem(value: m.$1, child: Text(m.$2)),
              ],
              onChanged: (v) => setSt(() => methode = v ?? 'especes'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                if (v == null || v <= 0) return;
                Navigator.pop(ctx, (v, methode));
              },
              child: const Text('Encaisser'),
            ),
          ],
        ),
      ),
    ).whenComplete(ctrl.dispose);
  }
}

/// Un montant de la carte de frais.
class _Montant extends StatelessWidget {
  const _Montant(
      {required this.label, required this.valeur, required this.couleur});
  final String label;
  final int valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: kTextMuted)),
          const SizedBox(height: 2),
          Text('$valeur F',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

