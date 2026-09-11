part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ACTES & PIÈCES — ce que l'école a produit, ce qui a été décidé
//
//  Cinq registres rares et définitifs : un papier délivré, une candidature à
//  un examen d'État, un avis d'orientation, un stage, un transfert. Ils
//  répondent tous à la question du guichet : « qu'est-ce que l'école a produit
//  pour cet enfant, et qu'a-t-on décidé de lui ? »
//
//  ── DÉLIVRÉ N'EST PAS DÉPOSÉ ───────────────────────────────────────────────
//  ⚠️ `issued_documents` = ce que l'école ÉMET (certificat de scolarité, carte
//  scolaire). Les pièces que la FAMILLE dépose (acte de naissance, certificat
//  médical) vivent dans l'onglet « Identité & famille ». Les deux tables
//  portent une colonne `document_type` et se ressemblent — les confondre
//  ferait dire à la fiche qu'un dossier est complet parce que l'école a
//  imprimé une carte.
// ════════════════════════════════════════════════════════════════════════════

class FicheActes extends ConsumerWidget {
  const FicheActes({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncActes = ref.watch(ficheActesProvider(studentId));

    return asyncActes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AdminErrorBanner(message: messageErreur(e)),
      data: (a) => Column(children: [
        _Delivres(actes: a.delivres),
        _Examens(candidatures: a.examens),
        _Orientations(avis: a.orientations),
        _Stages(stages: a.stages),
        _Transferts(transferts: a.transferts),
      ]),
    );
  }
}

class _Delivres extends StatelessWidget {
  const _Delivres({required this.actes});
  final List<ActeDelivre> actes;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Documents délivrés par l\'école',
        icone: Icons.description_outlined,
        compte: actes.length,
        action: FicheRenvoi(
          label: 'Registre des documents',
          onTap: () => context.push(Routes.documents),
        ),
        enfants: [
          if (actes.isEmpty)
            const FicheVide(
              "Aucun document n'a encore été délivré à cet élève : ni "
              'certificat de scolarité, ni carte scolaire, ni attestation.',
            )
          else
            for (final a in actes)
              FicheChrono(
                date: _dt(a.date),
                titre: documentDelivreLabel(a.type),
                detail: [
                  if (a.anneeLabel.isNotEmpty) 'Année ${a.anneeLabel}',
                  if (a.parQui.isNotEmpty) 'Délivré par ${a.parQui}',
                  if (a.motif.isNotEmpty) 'Motif : ${a.motif}',
                  if (a.reference.isNotEmpty) 'Réf. ${a.reference}',
                ].join(' · '),
                couleur: kNavy,
              ),
        ],
      );
}

class _Examens extends StatelessWidget {
  const _Examens({required this.candidatures});
  final List<CandidatureExamen> candidatures;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Examens d\'État',
        icone: Icons.workspace_premium_outlined,
        couleur: kAccent,
        compte: candidatures.length,
        action: FicheRenvoi(
          label: 'Module Examens',
          onTap: () => context.push(Routes.examens),
        ),
        enfants: [
          if (candidatures.isEmpty)
            const FicheVide(
              "Cet élève n'a été présenté à aucun examen d'État.",
            )
          else
            for (final c in candidatures) ...[
              FicheChrono(
                date: c.session,
                titre: [
                  c.examen.isEmpty ? 'Examen' : c.examen,
                  if (c.numero.isNotEmpty) '· n° ${c.numero}',
                ].join(' '),
                detail: [
                  'Dossier : ${examDossierLabel(c.statutDossier)}',
                  // ⚠️ Les pièces manquantes se disent ICI, nommément. Un
                  // dossier « incomplet » sans la liste de ce qui manque
                  // n'est pas une information : c'est une inquiétude.
                  if (c.piecesManquantes.isNotEmpty)
                    'Manque : ${c.piecesManquantes}',
                  if (c.centre.isNotEmpty) 'Centre : ${c.centre}',
                  if (c.redoublant) 'Candidat redoublant',
                ].join('\n'),
                couleur: switch (c.resultat) {
                  'admis' => kGreen,
                  'ajourne' || 'absent' => kRed,
                  _ => kAccent,
                },
                badge: examResultatLabel(c.resultat),
              ),
              if (c.moyenne != null || c.mention.isNotEmpty)
                FicheLigne(
                  label: 'Résultat ${c.session}',
                  valeur: [
                    if (c.moyenne != null) '${_num1(c.moyenne)}/20',
                    if (c.mention.isNotEmpty) '— mention ${c.mention}',
                  ].join(' '),
                  gras: true,
                ),
            ],
        ],
      );
}

