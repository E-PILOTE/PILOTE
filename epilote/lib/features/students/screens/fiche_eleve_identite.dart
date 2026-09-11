part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  IDENTITÉ & FAMILLE — le seul onglet que la fiche MODIFIE elle-même
//
//  État civil, situation familiale, santé, statuts particuliers, responsables
//  légaux, pièces déposées. C'est la matière dont la fiche est propriétaire :
//  elle ne dépend d'aucune règle de clôture, d'aucun reçu, d'aucun conseil.
//  Le bouton « Modifier » ouvre donc ici l'assistant qui porte les gardes
//  d'écriture — et pas un second formulaire écrit pour l'occasion.
// ════════════════════════════════════════════════════════════════════════════

class FicheIdentite extends ConsumerWidget {
  const FicheIdentite({
    super.key,
    required this.studentId,
    required this.dossier,
  });

  final String studentId;
  final StudentDossier dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(studentDocumentsProvider(studentId)).valueOrNull ??
        const <StudentDocument>[];
    final readOnly = ref.watch(yearReadOnlyProvider);
    final peutModifier = !readOnly &&
        ref.watch(canProvider((slug: _kSlugFiche, action: 'update')));

    final modifier = peutModifier
        ? FicheRenvoi(
            label: 'Modifier',
            onTap: () => showStudentEditModal(
              context,
              studentId: studentId,
              fullName: dossier.nomComplet,
            ),
          )
        : null;

    return Column(children: [
      FicheSection(
        titre: 'État civil',
        icone: Icons.badge_outlined,
        action: modifier,
        enfants: [
          FicheLigne(label: 'Nom', valeur: dossier.s('last_name'), gras: true),
          FicheLigne(label: 'Prénom(s)', valeur: dossier.s('first_name')),
          FicheLigne(
            label: 'Sexe',
            valeur: switch (dossier.s('gender')) {
              'F' => 'Féminin',
              'M' => 'Masculin',
              _ => '',
            },
          ),
          FicheLigne(
            label: 'Date de naissance',
            valeur: dossier.dob == null
                ? ''
                : '${_dtLong(dossier.dob)}'
                    '${dossier.age != null ? '  ·  ${dossier.age} ans' : ''}',
          ),
          FicheLigne(
            label: 'Lieu de naissance',
            valeur: dossier.s('place_of_birth'),
          ),
          FicheLigne(label: 'Nationalité', valeur: dossier.s('nationality')),
          FicheLigne(
            label: 'Matricule (école)',
            valeur: dossier.s('matricule'),
            gras: true,
          ),
          // ⚠️ Les deux identifiants, et dans cet ordre. Le matricule est le
          // numéro que le secrétariat manipule tous les jours ; l'INE est
          // celui qui suivra l'enfant s'il change d'établissement.
          FicheLigne(
            label: 'Identifiant national (INE)',
            valeur: dossier.s('ine').isEmpty
                ? kIneEnAttente
                : formatIne(dossier.s('ine')),
          ),
        ],
      ),
      FicheSection(
        titre: 'Situation familiale et domicile',
        icone: Icons.home_outlined,
        action: modifier,
        enfants: [
          // Le CODE BRUT s'affichait autrefois ici : le secrétariat lisait
          // « monoparentale_pere » à l'endroit même où il vérifie une
          // situation avant d'appeler une famille.
          FicheLigne(
            label: 'Situation familiale',
            valeur: situationFamilialeLabel(dossier.s('situation_familiale')),
          ),
          FicheLigne(
            label: 'Frères et sœurs',
            valeur: _fratrie(dossier.student['nombre_freres_soeurs']),
          ),
          FicheLigne(label: 'Adresse', valeur: dossier.s('address')),
          FicheLigne(label: 'Ville', valeur: dossier.s('city')),
          FicheLigne(label: 'Département', valeur: dossier.s('region')),
        ],
      ),
      FicheSection(
        titre: 'Santé',
        icone: Icons.medical_information_outlined,
        couleur: kRed,
        action: modifier,
        // ⚠️ La mention n'est pas un ornement : elle rappelle à l'agent, au
        // moment où il regarde ces lignes, qu'elles ne suivent pas sur un
        // papier remis à un tiers. C'est la même règle que le choix de portée
        // à l'impression.
        note: 'Donnée interne — ne figure pas sur la fiche administrative',
        enfants: [
          FicheLigne(label: 'Groupe sanguin', valeur: dossier.s('blood_group')),
          FicheLigne(
            label: 'Allergies et antécédents',
            valeur: dossier.s('allergies'),
          ),
        ],
      ),
      _Statuts(dossier: dossier, action: modifier),
      _Tuteurs(dossier: dossier, action: modifier),
      _Pieces(docs: docs),
    ]);
  }

  static String _fratrie(Object? v) {
    if (v is! num) return '';
    final n = v.toInt();
    if (n <= 0) return 'Aucun';
    return '$n';
  }
}

/// Ce qui donne des droits ou impose des obligations particulières.
///
/// ⚠️ Un statut FAUX se lit comme un statut absent : « Boursier » non coché sur
/// un enfant qui l'est fait réclamer le plein tarif à sa famille. On liste
/// donc les quatre lignes TOUJOURS, cochées ou non, plutôt que de n'afficher
/// que celles qui sont vraies — l'agent voit alors ce qui a été renseigné, et
/// non seulement ce qui a été coché.
class _Statuts extends StatelessWidget {
  const _Statuts({required this.dossier, required this.action});

