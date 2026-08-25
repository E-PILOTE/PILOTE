part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TIROIR DÉTAIL ÉLÈVE (slide droit) — CE QU'ON LIT : identité, statuts,
//  inscription de l'année, tuteurs, pièces du dossier.
//
//  CE QU'ON FAIT depuis ce tiroir — modifier, changer de classe, transférer,
//  radier, délivrer un certificat — vit dans `eleves_actions_parts.dart`.
// ════════════════════════════════════════════════════════════════════════════
class _StudentDrawer extends ConsumerWidget {
  const _StudentDrawer({required this.row});
  final StudentRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossier = ref.watch(studentDossierProvider(row.id));
    final docs = ref.watch(studentDocumentsProvider(row.id)).valueOrNull ??
        const <StudentDocument>[];
    final readOnly = ref.watch(yearReadOnlyProvider);
    final w = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: w < 520 ? w : 460,
        height: double.infinity,
        decoration: BoxDecoration(color: kCardBg),
        child: SafeArea(
          child: Column(children: [
            _DwHeader(row: row),
            Expanded(
              child: dossier.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(messageErreur(e),
                      style: TextStyle(color: kRed)),
                ),
                data: (d) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: _DwBody(row: row, d: d, docs: docs),
                ),
              ),
            ),
            // ⚠️ LA BARRE ENTIÈRE DISPARAISSAIT SUR UNE ANNÉE CLÔTURÉE, et
            // elle porte le certificat de scolarité. Or `yearReadOnlyProvider`
            // est vrai dès qu'on consulte une année passée — et c'est
            // précisément pour une année passée qu'on réclame ce papier : un
            // ancien élève monte un dossier de bourse, de visa, d'équivalence.
            // Imprimer n'est pas écrire. La barre reste, réduite à ce qui se lit.
            _DwActionBar(row: row, readOnly: readOnly),
          ]),
        ),
      ),
    );
  }
}

