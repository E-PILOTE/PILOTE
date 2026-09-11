part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'EN-TÊTE — ce qui reste vrai quel que soit l'onglet
//
//  ── CE QU'IL PORTE, ET POURQUOI CES CHOSES-LÀ ──────────────────────────────
//  La photo, le nom, la classe, le matricule et l'identifiant national : les
//  cinq renseignements avec lesquels on VÉRIFIE qu'on tient le bon dossier
//  avant de dire quoi que ce soit à une famille. Ils ne défilent pas avec les
//  onglets, parce que se tromper d'enfant est l'erreur la plus coûteuse que
//  cette page puisse produire.
//
//  ── LES ALERTES NE SONT PAS DES DÉCORATIONS ────────────────────────────────
//  ⚠️ Trois seulement, et chacune EMPÊCHE quelque chose :
//   • aucun contact principal → l'école a des numéros mais aucun ne se présente
//     comme celui qu'on compose ; le défaut est connu, documenté dans le
//     tiroir, et il se répare en deux clics ;
//   • pièces obligatoires manquantes → le dossier ne passera pas à l'examen ;
//   • reste dû → la caisse doit le savoir AVANT de délivrer un papier.
//
//  Une absence de saisie ordinaire (pas de nationalité, pas de groupe sanguin)
//  n'est pas une alerte : la noyer dans la même couleur rendrait les trois
//  vraies invisibles.
// ════════════════════════════════════════════════════════════════════════════

class FicheEntete extends ConsumerWidget {
  const FicheEntete({
    super.key,
    required this.studentId,
    required this.dossier,
    required this.parcours,
    required this.annee,
    required this.etroit,
  });

  final String studentId;
  final StudentDossier dossier;
  final List<ParcoursAnnee> parcours;
  final AnneeFiche? annee;
  final bool etroit;

  /// L'inscription de l'année affichée — celle qui donne la classe montrée en
  /// tête, et l'identifiant dont le décompte financier a besoin.
  ParcoursAnnee? get _inscription {
    if (parcours.isEmpty) return null;
    final l = annee?.label;
    if (l == null || l.isEmpty) return parcours.first;
    return parcours.where((p) => p.anneeLabel == l).firstOrNull ??
        parcours.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insc = _inscription;
    final pieces = ref.watch(fichePiecesCountProvider(studentId)).valueOrNull;
    final readOnly = ref.watch(yearReadOnlyProvider);
    final peutModifier = !readOnly &&
        ref.watch(canProvider((slug: _kSlugFiche, action: 'update')));

    return Container(
      padding: EdgeInsets.fromLTRB(etroit ? 14 : 20, 18, etroit ? 14 : 20, 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flex(
          direction: etroit ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoAvatar(
              name: dossier.nomComplet,
              photoUrl: dossier.s('photo_url'),
              size: etroit ? 72 : 96,
            ),
            SizedBox(width: etroit ? 0 : 20, height: etroit ? 14 : 0),
            Expanded(
              flex: etroit ? 0 : 1,
              child: _Identite(dossier: dossier, inscription: insc),
            ),
            SizedBox(width: etroit ? 0 : 16, height: etroit ? 14 : 0),
            _Actions(
              studentId: studentId,
              dossier: dossier,
              annee: annee,
              peutModifier: peutModifier,
              etroit: etroit,
            ),
          ],
        ),
        _Alertes(
          dossier: dossier,
          inscription: insc,
          pieces: pieces,
        ),
      ]),
    );
  }
}

class _Identite extends StatelessWidget {
  const _Identite({required this.dossier, required this.inscription});

  final StudentDossier dossier;
  final ParcoursAnnee? inscription;

