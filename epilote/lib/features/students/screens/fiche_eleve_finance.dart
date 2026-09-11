part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FINANCES — ce qui est dû, ce qui a été versé
//
//  ── LE MONTANT DÛ N'EST PAS CALCULÉ ICI ────────────────────────────────────
//  ⚠️ Il vient de `decompteDuProvider`, et de nulle part ailleurs. Ce calcul
//  applique la fenêtre de présence, les frais annexes, l'exonération et le
//  statut de boursier ; il est verrouillé par ses propres tests, et son
//  en-tête dit explicitement que toute version divergente est celle qui a
//  tort. En réécrire une ici donnerait deux chiffres pour la même chose sur la
//  page qu'on ouvre devant une famille.
//
//  ── LES VERSEMENTS ANNULÉS RESTENT VISIBLES ────────────────────────────────
//  ⚠️ Un versement annulé n'est pas un versement effacé. Une famille qui tient
//  un reçu doit retrouver l'opération, avec son annulation et son motif ; le
//  masquer reviendrait à nier une pièce que le parent a en main. Il est donc
//  affiché, marqué, et exclu des seuls totaux.
// ════════════════════════════════════════════════════════════════════════════

class FicheFinance extends ConsumerWidget {
  const FicheFinance({
    super.key,
    required this.studentId,
    required this.parcours,
    required this.annee,
  });

  final String studentId;
  final List<ParcoursAnnee> parcours;
  final AnneeFiche? annee;

  /// L'inscription de l'année affichée — le décompte est porté par elle, et
  /// non par l'élève : une exonération obtenue une année ne suit pas.
  ParcoursAnnee? get _inscription {
    if (parcours.isEmpty) return null;
    final l = annee?.label;
    if (l == null || l.isEmpty) return parcours.first;
    return parcours.where((p) => p.anneeLabel == l).firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insc = _inscription;
    final versements =
        ref.watch(ficheVersementsProvider(studentId)).valueOrNull ??
            const <VersementLigne>[];

    return Column(children: [
      _Decompte(inscription: insc, annee: annee),
      _Journal(versements: versements),
    ]);
  }
}

class _Decompte extends ConsumerWidget {
  const _Decompte({required this.inscription, required this.annee});

  final ParcoursAnnee? inscription;
  final AnneeFiche? annee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ie = inscription?.enrollmentId;
    if (ie == null || ie.isEmpty) {
      return FicheSection(
        titre: 'Ce qui est dû',
        icone: Icons.request_quote_outlined,
        note: annee == null ? null : 'Année ${annee!.label}',
        enfants: const [
          FicheVide(
            "Aucune inscription sur cette année : il n'y a donc rien à devoir. "
            'Le décompte est porté par une inscription, pas par un élève.',
          ),
        ],
      );
    }

    final asyncD = ref.watch(decompteDuProvider(ie));

