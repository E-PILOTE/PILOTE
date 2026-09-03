part of '../economie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'UN MARCHÉ — ce que la carte ne pouvait pas montrer
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  La liste des licences empilait des cartes qui portaient tout : intitulé,
//  période, montant, mensualisé, solde, motif, plus une rangée de boutons.
//  Sur quarante millions, c'était à la fois trop et pas assez — trop pour être
//  balayé du regard, pas assez pour décider. Le fondateur : « je trouve ces
//  pages pauvres, on a besoin de voir le détail avec des modales ».
//
//  ── LE PARTAGE ────────────────────────────────────────────────────────────
//  La CARTE répond à « où en est-on ? » en une seconde : qui, combien, quelle
//  part réglée, et faut-il s'en occuper. La FICHE répond à « que fait-on ? » :
//  les quatre sommes, les deux barres (temps et règlement), la période, le
//  motif du dernier changement, l'état de l'accès — et les gestes.
//
//  ── ⚠️ POURQUOI LES GESTES SONT ICI, ET PAS SUR LA CARTE ──────────────────
//  Résilier un marché de quarante millions ou couper l'accès d'un ministère ne
//  doit pas être à un clic dans une liste qu'on parcourt. Il faut avoir ouvert
//  la fiche, donc avoir vu le montant, la période et le solde. C'est la seule
//  friction du dossier, et elle est délibérée.
// ════════════════════════════════════════════════════════════════════════════

Future<void> _ouvrirDetailLicence(
    BuildContext context, WidgetRef ref, LicenceTutelle licence) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _LicenceDetail(licenceId: licence.id),
  );
}

/// ⚠️ La fiche se relit depuis le provider à chaque construction, par son
/// identifiant — jamais depuis l'objet passé à l'ouverture. Sans cela, activer
/// puis suspendre sans refermer laisserait la fiche afficher l'état d'avant,
/// et le geste suivant se déciderait sur un écran périmé.
class _LicenceDetail extends ConsumerWidget {
  const _LicenceDetail({required this.licenceId});

  final String licenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(economieProvider).valueOrNull;
    LicenceTutelle? l;
    for (final x in d?.licences ?? const <LicenceTutelle>[]) {
      if (x.id == licenceId) {
        l = x;
        break;
      }
    }
    if (l == null) return const SizedBox.shrink();

    final couleur = couleurStatutLicence(l.statut);
    return AdminFormDialog(
      icon: Icons.gavel_rounded,
      title: l.intitule,
      subtitle: l.groupeNom,
      accent: couleur,
      width: 620,
      headerTrailing: _Puce(
          texte: libelleStatutLicenceOuTiret(l.statut).toUpperCase(),
          couleur: Colors.white),
      hero: _HeroMontant(licence: l, couleur: couleur),
      // « Modifier les conditions » quitte la liste pour la fiche : on ne
      // change pas un montant de marché sans l'avoir sous les yeux.
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _ouvrirLicence(context, ref, edition: l);
            },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Modifier les conditions'),
            style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kTextMuted)),
          ),
        ]),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (l.motifStatut != null && l.motifStatut!.trim().isNotEmpty) ...[
          _BlocMotif(
              titre: 'Dernier changement de statut',
              texte: l.motifStatut!,
              date: l.statutChangeLe,
              couleur: couleur),
          const SizedBox(height: 14),
        ],
        const AdminModalSectionTitle('Règlement'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.request_quote_rounded, 'Montant du marché',
              fmtXaf(l.montantXaf)),
          AdminDetailRow(Icons.savings_rounded, 'Avance de démarrage',
              fmtXaf(l.avanceXaf)),
          AdminDetailRow(
              Icons.payments_rounded, 'Encaissé', fmtXaf(l.montantRegleXaf)),
          AdminDetailRow(
            Icons.account_balance_wallet_rounded,
            l.soldeXaf <= 0 ? 'Solde' : 'Reste à encaisser',
            fmtXaf(l.soldeXaf < 0 ? 0 : l.soldeXaf),
            valueColor: l.soldeXaf <= 0 ? kGreen : kListOrange,
            last: true,
          ),
        ]),
        const SizedBox(height: 14),
        // ⚠️ Les DEUX barres, l'une sous l'autre. Un marché peut être couvert
        // à 80 % du temps et réglé à 25 % : c'est cet écart-là qui déclenche
        // une relance, et aucune des deux barres seule ne le montre.
        _DeuxBarres(licence: l, couleur: couleur),
        const SizedBox(height: 16),
        const AdminModalSectionTitle('Marché'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.play_arrow_rounded, 'Début', _d(l.dateDebut)),
          AdminDetailRow(Icons.flag_rounded, 'Terme', _d(l.dateFin)),
          AdminDetailRow(Icons.timelapse_rounded, 'Durée',
              '${l.moisCouverts} mois · ${fmtXaf(l.mensuelXaf)} / mois'),
          AdminDetailRow(Icons.numbers_rounded, 'Référence',
              l.referenceMarche ?? '—',
              mono: l.referenceMarche != null),
          AdminDetailRow(Icons.draw_rounded, 'Signataire', l.signataire ?? '—',
              last: l.notes == null || l.notes!.trim().isEmpty),
          if (l.notes != null && l.notes!.trim().isNotEmpty)
            AdminDetailRow(Icons.sticky_note_2_rounded, 'Notes', l.notes!,
                last: true),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Cycle de vie du marché'),
        const SizedBox(height: 4),
        Text(
            'Ces gestes ne touchent PAS l’accès du ministère : une licence '
            'suspendue ne coupe rien.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
        const SizedBox(height: 10),
        if (transitionsLicence(l.statut).isEmpty)
          Text('Marché clos — aucun geste possible.',
              style: TextStyle(fontSize: 12, color: kTextMuted))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final vers in transitionsLicence(l.statut))
              _BoutonTransition(licence: l, vers: vers),
          ]),
        const SizedBox(height: 20),
        _ZoneAcces(licence: l),
      ]),
    );
  }
}