  @override
  Widget build(BuildContext context) {
    final age = dossier.age;
    final naissance = dossier.dob == null
        ? null
        : '${_dtLong(dossier.dob)}${age != null ? ' · $age ans' : ''}';
    final i = inscription;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(
        dossier.nomComplet.isEmpty ? 'Élève sans nom' : dossier.nomComplet,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.15,
          color: kTextPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        [
          if (dossier.s('gender') == 'F')
            'Féminin'
          else if (dossier.s('gender') == 'M')
            'Masculin',
          if (naissance != null) 'Né${dossier.s('gender') == 'F' ? 'e' : ''} '
              'le $naissance',
          if (dossier.s('place_of_birth').isNotEmpty)
            'à ${dossier.s('place_of_birth')}',
        ].join(' · '),
        style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 7, children: [
        if (i != null && i.classe.isNotEmpty)
          AdminBadge(i.classe, color: kNavy),
        if (i != null && i.filiere.isNotEmpty)
          AdminBadge(i.filiere, color: kTextMuted),
        if (i != null)
          AdminBadge(
            enrollmentStatutLabel(i.statut),
            color: i.statut == 'active'
                ? kGreen
                : i.interrompue
                    ? kRed
                    : kAccent,
          ),
        if (i != null && i.redoublant) AdminBadge('Redoublant', color: kAccent),
        if (dossier.s('matricule').isNotEmpty)
          AdminBadge(dossier.s('matricule'), color: kTextMuted),
        // ⚠️ Le matricule ET l'identifiant national, jamais l'un pour l'autre.
        // Le premier est le numéro de l'école ; le second suit l'enfant s'il
        // change d'établissement. Les confondre reperd ce que l'INE apporte.
        AdminBadge(
          dossier.s('ine').isEmpty
              ? kIneEnAttente
              : formatIne(dossier.s('ine')),
          color: dossier.s('ine').isEmpty ? kAccent : kGreen,
        ),
        if (dossier.student['is_boarder'] == 1 ||
            dossier.student['is_boarder'] == true)
          AdminBadge('Interne', color: kNavy),
        if (dossier.student['has_scholarship'] == 1 ||
            dossier.student['has_scholarship'] == true)
          AdminBadge('Boursier', color: kGreen),
      ]),
    ]);
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.studentId,
    required this.dossier,
    required this.annee,
    required this.peutModifier,
    required this.etroit,
  });

  final String studentId;
  final StudentDossier dossier;
  final AnneeFiche? annee;
  final bool peutModifier, etroit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: etroit ? WrapAlignment.start : WrapAlignment.end,
      children: [
        if (peutModifier)
          AdminActionButton(
            label: 'Modifier',
            icon: Icons.edit_outlined,
            filled: true,
            onPressed: () => showStudentEditModal(
              context,
              studentId: studentId,
              fullName: dossier.nomComplet,
            ),
          ),
        AdminActionButton(
          label: 'Imprimer',
          icon: Icons.print_outlined,
          filled: false,
          onPressed: () => _choisirPortee(context, ref),
        ),
      ],
    );
  }

  /// ── POURQUOI ON DEMANDE AVANT D'IMPRIMER ─────────────────────────────────
  /// ⚠️ L'écran peut tout montrer à la secrétaire ; LE PAPIER SORT DE L'ÉCOLE.
  /// Groupe sanguin, allergies, passages à l'infirmerie, sanctions et
  /// situation financière de la famille n'ont rien à faire sur un document
  /// remis à un tiers — un employeur, une administration, une autre école.
  ///
  /// Deux portées, donc, et le choix est explicite : une case cochée par
  /// défaut finirait par être cochée toujours.
  void _choisirPortee(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: Text(
          'Que doit contenir le document ?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Portee(
              titre: 'Fiche administrative',
              detail: 'Identité, famille, scolarité et parcours. Ce qui peut '
                  'être remis à un tiers.',
              icone: Icons.description_outlined,
              couleur: kNavy,
              onTap: () {
                Navigator.of(ctx).pop();
                _imprimer(context, ref, complet: false);
              },
            ),
            const SizedBox(height: 10),
            _Portee(
              titre: 'Dossier complet interne',
              detail: 'Tout, y compris santé, conduite et finances. Réservé à '
                  "l'usage de l'établissement.",
              icone: Icons.folder_special_outlined,
              couleur: kRed,
              onTap: () {
                Navigator.of(ctx).pop();
                _imprimer(context, ref, complet: true);
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimer(
    BuildContext context,
    WidgetRef ref, {
    required bool complet,
  }) async {
    final matiere = await rassemblerFicheEleve(
      ref,
      studentId: studentId,
      dossier: dossier,
      annee: annee,
      complet: complet,
    );
    if (!context.mounted) return;
    final titre = complet ? 'Dossier complet' : 'Fiche administrative';
    showPdfPreviewDialog(
      context,
      title: titre,
      subtitle: dossier.nomComplet,
      pdfFileName: 'Fiche_${dossier.s('matricule')}.pdf'
          .replaceAll(RegExp(r'_+\.'), '.'),
      build: (_) => FicheElevePdfService.buildPdf(matiere: matiere),
      onDownload: () => FicheElevePdfService.downloadDoc(matiere: matiere),
    );
  }
}

class _Portee extends StatelessWidget {
  const _Portee({
    required this.titre,
    required this.detail,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  final String titre, detail;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: couleur.withValues(alpha: 0.35)),
              color: couleur.withValues(alpha: 0.05),
            ),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icone, size: 20, color: couleur),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: kTextMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class _Alertes extends ConsumerWidget {
  const _Alertes({
    required this.dossier,
    required this.inscription,
    required this.pieces,
  });

  final StudentDossier dossier;
  final ParcoursAnnee? inscription;
  final (int, int)? pieces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertes = <(String, Color)>[];

    if (dossier.tutors.isEmpty) {
      alertes.add(('Aucun tuteur enregistré — la famille est injoignable', kRed));
    } else if (!dossier.tutors.any((t) => t.isPrimary)) {
      alertes.add((
        'Aucun contact principal désigné — aucun numéro ne se présente comme '
            'celui à composer',
        kRed,
      ));
    }

    if (pieces != null && pieces!.$1 == 0) {
      alertes.add(('Aucune pièce au dossier', kAccent));
    }

    // Le décompte n'est demandé que si l'élève a une inscription : sans
    // identifiant, il n'y a rien à calculer, et le provider n'a pas de sens.
    final ie = inscription?.enrollmentId;
    if (ie != null && ie.isNotEmpty) {
      final d = ref.watch(decompteDuProvider(ie)).valueOrNull;
      if (d != null && d.reste > 0) {
        alertes.add((
          'Reste dû : ${CurrencyFormatter.format(d.reste)}',
          kRed,
        ));
      }
      if (d != null && d.boursierSansTaux) {
        alertes.add((
          'Déclaré boursier, sans taux saisi — la scolarité entière reste due',
          kAccent,
        ));
      }
    }

    if (alertes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (texte, couleur) in alertes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: couleur.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: couleur),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  texte,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
