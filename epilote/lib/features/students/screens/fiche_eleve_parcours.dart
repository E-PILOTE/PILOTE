part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PARCOURS — la suite des années, et ce qui s'est décidé à chacune
//
//  ── CE QUE CETTE PAGE RÉPOND, ET QUE RIEN D'AUTRE NE RÉPONDAIT ─────────────
//  « Cet enfant a-t-il déjà redoublé ? » · « D'où vient-il ? » · « Pourquoi
//  a-t-il quitté l'école en mars ? » Trois questions d'instruction de dossier,
//  toutes inscrites dans `class_enrollments`, aucune lisible nulle part avant
//  cette page : le tiroir de la liste ne montre que l'année en cours.
//
//  ── L'ORDRE EST DÉCROISSANT, ET C'EST UN CHOIX ─────────────────────────────
//  Une chronologie se lit du plus ancien au plus récent ; un dossier
//  s'instruit à partir de MAINTENANT. On met donc l'année en cours en tête —
//  c'est ce que l'agent regarde en premier neuf fois sur dix, et il n'a pas à
//  dérouler une scolarité entière pour y arriver.
//
//  ── EN LECTURE SEULE, DÉLIBÉRÉMENT ─────────────────────────────────────────
//  ⚠️ Une inscription se corrige au GUICHET (`inscriptions_edit.dart`), qui
//  connaît les capacités de classe, les frais et la validation. La modifier
//  ici contournerait tout cela — la fiche renvoie donc au guichet.
// ════════════════════════════════════════════════════════════════════════════

class FicheParcours extends ConsumerWidget {
  const FicheParcours({
    super.key,
    required this.studentId,
    required this.parcours,
  });

  final String studentId;
  final List<ParcoursAnnee> parcours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parcours.isEmpty) {
      return const FicheSection(
        titre: 'Parcours scolaire',
        icone: Icons.timeline_rounded,
        enfants: [
          FicheVide(
            'Aucune inscription enregistrée pour cet élève — sa fiche existe, '
            "mais il n'a encore été inscrit dans aucune classe.",
          ),
        ],
      );
    }

    final redoublements = parcours.where((p) => p.redoublant).length;
    final interrompues = parcours.where((p) => p.interrompue).length;

    return Column(children: [
      FicheSection(
        titre: 'Parcours scolaire',
        icone: Icons.timeline_rounded,
        compte: parcours.length,
        action: FicheRenvoi(
          label: 'Guichet des inscriptions',
          onTap: () => context.push(Routes.inscriptions),
        ),
        enfants: [
          FicheStats([
            FicheStat(
              label: parcours.length > 1 ? 'années suivies' : 'année suivie',
              valeur: '${parcours.length}',
            ),
            FicheStat(
              label: redoublements > 1 ? 'redoublements' : 'redoublement',
              valeur: '$redoublements',
              couleur: redoublements > 0 ? kAccent : null,
            ),
            FicheStat(
              label: 'années interrompues',
              valeur: '$interrompues',
              couleur: interrompues > 0 ? kRed : null,
            ),
          ]),
          FicheTableau(
            entetes: const [
              'Année',
              'Classe',
              'Type',
              'Statut',
              'Fin d\'année',
            ],
            largeurs: const [110, 150, 120, 160, 190],
            lignes: [
              for (final p in parcours)
                [
                  p.anneeLabel,
                  [p.classe, if (p.filiere.isNotEmpty) '· ${p.filiere}']
                      .join(' '),
                  inscriptionTypeLabel(p.type),
                  enrollmentStatutLabel(p.statut),
                  verdictPassageLabel(p.verdict),
                ],
            ],
            vide: 'Aucune inscription.',
          ),
        ],
      ),
      for (final p in parcours) _AnneeCarte(annee: p),
    ]);
  }
}

/// Le détail d'une année — ce que le tableau ne peut pas porter.
class _AnneeCarte extends StatelessWidget {
  const _AnneeCarte({required this.annee});
  final ParcoursAnnee annee;

  @override
  Widget build(BuildContext context) {
    final a = annee;
    return FicheSection(
      titre: a.anneeLabel.isEmpty ? 'Année sans libellé' : a.anneeLabel,
      icone: Icons.event_note_outlined,
      couleur: a.interrompue
          ? kRed
          : a.statut == 'active'
              ? kGreen
              : kTextMuted,
      note: [
        if (a.classe.isNotEmpty) a.classe,
        if (a.niveauCode.isNotEmpty) a.niveauCode,
        if (a.filiere.isNotEmpty) a.filiere,
      ].join(' · '),
      enfants: [
        FicheLigne(
          label: 'Statut de l\'inscription',
          valeur: enrollmentStatutLabel(a.statut),
          gras: true,
        ),
        FicheLigne(
          label: 'Type d\'inscription',
          valeur: inscriptionTypeLabel(a.type),
        ),
        FicheLigne(
          label: 'Inscrit le',
          valeur: _dtLong(a.dateInscription),
        ),
        FicheLigne(
          label: 'Redoublant',
          valeur: a.redoublant ? 'Oui' : 'Non',
        ),
        // Les deux colonnes de provenance ne sont remplies que pour un
        // transfert. Les afficher vides sur une réinscription ordinaire
        // laisserait croire à une information perdue.
        if (a.ecolePrecedente.isNotEmpty || a.classePrecedente.isNotEmpty) ...[
          FicheLigne(
            label: 'École précédente',
            valeur: a.ecolePrecedente,
          ),
          FicheLigne(
            label: 'Classe précédente',
            valeur: a.classePrecedente,
          ),
        ],
        if (a.motifTransfert.isNotEmpty)
          FicheLigne(label: 'Motif du transfert', valeur: a.motifTransfert),
        if (a.dateRetrait != null || a.motifRetrait.isNotEmpty) ...[
          FicheLigne(
            label: 'Sortie le',
            valeur: _dtLong(a.dateRetrait),
            alerte: true,
          ),
          FicheLigne(
            label: 'Motif de sortie',
            valeur: a.motifRetrait,
            alerte: a.motifRetrait.isNotEmpty,
          ),
        ],
        if (a.motifRejet.isNotEmpty)
          FicheLigne(
            label: 'Motif du rejet',
            valeur: a.motifRejet,
            alerte: true,
          ),
        if (a.verdict.isNotEmpty)
          FicheLigne(
            label: 'Décision de fin d\'année',
            valeur: [
              verdictPassageLabel(a.verdict),
              if (a.moyenneAnnuelle != null)
                '(moyenne ${_num1(a.moyenneAnnuelle)}/20)',
            ].join(' '),
            gras: true,
          ),
        // L'exonération se lit ICI parce qu'elle est portée par l'inscription
        // de CETTE année : une remise obtenue en cinquième ne suit pas
        // l'enfant en quatrième.
        if ((a.tauxExoneration ?? 0) > 0)
          FicheLigne(
            label: 'Exonération de scolarité',
            valeur: [
              '${a.tauxExoneration} %',
              if (a.motifExoneration.isNotEmpty) '— ${a.motifExoneration}',
            ].join(' '),
          ),
        if (a.notes.isNotEmpty)
          FicheLigne(label: 'Observations', valeur: a.notes),
      ],
    );
  }
}