// ─── Le bandeau fixe : le montant reste visible pendant qu'on défile ───────
class _HeroMontant extends StatelessWidget {
  const _HeroMontant({required this.licence, required this.couleur});

  final LicenceTutelle licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTANT DU MARCHÉ',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: kTextMuted)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(fmtXaf(licence.montantXaf),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            color: kTextPrimary)),
                  ),
                ]),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(licence.soldeXaf <= 0 ? 'Soldé' : 'Reste à encaisser',
                style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            Text(fmtXaf(licence.soldeXaf < 0 ? 0 : licence.soldeXaf),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: licence.soldeXaf <= 0 ? kGreen : kListOrange)),
          ]),
        ]),
      );
}

class _DeuxBarres extends StatelessWidget {
  const _DeuxBarres({required this.licence, required this.couleur});

  final LicenceTutelle licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final regle = licence.montantXaf <= 0
        ? null
        : (licence.montantRegleXaf / licence.montantXaf).clamp(0.0, 1.0);
    final ecoule = licence.partEcoulee;
    // L'écart entre les deux : le nombre qui déclenche une relance.
    final retard = regle == null ? null : ecoule - regle;

    return Column(children: [
      _Barre(
          label: 'Période écoulée',
          valeur: ecoule,
          couleur: couleur,
          texte: '${(ecoule * 100).round()} %'),
      if (regle != null) ...[
        const SizedBox(height: 8),
        _Barre(
            label: 'Marché réglé',
            valeur: regle,
            couleur: regle >= ecoule ? kGreen : kListOrange,
            texte: '${(regle * 100).round()} %'),
      ],
      if (retard != null && retard > 0.15) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.trending_down_rounded,
              size: 15, color: kListOrange),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
                'Le règlement a ${(retard * 100).round()} points de retard sur '
                'la période consommée.',
                style: const TextStyle(
                    fontSize: 11.5, color: kListOrange)),
          ),
        ]),
      ],
    ]);
  }
}

class _Barre extends StatelessWidget {
  const _Barre(
      {required this.label,
      required this.valeur,
      required this.couleur,
      required this.texte});

  final String label, texte;
  final double valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 108,
          child: Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: valeur.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: couleur.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(couleur),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(texte,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ),
      ]);
}

class _BlocMotif extends StatelessWidget {
  const _BlocMotif(
      {required this.titre,
      required this.texte,
      required this.couleur,
      this.date});

  final String titre, texte;
  final Color couleur;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.07),
          border: Border.all(color: couleur.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.sticky_note_2_rounded, size: 15, color: couleur),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date == null ? titre : '$titre · ${_d(date!)}',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: kTextMuted)),
                  const SizedBox(height: 3),
                  Text(texte.trim(),
                      style: TextStyle(
                          fontSize: 12.5, color: kTextPrimary, height: 1.45)),
                ]),
          ),
        ]),
      );
}

// ─── ⚠️ LA ZONE DE DERNIER RECOURS ─────────────────────────────────────────
//
//  Encadrée en rouge, en bas, séparée du reste par un titre qui dit ce que
//  c'est. Ce n'est pas une décoration : couper l'accès d'un ministère de
//  l'Éducation nationale est le geste le plus grave de cette application, et
//  il ne doit ressembler à aucun autre bouton.
class _ZoneAcces extends ConsumerWidget {
  const _ZoneAcces({required this.licence});

