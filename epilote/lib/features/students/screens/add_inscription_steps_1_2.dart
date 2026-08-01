part of 'add_inscription_screen.dart';

// ─── Étape 1 — Élève ─────────────────────────────────────────────────────────

class _Step1Eleve extends ConsumerStatefulWidget {
  const _Step1Eleve({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Step1Eleve> createState() => _Step1EleveState();
}

class _Step1EleveState extends ConsumerState<_Step1Eleve> {
  late final _firstNameCtrl       = TextEditingController(text: widget.state.firstName);
  late final _lastNameCtrl        = TextEditingController(text: widget.state.lastName);
  late final _placeOfBirthCtrl    = TextEditingController(text: widget.state.placeOfBirth ?? '');
  late final _nationalityCtrl     = TextEditingController(text: widget.state.nationality);
  late final _addressCtrl         = TextEditingController(text: widget.state.address ?? '');
  late final _cityCtrl            = TextEditingController(text: widget.state.city ?? '');
  late final _regionCtrl          = TextEditingController(text: widget.state.region ?? '');
  late final _allergiesCtrl       = TextEditingController(text: widget.state.allergies ?? '');
  late final _scholarshipTypeCtrl = TextEditingController(text: widget.state.scholarshipType ?? '');
  late final _socialAidTypeCtrl   = TextEditingController(text: widget.state.socialAidType ?? '');
  late final _siblingsCtrl        = TextEditingController(
      text: widget.state.nombreFreresSoeurs > 0 ? '${widget.state.nombreFreresSoeurs}' : '');

  static const _bloodGroups = {
    'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-',
    'AB+': 'AB+', 'AB-': 'AB-', 'O+': 'O+', 'O-': 'O-',
  };

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _allergiesCtrl.dispose();
    _scholarshipTypeCtrl.dispose();
    _socialAidTypeCtrl.dispose();
    _siblingsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    // Élève déjà reconnu : on ne redemande pas son identité, on la rappelle.
    if (s.reusesExistingStudent) {
      return _ReinscriptionPanel(
        name: s.existingStudentName ?? '',
        onCancel: () {
          setState(() {
            s.existingStudentId = null;
            s.existingStudentName = null;
          });
          widget.onChanged();
        },
      );
    }

    // Rapprochement avec les élèves déjà présents. Se met à jour pendant la
    // frappe, en local : c'est la question qu'un guichet d'admissions pose en
    // premier, et que ce formulaire ne posait pas du tout.
    final matches = ref
            .watch(studentMatchesProvider((
              firstName: s.firstName,
              lastName: s.lastName,
              dob: s.dateOfBirth,
            )))
            .valueOrNull ??
        const <StudentMatch>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle('Identité'),
          FormTextField(
            controller: _firstNameCtrl,
            label: 'Prénom *',
            onChanged: (v) { s.firstName = v; widget.onChanged(); },
          ),
          FormTextField(
            controller: _lastNameCtrl,
            label: 'Nom *',
            onChanged: (v) { s.lastName = v; widget.onChanged(); },
          ),
          Row(
            children: [
              Expanded(
                child: FormDropdown<String>(
                  label: 'Genre',
                  value: s.gender,
                  items: const {'M': 'Masculin', 'F': 'Féminin'},
                  onChanged: (v) { s.gender = v!; widget.onChanged(); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormDateField(
                  label: 'Date de naissance *',
                  value: s.dateOfBirth,
                  onChanged: (v) { s.dateOfBirth = v; widget.onChanged(); },
                ),
              ),
            ],
          ),
          if (matches.isNotEmpty) ...[
            _MatchWarning(
              matches: matches,
              onReuse: (m) {
                setState(() {
                  s.existingStudentId = m.id;
                  s.existingStudentName = m.fullName;
                  s.inscriptionType = 'reinscription';
                });
                widget.onChanged();
              },
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: FormTextField(
                  controller: _placeOfBirthCtrl,
                  label: 'Lieu de naissance',
                  onChanged: (v) { s.placeOfBirth = v.isEmpty ? null : v; widget.onChanged(); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormTextField(
                  controller: _nationalityCtrl,
                  label: 'Nationalité',
                  onChanged: (v) { s.nationality = v.isEmpty ? 'Congolaise' : v; widget.onChanged(); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FormSectionTitle('Situation familiale'),
          FormDropdown<String>(
            label: 'Situation familiale',
            value: s.situationFamiliale,
            items: const {
              'biparentale':        'Biparentale',
              'monoparentale_pere': 'Monoparentale (père)',
              'monoparentale_mere': 'Monoparentale (mère)',
              'orphelin_partiel':   'Orphelin partiel',
              'orphelin_total':     'Orphelin total',
              'tuteur':             'Sous tutelle',
            },
            onChanged: (v) { s.situationFamiliale = v; widget.onChanged(); },
          ),
          FormTextField(
            controller: _siblingsCtrl,
            label: 'Nombre de frères et sœurs',
            keyboardType: TextInputType.number,
            onChanged: (v) {
              s.nombreFreresSoeurs = int.tryParse(v.trim()) ?? 0;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 16),
          const FormSectionTitle('Statuts particuliers'),
          FormCheckTile(
            label: 'Pensionnaire / Interne',
            value: s.isBoarder,
            onChanged: (v) { s.isBoarder = v; widget.onChanged(); },
          ),
          FormCheckTile(
            label: 'Affecté par le MEPSA/METP',
            value: s.isAffecte,
            onChanged: (v) { s.isAffecte = v; widget.onChanged(); },
          ),
          FormCheckTile(
            label: 'Bénéficie d\'une bourse',
            value: s.hasScholarship,
            onChanged: (v) { s.hasScholarship = v; widget.onChanged(); },
          ),
          if (s.hasScholarship)
            FormTextField(
              label: 'Type de bourse',
              controller: _scholarshipTypeCtrl,
              onChanged: (v) { s.scholarshipType = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          FormCheckTile(
            label: 'Bénéficie d\'une aide sociale',
            value: s.hasSocialAid,
            onChanged: (v) { s.hasSocialAid = v; widget.onChanged(); },
          ),
          if (s.hasSocialAid)
            FormTextField(
              controller: _socialAidTypeCtrl,
              label: 'Type d\'aide sociale',
              onChanged: (v) { s.socialAidType = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          const SizedBox(height: 16),
          const FormSectionTitle('Santé & Adresse'),
          FormDropdown<String>(
            label: 'Groupe sanguin',
            value: s.bloodGroup,
            items: _bloodGroups,
            onChanged: (v) { s.bloodGroup = v; widget.onChanged(); },
          ),
          FormTextField(
            controller: _allergiesCtrl,
            label: 'Allergies / Antécédents médicaux',
            onChanged: (v) { s.allergies = v.isEmpty ? null : v; widget.onChanged(); },
            maxLines: 2,
          ),
          FormTextField(
            controller: _addressCtrl,
            label: 'Adresse',
            onChanged: (v) { s.address = v.isEmpty ? null : v; widget.onChanged(); },
          ),
          Row(
            children: [
              Expanded(
                child: FormTextField(
                  controller: _cityCtrl,
                  label: 'Ville',
                  onChanged: (v) { s.city = v.isEmpty ? null : v; widget.onChanged(); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormTextField(
                  controller: _regionCtrl,
                  label: 'Département / Région',
                  onChanged: (v) { s.region = v.isEmpty ? null : v; widget.onChanged(); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Rapprochement : « cet enfant est-il déjà chez nous ? » ──────────────────

/// Avertissement affiché dès qu'un élève de l'école ressemble à l'identité
/// saisie. Il ne décide rien : le secrétariat tranche.
class _MatchWarning extends StatelessWidget {
  const _MatchWarning({required this.matches, required this.onReuse});
  final List<StudentMatch> matches;
  final ValueChanged<StudentMatch> onReuse;

  @override
  Widget build(BuildContext context) {
    final certain = matches.any((m) => m.sameBirthDate);
    final color = certain ? _kRed : kAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_search_rounded, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              matches.length == 1
                  ? 'Un élève de ce nom est déjà inscrit dans l\'école'
                  : '${matches.length} élèves de ce nom sont déjà dans l\'école',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Créer une seconde fiche donnerait au même enfant deux matricules et '
          'deux dossiers, et couperait sa scolarité en deux. S\'il s\'agit du '
          'même élève, réinscrivez sa fiche existante.',
          style: TextStyle(fontSize: 12.5, color: _kMuted, height: 1.45),
        ),
        const SizedBox(height: 10),
        for (final m in matches) _MatchRow(match: m, onReuse: onReuse),
      ]),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.onReuse});
  final StudentMatch match;
  final ValueChanged<StudentMatch> onReuse;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final details = [
      if (m.matricule.isNotEmpty) m.matricule,
      if (m.dateOfBirth != null && m.dateOfBirth!.isNotEmpty)
        'né(e) le ${m.dateOfBirth}',
      if (m.className != null) 'inscrit(e) en ${m.className}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(m.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kText)),
              ),
              if (m.sameBirthDate) ...[
                const SizedBox(width: 8),
                AdminBadge('Même date de naissance', color: _kRed),
              ],
            ]),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(details,
                  maxLines: 2,
                  style: TextStyle(fontSize: 11.5, color: _kMuted)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        // Déjà inscrit cette année : la contrainte d'unicité interdit une
        // seconde inscription, on le dit au lieu de laisser le serveur la
        // refuser après coup (et emporter tout le lot avec elle).
        if (m.enrolledThisYear)
          Text(
            switch (m.enrollmentStatus) {
              'pending_validation' => 'Dossier déjà\nen attente',
              'rejected' => 'Dossier rejeté\ncette année',
              'withdrawn' => 'Sorti(e)\ncette année',
              'transferred' => 'Transféré(e)\ncette année',
              _ => 'Déjà inscrit\ncette année',
            },
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 11.5, color: _kMuted, fontStyle: FontStyle.italic),
          )
        else
          OutlinedButton(
            onPressed: () => onReuse(m),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kNavy,
              side: BorderSide(color: _kNavy.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: const Text('C\'est lui — réinscrire',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

/// Étape 1 quand un élève existant a été retenu : plus de saisie d'identité.
class _ReinscriptionPanel extends StatelessWidget {
  const _ReinscriptionPanel({required this.name, required this.onCancel});
  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FormSectionTitle('Réinscription'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGreen.withValues(alpha: 0.32)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.how_to_reg_rounded, size: 19, color: _kGreen),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kText)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Sa fiche, ses tuteurs et son dossier de pièces sont '
                    'conservés : rien n\'est ressaisi, rien n\'est dupliqué. '
                    'Il ne reste qu\'à choisir sa classe.',
                    style: TextStyle(
                        fontSize: 12.5, color: _kMuted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    style: TextButton.styleFrom(foregroundColor: _kNavy),
                    label: const Text(
                        'Ce n\'est pas lui — créer un nouvel élève',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
          ),
        ]),
      );
}

// ─── Étape 2 — Parents / Tuteurs ─────────────────────────────────────────────

class _Step2Parents extends StatefulWidget {
  const _Step2Parents({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step2Parents> createState() => _Step2ParentsState();
}

class _Step2ParentsState extends State<_Step2Parents> {
  @override
  Widget build(BuildContext context) {
    // Réinscription d'un élève connu : ses tuteurs sont déjà en base. Les
    // resaisir en créerait des doubles ; les redemander ferait croire qu'ils
    // ont été perdus.
    if (widget.state.reusesExistingStudent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.family_restroom, size: 34, color: _kMuted),
            const SizedBox(height: 12),
            Text(
              'Les parents et tuteurs de ${widget.state.existingStudentName ?? 'cet élève'} '
              'sont déjà enregistrés.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _kText),
            ),
            const SizedBox(height: 6),
            Text(
              'Pour les corriger, ouvrez sa fiche depuis la page Élèves ou '
              'l\'Annuaire des familles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _kMuted, height: 1.45),
            ),
          ]),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.state.tutors.asMap().entries.map((e) => _TutorForm(
            index: e.key,
            tutor: e.value,
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
            onRemove: e.key > 0
                ? () {
                    setState(() => widget.state.tutors.removeAt(e.key));
                    widget.onChanged();
                  }
                : null,
          )),
          const SizedBox(height: 8),
          if (widget.state.tutors.length < 3)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un tuteur / contact'),
              style: TextButton.styleFrom(foregroundColor: _kNavy),
              onPressed: () {
                setState(() => widget.state.tutors.add(_TutorEntry()));
                widget.onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _TutorForm extends StatefulWidget {
  const _TutorForm({
    required this.index,
    required this.tutor,
    required this.onChanged,
    this.onRemove,
  });
  final int          index;
  final _TutorEntry  tutor;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_TutorForm> createState() => _TutorFormState();
}

class _TutorFormState extends State<_TutorForm> {
  late final _firstNameCtrl = TextEditingController(text: widget.tutor.firstName);
  late final _lastNameCtrl  = TextEditingController(text: widget.tutor.lastName);
  late final _phoneCtrl     = TextEditingController(text: widget.tutor.phonePrimary);
  late final _emailCtrl     = TextEditingController(text: widget.tutor.email ?? '');
  late final _profCtrl      = TextEditingController(text: widget.tutor.profession ?? '');
  late final _addressCtrl   = TextEditingController(text: widget.tutor.address ?? '');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _profCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t     = widget.tutor;
    final title = t.isPrimary
        ? 'Parent / tuteur principal'
        : 'Contact ${widget.index + 1}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: t.isPrimary ? _kNavy.withValues(alpha: 0.3) : _kBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kNavy,
                  ),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _kRed, size: 18),
                    onPressed: widget.onRemove,
                    tooltip: 'Supprimer',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FormTextField(
                    controller: _firstNameCtrl,
                    label: 'Prénom *',
                    onChanged: (v) { t.firstName = v; widget.onChanged(); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormTextField(
                    controller: _lastNameCtrl,
                    label: 'Nom *',
                    onChanged: (v) { t.lastName = v; widget.onChanged(); },
                  ),
                ),
              ],
            ),
            FormDropdown<String>(
              label: 'Lien de parenté',
              value: t.relationship,
              items: const {
                'pere':   'Père',
                'mere':   'Mère',
                'tuteur': 'Tuteur légal',
                'autre':  'Autre',
              },
              onChanged: (v) { t.relationship = v!; widget.onChanged(); },
            ),
            FormTextField(
              controller: _phoneCtrl,
              label: 'Téléphone *',
              keyboardType: TextInputType.phone,
              onChanged: (v) { t.phonePrimary = v; widget.onChanged(); },
            ),
            FormTextField(
              controller: _emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) { t.email = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            FormTextField(
              controller: _profCtrl,
              label: 'Profession',
              onChanged: (v) { t.profession = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            FormTextField(
              controller: _addressCtrl,
              label: 'Adresse',
              onChanged: (v) { t.address = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            FormCheckTile(
              label: 'Contact d\'urgence',
              value: t.isEmergency,
              onChanged: (v) { setState(() => t.isEmergency = v); widget.onChanged(); },
            ),
            if (!t.isPrimary)
              FormCheckTile(
                label: 'Contact principal',
                value: t.isPrimary,
                onChanged: (v) { setState(() => t.isPrimary = v); widget.onChanged(); },
              ),
          ],
        ),
      ),
    );
  }
}