class _Orientations extends StatelessWidget {
  const _Orientations({required this.avis});
  final List<AvisOrientation> avis;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Avis d\'orientation',
        icone: Icons.signpost_outlined,
        compte: avis.length,
        action: FicheRenvoi(
          label: 'Module Orientation',
          onTap: () => context.push(Routes.orientation),
        ),
        enfants: [
          if (avis.isEmpty)
            const FicheVide(
              'Aucun avis d\'orientation rendu pour cet élève.',
            )
          else
            for (final a in avis)
              FicheChrono(
                date: _dt(a.date),
                titre: [
                  if (a.anneeLabel.isNotEmpty) a.anneeLabel,
                  if (a.trimestre.isNotEmpty) a.trimestre,
                ].join(' · '),
                detail: [
                  if (a.recommandation.isNotEmpty) a.recommandation,
                  if (a.niveauVise.isNotEmpty || a.filiereVisee.isNotEmpty)
                    'Vers : ${[a.niveauVise, a.filiereVisee].where((s) => s.isNotEmpty).join(' · ')}',
                  // La famille a-t-elle été reçue ? Un avis rendu sans qu'elle
                  // le sache est un avis qui produira une surprise.
                  a.familleConsultee
                      ? 'Famille consultée'
                      : 'Famille NON consultée',
                ].join('\n'),
                couleur: kNavy,
                badge: a.familleConsultee ? null : 'À notifier',
              ),
        ],
      );
}

class _Stages extends StatelessWidget {
  const _Stages({required this.stages});
  final List<StageLigne> stages;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Stages en entreprise',
        icone: Icons.work_outline_rounded,
        compte: stages.length,
        action: FicheRenvoi(
          label: 'Module Stages',
          onTap: () => context.push(Routes.stages),
        ),
        enfants: [
          if (stages.isEmpty)
            const FicheVide(
              'Aucun stage enregistré — ce qui est normal hors des filières '
              'techniques et professionnelles.',
            )
          else
            for (final s in stages)
              FicheChrono(
                date: _dt(s.debut),
                titre: [
                  s.titre.isEmpty ? 'Stage' : s.titre,
                  if (s.entreprise.isNotEmpty) '· ${s.entreprise}',
                ].join(' '),
                detail: [
                  if (s.fin != null) 'Jusqu\'au ${_dt(s.fin)}',
                  if (s.tuteurEntreprise.isNotEmpty)
                    'Tuteur : ${s.tuteurEntreprise}',
                  if (s.conventionSignee != null)
                    'Convention signée le ${_dt(s.conventionSignee)}'
                  else
                    'Convention NON signée',
                  if (s.note != null) 'Évaluation : ${_num1(s.note)}/20',
                  if (s.appreciation.isNotEmpty) s.appreciation,
                  if (s.attestationLe != null)
                    'Attestation délivrée le ${_dt(s.attestationLe)}',
                ].join('\n'),
                couleur: switch (s.statut) {
                  'valide' || 'termine' => kGreen,
                  'interrompu' => kRed,
                  _ => kNavy,
                },
                badge: stageStatutLabel(s.statut),
              ),
        ],
      );
}

class _Transferts extends StatelessWidget {
  const _Transferts({required this.transferts});
  final List<TransfertLigne> transferts;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Transferts',
        icone: Icons.swap_horiz_rounded,
        couleur: kRed,
        compte: transferts.length,
        action: FicheRenvoi(
          label: 'Module Transferts',
          onTap: () => context.push(Routes.transferts),
        ),
        enfants: [
          if (transferts.isEmpty)
            const FicheVide(
              "Aucun transfert vers un autre établissement n'a été demandé "
              'pour cet élève.',
            )
          else
            for (final t in transferts)
              FicheChrono(
                date: _dt(t.date),
                titre: t.destination.isEmpty
                    ? 'Établissement non précisé'
                    : t.destination,
                detail: [
                  if (t.anneeLabel.isNotEmpty) 'Année ${t.anneeLabel}',
                  if (t.motif.isNotEmpty) 'Motif : ${t.motif}',
                  if (t.approuveLe != null)
                    'Approuvé le ${_dt(t.approuveLe)}',
                ].join('\n'),
                couleur: t.statut == 'completed' ? kRed : kAccent,
                badge: transfertStatutLabel(t.statut),
              ),
        ],
      );
}
