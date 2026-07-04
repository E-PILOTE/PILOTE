part of 'add_inscription_screen.dart';

// ─── Étape 1 — Élève ─────────────────────────────────────────────────────────

class _Step1Eleve extends StatefulWidget {
  const _Step1Eleve({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step1Eleve> createState() => _Step1EleveState();
}

class _Step1EleveState extends State<_Step1Eleve> {
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kNavy,
                  ),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _kRed, size: 18),
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