class _DwHeader extends StatelessWidget {
  const _DwHeader({required this.row});
  final StudentRow row;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Icon(Icons.close_rounded, color: kTextMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Row(children: [
          _Avatar(name: row.fullName, photoUrl: row.photoUrl, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AdminBadge('Inscrit', color: kGreen),
                if (row.className != null)
                  AdminBadge(row.className!, color: _cycColor(row.cycleCode)),
                if (row.matricule.isNotEmpty)
                  AdminBadge(row.matricule, color: kTextMuted),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _DwBody extends StatelessWidget {
  const _DwBody({required this.row, required this.d, required this.docs});
  final StudentRow row;
  final StudentDossier d;
  final List<StudentDocument> docs;

  bool _b(Object? v) => v == 1 || v == true;

  @override
  Widget build(BuildContext context) {
    final dob = d.dob;
    final age = row.age;
    final naissance = dob == null
        ? '—'
        : '${dob.toIso8601String().substring(0, 10)}${age != null ? '  ($age ans)' : ''}';
    final adresse = [d.s('address'), d.s('city'), d.s('region')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final siblings = d.student['nombre_freres_soeurs'];
    final siblingsLabel = (siblings is int && siblings > 0) ? '$siblings' : '';
    final statuts = <(String, String)>[
      if (_b(d.student['is_boarder'])) ('Interne', '✓'),
      if (_b(d.student['is_affecte'])) ('Affecté MEPSA/METP', '✓'),
      if (_b(d.student['has_scholarship']))
        ('Boursier', d.s('scholarship_type').isEmpty ? '✓' : d.s('scholarship_type')),
      if (_b(d.student['has_social_aid']))
        ('Aide sociale', d.s('social_aid_type').isEmpty ? '✓' : d.s('social_aid_type')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      ResumeCard(
        title: 'Inscription (année active)',
        icon: Icons.how_to_reg_outlined,
        rows: [
          ('Statut', 'Inscrit (validé)'),
          ('Classe', row.className ?? '—'),
          ('Cycle', _cycName(row.cycleCode)),
          if ((row.levelCode ?? '').isNotEmpty) ('Niveau', row.levelCode!),
          if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
        ],
      ),
      ResumeCard(
        title: 'Identité',
        icon: Icons.person_outline,
        rows: [
          // Les deux, et dans cet ordre. Le matricule est le numéro de
          // l'école, celui que le secrétariat manipule tous les jours ; l'INE
          // est celui qui suivra l'enfant s'il change d'établissement. Les
          // confondre, c'est reperdre ce que l'INE apporte.
          ('Matricule (école)', row.matricule.isEmpty ? '—' : row.matricule),
          (
            'Identifiant national',
            row.ine == null ? kIneEnAttente : formatIne(row.ine)
          ),
          (
            'Sexe',
            row.gender == 'F'
                ? 'Féminin'
                : row.gender == 'M'
                    ? 'Masculin'
                    : '—'
          ),
          ('Naissance', naissance),
          ('Lieu de naissance', _od(d.s('place_of_birth'))),
          ('Nationalité', _od(d.s('nationality'))),
          // ⚠️ LE CODE BRUT S'AFFICHAIT ICI. Le secrétariat lisait
          // « monoparentale_pere » dans le dossier d'un élève, à l'endroit
          // même où il vérifie sa situation avant d'appeler la famille. C'est
          // exactement le défaut qui avait donné naissance à
          // `models/eleve_libelles.dart` — corrigé côté guichet, resté ici.
          (
            'Situation familiale',
            situationFamilialeLabel(d.s('situation_familiale'))
          ),
          if (siblingsLabel.isNotEmpty) ('Frères et sœurs', siblingsLabel),
          ('Groupe sanguin', _od(d.s('blood_group'))),
          if (d.s('allergies').isNotEmpty) ('Antécédents', d.s('allergies')),
          ('Adresse', _od(adresse)),
        ],
      ),
      if (statuts.isNotEmpty)
        ResumeCard(
            title: 'Statuts particuliers',
            icon: Icons.verified_outlined,
            rows: statuts),
      ResumeCard(
        title: 'Tuteurs (${d.tutors.length})',
        icon: Icons.family_restroom_outlined,
        rows: d.tutors.isEmpty
            ? [('Aucun tuteur enregistré', '')]
            : [
                for (final t in d.tutors)
                  (
                    t.isPrimary ? 'Principal' : _rel(t.relationship),
                    [
                      t.fullName,
                      if ((t.phonePrimary ?? '').trim().isNotEmpty)
                        '· ${t.phonePrimary}',
                    ].join(' '),
                  ),
                // ⚠️ LE RÉSIDU D'UN DÉFAUT CORRIGÉ EN AMONT. La case « contact
                // principal » se décochait librement : des dossiers portent
                // donc déjà plusieurs principaux, ou aucun. `primaryTutorProvider`
                // fait `LIMIT 1` et n'a alors rien à rendre — l'école a des
                // numéros, mais plus aucun ne se présente comme celui qu'on
                // compose. Rien ne le disait ; le dossier avait l'air complet.
                if (!d.tutors.any((t) => t.isPrimary))
                  ('⚠ Aucun contact principal',
                      'Ouvrez « Modifier » pour en désigner un'),
              ],
      ),
      ResumeCard(
        title: 'Dossier (${docs.length} pièce${docs.length > 1 ? 's' : ''})',
        icon: Icons.folder_open_rounded,
        rows: docs.isEmpty
            ? [('Aucune pièce téléversée', '')]
            : [
                for (final doc in docs)
                  (
                    docTypeLabel(doc.documentType),
                    doc.isVerified ? '✓ vérifiée' : 'à vérifier'
                  ),
              ],
      ),
    ]);
  }

  static String _od(String v) => v.isEmpty ? '—' : v;
  static String _rel(String c) => tutorRelationshipLabel(c);
}