  final StudentDossier dossier;
  final Widget? action;

  bool _b(String k) => dossier.student[k] == 1 || dossier.student[k] == true;

  String _oui(bool v, [String precision = '']) => v
      ? (precision.isEmpty ? 'Oui' : 'Oui — $precision')
      : 'Non';

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Statuts particuliers',
        icone: Icons.verified_outlined,
        couleur: kGreen,
        action: action,
        enfants: [
          FicheLigne(label: 'Interne', valeur: _oui(_b('is_boarder'))),
          FicheLigne(
            label: 'Affecté MEPSA / METP',
            valeur: _oui(_b('is_affecte')),
          ),
          FicheLigne(
            label: 'Boursier',
            valeur: _oui(
              _b('has_scholarship'),
              dossier.s('scholarship_type'),
            ),
          ),
          FicheLigne(
            label: 'Aide sociale',
            valeur: _oui(_b('has_social_aid'), dossier.s('social_aid_type')),
          ),
        ],
      );
}

class _Tuteurs extends StatelessWidget {
  const _Tuteurs({required this.dossier, required this.action});

  final StudentDossier dossier;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = dossier.tutors;
    final sansPrincipal = t.isNotEmpty && !t.any((x) => x.isPrimary);

    return FicheSection(
      titre: 'Responsables légaux',
      icone: Icons.family_restroom_outlined,
      compte: t.length,
      action: action,
      enfants: [
        if (t.isEmpty)
          const FicheVide(
            'Aucun responsable enregistré — dans une école où le tuteur est le '
            'seul canal joignable, ce dossier ne permet de prévenir personne.',
          ),
        // ⚠️ RÉSIDU D'UN DÉFAUT CORRIGÉ EN AMONT. La case « contact principal »
        // s'est longtemps décochée librement : des dossiers portent donc
        // plusieurs principaux, ou aucun. Le sélecteur du guichet fait alors
        // `LIMIT 1` et ne rend rien — l'école a des numéros, mais aucun ne se
        // présente comme celui qu'on compose. Rien ne le disait.
        if (sansPrincipal)
          const FicheLigne(
            label: 'Contact principal',
            valeur: 'Aucun désigné — ouvrez « Modifier » pour en choisir un',
            alerte: true,
          ),
        for (final x in t) _CarteTuteur(tuteur: x),
      ],
    );
  }
}

class _CarteTuteur extends StatelessWidget {
  const _CarteTuteur({required this.tuteur});
  final StudentTutorInfo tuteur;

  @override
  Widget build(BuildContext context) {
    final tel = [
      if ((tuteur.phonePrimary ?? '').trim().isNotEmpty) tuteur.phonePrimary!,
      if ((tuteur.phoneSecondary ?? '').trim().isNotEmpty)
        tuteur.phoneSecondary!,
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: SelectableText(
              tuteur.fullName.isEmpty ? 'Sans nom' : tuteur.fullName,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
          ),
          if (tuteur.isPrimary) AdminBadge('Contact principal', color: kGreen),
          if (tuteur.isEmergency) ...[
            const SizedBox(width: 6),
            AdminBadge('Urgence', color: kRed),
          ],
        ]),
        const SizedBox(height: 6),
        FicheLigne(
          label: 'Lien de parenté',
          valeur: tutorRelationshipLabel(tuteur.relationship),
        ),
        FicheLigne(label: 'Téléphone', valeur: tel),
        FicheLigne(label: 'Courriel', valeur: tuteur.email ?? ''),
        FicheLigne(label: 'Profession', valeur: tuteur.profession ?? ''),
        FicheLigne(label: 'Adresse', valeur: tuteur.address ?? ''),
      ]),
    );
  }
}

/// Les pièces que la FAMILLE a déposées.
///
/// ⚠️ À ne pas confondre avec les actes que l'école DÉLIVRE, qui vivent dans
/// l'onglet « Actes & pièces ». Les deux tables portent une colonne
/// `document_type` et se ressemblent ; les mélanger ferait dire à la fiche
/// qu'un dossier est complet parce que l'école a imprimé une carte scolaire.
class _Pieces extends StatelessWidget {
  const _Pieces({required this.docs});
  final List<StudentDocument> docs;

  @override
  Widget build(BuildContext context) {
    final presentes = docs.map((d) => d.documentType).toSet();
    final manquantes = kRequiredDocTypes.difference(presentes);

    return FicheSection(
      titre: 'Pièces du dossier',
      icone: Icons.attach_file_rounded,
      compte: docs.length,
      note: manquantes.isEmpty && docs.isNotEmpty
          ? 'Toutes les pièces exigées sont déposées'
          : null,
      enfants: [
        if (docs.isEmpty)
          const FicheVide('Aucune pièce déposée au dossier.')
        else
          for (final d in docs)
            FicheLigne(
              label: docTypeLabel(d.documentType),
              valeur: d.isVerified ? 'Vérifiée' : 'Déposée, à vérifier',
            ),
        if (manquantes.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final m in manquantes)
            FicheLigne(
              label: docTypeLabel(m),
              valeur: 'Manquante',
              alerte: true,
            ),
        ],
      ],
    );
  }
}