  final LicenceTutelle licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupe = licence.accesSuspendu;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: coupe ? 0.09 : 0.04),
        border: Border.all(color: kRed.withValues(alpha: coupe ? 0.45 : 0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(coupe ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 16, color: kRed),
          const SizedBox(width: 8),
          Text(coupe ? 'Accès coupé' : 'Accès à la plateforme',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: kRed)),
        ]),
        const SizedBox(height: 6),
        Text(
          coupe
              ? 'L’espace de ce ministère est fermé. Sa vue sur le réseau, ses '
                  'circulaires et ses destinataires sont refusés par le '
                  'serveur. Ses écoles, elles, travaillent normalement.'
              : 'Dernier recours en cas de modalités de paiement non '
                  'respectées. Ferme l’espace du ministère et lui refuse la '
                  'vue sur son réseau et l’envoi de circulaires. '
                  'N’efface rien, et n’arrête aucune école du réseau.',
          style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45),
        ),
        if (coupe &&
            licence.accesSuspenduMotif != null &&
            licence.accesSuspenduMotif!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('« ${licence.accesSuspenduMotif!.trim()} »',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: kTextPrimary)),
        ],
        const SizedBox(height: 12),
        coupe
            ? FilledButton.icon(
                onPressed: () => _retablirAcces(context, ref, licence),
                icon: const Icon(Icons.lock_open_rounded, size: 17),
                label: const Text('Rétablir l’accès'),
                style: FilledButton.styleFrom(
                    backgroundColor: kGreen, foregroundColor: Colors.white),
              )
            : OutlinedButton.icon(
                onPressed: () => _couperAcces(context, ref, licence),
                icon: const Icon(Icons.lock_rounded, size: 17),
                label: const Text('Couper l’accès du ministère'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRed,
                  side: BorderSide(color: kRed.withValues(alpha: 0.4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
      ]),
    );
  }
}

Future<void> _couperAcces(
    BuildContext context, WidgetRef ref, LicenceTutelle l) async {
  final motif = await showDialog<String>(
    context: context,
    builder: (_) => _MotifCoupureDialog(groupeNom: l.groupeNom),
  );
  if (motif == null || motif.trim().isEmpty) return;
  try {
    await couperAccesGroupe(ref, groupId: l.groupId, motif: motif.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text('Accès de ${l.groupeNom} coupé.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          duration: const Duration(seconds: 8),
          content: Text(messageErreur(e))));
    }
  }
}

Future<void> _retablirAcces(
    BuildContext context, WidgetRef ref, LicenceTutelle l) async {
  try {
    await retablirAccesGroupe(ref, groupId: l.groupId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('Accès de ${l.groupeNom} rétabli.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed, content: Text(messageErreur(e))));
    }
  }
}

class _MotifCoupureDialog extends StatefulWidget {
  const _MotifCoupureDialog({required this.groupeNom});

  final String groupeNom;

  @override
  State<_MotifCoupureDialog> createState() => _MotifCoupureDialogState();
}

class _MotifCoupureDialogState extends State<_MotifCoupureDialog> {
  final _motif = TextEditingController();
  bool _tente = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vide = _motif.text.trim().isEmpty;
    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kModalRadius)),
      title: Row(children: [
        Icon(Icons.lock_rounded, color: kRed, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Couper l’accès',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupeNom,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _LigneEffet(
                icone: Icons.block_rounded,
                texte: 'Son espace se ferme sur une page qui explique.',
                couleur: kRed),
            _LigneEffet(
                icone: Icons.hub_rounded,
                texte: 'Vue sur le réseau, circulaires et destinataires : '
                    'refusés par le serveur.',
                couleur: kRed),
            _LigneEffet(
                icone: Icons.school_rounded,
                texte: 'Les écoles du réseau ne sont PAS touchées : elles '
                    'gardent leur accès et leur synchro hors ligne.',
                couleur: kGreen),
            _LigneEffet(
                icone: Icons.inventory_2_rounded,
                texte: 'Aucune donnée n’est effacée. Tout revient au '
                    'rétablissement.',
                couleur: kGreen),
            const SizedBox(height: 14),
            TextField(
              controller: _motif,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: adminInputDecoration(
                'Motif (obligatoire)',
                icon: Icons.edit_note_rounded,
                hint: 'Ex. : trois échéances impayées — marché MEPSA/2026/001',
              ).copyWith(
                errorText: _tente && vide
                    ? 'C’est la seule chose que le ministère lira.'
                    : null,
              ),
            ),
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
            if (vide) return;
            Navigator.pop(context, _motif.text.trim());
          },
          icon: const Icon(Icons.lock_rounded, size: 17),
          label: const Text('Couper l’accès'),
          style: FilledButton.styleFrom(
              backgroundColor: kRed, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

class _LigneEffet extends StatelessWidget {
  const _LigneEffet(
      {required this.icone, required this.texte, required this.couleur});

  final IconData icone;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style:
                    TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
          ),
        ]),
      );
}