    return FicheSection(
      titre: 'Ce qui est dû',
      icone: Icons.request_quote_outlined,
      couleur: kNavy,
      note: annee == null ? null : 'Année ${annee!.label}',
      action: FicheRenvoi(
        label: 'Module Paiements',
        onTap: () => context.push(Routes.paiements),
      ),
      enfants: [
        // ⚠️ TROIS ÉTATS, PAS DEUX. Confondre « pas encore lu » et « aucun
        // barème » afficherait « reste dû : 0 » pendant le chargement — et
        // pour toujours en cas d'échec. Le caissier laisserait repartir la
        // famille.
        ...asyncD.when<List<Widget>>(
          loading: () => const [FicheVide('Lecture du décompte…')],
          error: (e, _) => [
            FicheLigne(
              label: 'Décompte indisponible',
              valeur: messageErreur(e),
              alerte: true,
            ),
          ],
          data: (d) => [
            if (d.vide)
              const FicheVide(
                'Aucun barème de frais ne s\'applique à cet élève sur cette '
                "année — l'école n'en a pas posé, ou aucun ne vise son niveau.",
              )
            else ...[
              FicheStats([
                FicheStat(
                  label: 'total au tarif plein',
                  valeur: CurrencyFormatter.format(d.brut),
                ),
                if (d.remise > 0)
                  FicheStat(
                    label: 'remise appliquée',
                    valeur: CurrencyFormatter.format(d.remise),
                    couleur: kGreen,
                  ),
                FicheStat(
                  label: 'net dû',
                  valeur: CurrencyFormatter.format(d.net),
                  couleur: kNavy,
                ),
                FicheStat(
                  label: 'encaissé',
                  valeur: CurrencyFormatter.format(d.verse),
                  couleur: kGreen,
                ),
                FicheStat(
                  label: 'reste dû',
                  valeur: CurrencyFormatter.format(d.reste),
                  couleur: d.reste > 0 ? kRed : kGreen,
                ),
              ]),
              if (d.boursierSansTaux)
                const FicheLigne(
                  label: 'Boursier sans taux',
                  valeur: "L'élève est déclaré boursier mais aucun taux n'a "
                      'été saisi : la scolarité entière reste due.',
                  alerte: true,
                ),
              if (d.estExonere)
                FicheLigne(
                  label: 'Exonération',
                  valeur: [
                    '${d.exoneration} %',
                    if ((d.motifExoneration ?? '').isNotEmpty)
                      '— ${d.motifExoneration}',
                  ].join(' '),
                ),
              FicheTableau(
                entetes: const ['Poste', 'Dû', 'Versé', 'Reste'],
                largeurs: const [240, 130, 130, 130],
                lignes: [
                  for (final l in d.lignes)
                    [
                      l.libelle,
                      CurrencyFormatter.format(d.duDe(l)),
                      CurrencyFormatter.format(l.verse),
                      CurrencyFormatter.format(
                        (d.duDe(l) - l.verse).clamp(0, d.duDe(l)),
                      ),
                    ],
                ],
              ),
              // ⚠️ Ce montant DOIT rester visible. Ce sont les versements que
              // le décompte ne sait plus rattacher — barème retiré, changement
              // de niveau, encaissement « libre ». Les taire ferait
              // réapparaître l'élève débiteur d'une somme qu'il a payée.
              if (d.verseLibre > 0)
                FicheLigne(
                  label: 'Versements non rattachés à un poste',
                  valeur: CurrencyFormatter.format(d.verseLibre),
                ),
              FicheLigne(
                label: 'Mensualités dues',
                valeur: '${d.mois}',
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Journal extends StatelessWidget {
  const _Journal({required this.versements});
  final List<VersementLigne> versements;

  @override
  Widget build(BuildContext context) {
    final comptes = versements.where((v) => v.compte);
    final total = comptes.fold<int>(0, (a, v) => a + v.montant);
    final annules = versements.where((v) => v.annule).length;

    return FicheSection(
      titre: 'Journal des versements',
      icone: Icons.receipt_long_outlined,
      couleur: kGreen,
      compte: versements.length,
      note: versements.isEmpty ? null : 'Toute la scolarité',
      enfants: [
        if (versements.isEmpty)
          const FicheVide(
            'Aucun versement enregistré pour cet élève, sur aucune année.',
          )
        else ...[
          FicheStats([
            FicheStat(
              label: 'total encaissé (confirmé)',
              valeur: CurrencyFormatter.format(total),
              couleur: kGreen,
            ),
            FicheStat(
              label: 'opérations',
              valeur: '${versements.length}',
            ),
            if (annules > 0)
              FicheStat(
                label: annules > 1 ? 'annulées' : 'annulée',
                valeur: '$annules',
                couleur: kRed,
              ),
          ]),
          for (final v in versements)
            FicheChrono(
              date: _dt(v.date),
              titre: [
                CurrencyFormatter.format(v.montant),
                if (v.libelle.isNotEmpty) '· ${v.libelle}',
                if (v.periode.isNotEmpty) '· ${v.periode}',
              ].join(' '),
              detail: [
                [
                  if (v.anneeLabel.isNotEmpty) v.anneeLabel,
                  if (v.methode.isNotEmpty) v.methode,
                  if (v.recu.isNotEmpty) 'Reçu ${v.recu}',
                  if (v.reference.isNotEmpty) 'Réf. ${v.reference}',
                ].join(' · '),
                if (v.annule)
                  'ANNULÉ${v.annuleLe == null ? '' : ' le ${_dt(v.annuleLe)}'}'
                      '${v.motifAnnulation.isEmpty ? '' : ' — ${v.motifAnnulation}'}',
                if (v.rembourse > 0)
                  'Remboursé : ${CurrencyFormatter.format(v.rembourse)}',
                if (v.notes.isNotEmpty) v.notes,
              ].where((s) => s.isNotEmpty).join('\n'),
              couleur: v.annule
                  ? kRed
                  : v.compte
                      ? kGreen
                      : kAccent,
              badge: v.compte ? null : paiementStatutLabel(v.statut),
            ),
        ],
      ],
    );
  }
}
