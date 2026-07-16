part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MODIFICATION ÉLÈVE (personne) — assistant 2 étapes Identité · Tuteurs
//  (la scolarité se gère via Inscriptions). Même habillage que l'inscription.
// ════════════════════════════════════════════════════════════════════════════
class _StudentEditModal extends ConsumerStatefulWidget {
  const _StudentEditModal({required this.studentId, required this.fullName});
  final String studentId, fullName;
  @override
  ConsumerState<_StudentEditModal> createState() => _StudentEditModalState();
}

class _StudentEditModalState extends ConsumerState<_StudentEditModal> {
  final _page = PageController();
  int _step = 0;
  static const _steps = ['Identité', 'Tuteurs'];

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _placeOfBirth = TextEditingController();
  final _nationality = TextEditingController();
  final _siblings = TextEditingController();
  final _scholarshipType = TextEditingController();
  final _socialAidType = TextEditingController();
  final _allergies = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  String _gender = 'M';
  String? _dobIso;
  String? _situation;
  bool _isBoarder = false, _isAffecte = false, _hasScholarship = false,
      _hasSocialAid = false;
  String? _bloodGroup;

  String? _photoUrl;
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  final List<_TutorDraft> _tutors = [];
  final List<String> _removedTutorIds = [];

  bool _primed = false, _saving = false;

  static const _situations = {
    'biparentale': 'Biparentale',
    'monoparentale_pere': 'Monoparentale (père)',
    'monoparentale_mere': 'Monoparentale (mère)',
    'orphelin_partiel': 'Orphelin partiel',
    'orphelin_total': 'Orphelin total',
    'tuteur': 'Sous tutelle',
  };
  static const _bloodGroups = {
    'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-',
    'AB+': 'AB+', 'AB-': 'AB-', 'O+': 'O+', 'O-': 'O-',
  };

  bool _b(Object? v) => v == 1 || v == true;

  @override
  void dispose() {
    _page.dispose();
    for (final c in [
      _firstName, _lastName, _placeOfBirth, _nationality, _siblings,
      _scholarshipType, _socialAidType, _allergies, _address, _city, _region,
    ]) {
      c.dispose();
    }
    for (final t in _tutors) {
      t.dispose();
    }
    super.dispose();
  }

  void _prime(StudentDossier d) {
    _firstName.text = d.s('first_name');
    _lastName.text = d.s('last_name');
    _placeOfBirth.text = d.s('place_of_birth');
    _nationality.text =
        d.s('nationality').isEmpty ? 'Congolaise' : d.s('nationality');
    final sib = d.student['nombre_freres_soeurs'];
    _siblings.text = (sib is int && sib > 0) ? '$sib' : '';
    final g = d.s('gender');
    _gender = (g == 'M' || g == 'F') ? g : 'M';
    _dobIso = d.dob?.toIso8601String().substring(0, 10);
    final sit = d.s('situation_familiale');
    _situation = sit.isEmpty ? null : sit;
    _isBoarder = _b(d.student['is_boarder']);
    _isAffecte = _b(d.student['is_affecte']);
    _hasScholarship = _b(d.student['has_scholarship']);
    _scholarshipType.text = d.s('scholarship_type');
    _hasSocialAid = _b(d.student['has_social_aid']);
    _socialAidType.text = d.s('social_aid_type');
    final bg = d.s('blood_group');
    _bloodGroup = bg.isEmpty ? null : bg;
    _allergies.text = d.s('allergies');
    _address.text = d.s('address');
    _city.text = d.s('city');
    _region.text = d.s('region');
    final pu = d.s('photo_url');
    _photoUrl = pu.isEmpty ? null : pu;
    for (final t in d.tutors) {
      _tutors.add(_TutorDraft.fromInfo(t));
    }
    _primed = true;
  }

  Future<void> _pickPhoto() async {
    final res =
        await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      _photoBytes = f.bytes;
      _photoExt = (f.extension ?? 'jpg').toLowerCase();
    });
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      _page.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _page.previousPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      if (_step != 0) {
        setState(() => _step = 0);
        _page.jumpToPage(0);
      }
      _snack('Le prénom et le nom sont obligatoires.', kRed);
      return;
    }
    setState(() => _saving = true);
    final id = widget.studentId;
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId ?? '';
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        final client = ref.read(supabaseClientProvider);
        photoUrl = await uploadStudentPhoto(
            client: client, studentId: id, bytes: _photoBytes!, ext: _photoExt);
      }
      await updateStudent(
        studentId: id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        dateOfBirth: _dobIso != null ? DateTime.tryParse(_dobIso!) : null,
        placeOfBirth: _placeOfBirth.text.trim(),
        gender: _gender,
        nationality: _nationality.text.trim(),
        situationFamiliale: _situation,
        nombreFreresSoeurs: int.tryParse(_siblings.text.trim()) ?? 0,
        isBoarder: _isBoarder,
        isAffecte: _isAffecte,
        hasScholarship: _hasScholarship,
        scholarshipType: _hasScholarship ? _scholarshipType.text.trim() : '',
        hasSocialAid: _hasSocialAid,
        socialAidType: _hasSocialAid ? _socialAidType.text.trim() : '',
        bloodGroup: _bloodGroup,
        allergies: _allergies.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        region: _region.text.trim(),
        photoUrl: photoUrl,
      );
      for (final tid in _removedTutorIds) {
        await deleteTutor(tid);
      }
      for (final t in _tutors) {
        final fn = t.firstName.text.trim();
        final ln = t.lastName.text.trim();
        final ph = t.phone.text.trim();
        if (fn.isEmpty || ln.isEmpty || ph.isEmpty) continue;
        if (t.id == null) {
          await addTutor(
            studentId: id,
            groupId: groupId,
            firstName: fn,
            lastName: ln,
            relationship: t.relationship,
            phonePrimary: ph,
            email: _nullIfEmpty(t.email.text),
            profession: _nullIfEmpty(t.profession.text),
            address: _nullIfEmpty(t.address.text),
            isPrimaryContact: t.isPrimary,
            isEmergencyContact: t.isEmergency,
          );
        } else {
          await updateTutor(
            tutorId: t.id!,
            firstName: fn,
            lastName: ln,
            relationship: t.relationship,
            phonePrimary: ph,
            email: t.email.text.trim(),
            profession: t.profession.text.trim(),
            address: t.address.text.trim(),
            isPrimaryContact: t.isPrimary,
            isEmergencyContact: t.isEmergency,
          );
        }
      }
      ref.invalidate(studentDossierProvider(id));
      ref.invalidate(studentTutorsProvider(id));
      ref.invalidate(studentsRegistryProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Modifications enregistrées.', kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Erreur : $e', kRed);
      }
    }
  }

  String _initials() {
    final a = _firstName.text.trim(), b = _lastName.text.trim();
    final r =
        '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  @override
  Widget build(BuildContext context) {
    final dossier = ref.watch(studentDossierProvider(widget.studentId));
    return InscriptionModalFrame(
      child: dossier.when(
        loading: () => const SizedBox(
            height: 240, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
            height: 240,
            child: Center(
                child:
                    Text('Erreur : $e', style: TextStyle(color: kRed)))),
        data: (d) {
          if (!_primed) _prime(d);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            InscriptionHeader(
              icon: Icons.edit_outlined,
              title: '${_firstName.text} ${_lastName.text}'.trim().isEmpty
                  ? widget.fullName
                  : '${_firstName.text} ${_lastName.text}'.trim(),
              subtitle:
                  'Modifier · Étape ${_step + 1}/${_steps.length} · ${_steps[_step]}',
            ),
            InscriptionStepIndicator(current: _step, steps: _steps),
            Flexible(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [_stepIdentite(), _stepTuteurs()],
              ),
            ),
            InscriptionNavBar(
              currentStep: _step,
              totalSteps: _steps.length,
              submitting: _saving,
              onBack: _back,
              onNext: _next,
              onSubmit: _save,
              lastLabel: 'Enregistrer',
            ),
          ]);
        },
      ),
    );
  }

  Widget _stepIdentite() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: _PhotoPicker(
              bytes: _photoBytes,
              url: _photoUrl,
              initials: _initials(),
              onPick: _saving ? null : _pickPhoto,
            ),
          ),
          const SizedBox(height: 18),
          const FormSectionTitle('Identité'),
          FormTextField(controller: _firstName, label: 'Prénom *'),
          FormTextField(controller: _lastName, label: 'Nom *'),
          Row(children: [
            Expanded(
              child: FormDropdown<String>(
                label: 'Genre',
                value: _gender,
                items: const {'M': 'Masculin', 'F': 'Féminin'},
                onChanged: (v) => setState(() => _gender = v ?? 'M'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormDateField(
                label: 'Date de naissance',
                value: _dobIso,
                onChanged: (v) => setState(() => _dobIso = v),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
                child: FormTextField(
                    controller: _placeOfBirth, label: 'Lieu de naissance')),
            const SizedBox(width: 12),
            Expanded(
                child:
                    FormTextField(controller: _nationality, label: 'Nationalité')),
          ]),
          const FormSectionTitle('Situation familiale'),
          FormDropdown<String>(
            label: 'Situation familiale',
            value: _situation,
            items: _situations,
            onChanged: (v) => setState(() => _situation = v),
          ),
          FormTextField(
              controller: _siblings,
              label: 'Nombre de frères et sœurs',
              keyboardType: TextInputType.number),
          const FormSectionTitle('Statuts particuliers'),
          FormCheckTile(
              label: 'Pensionnaire / Interne',
              value: _isBoarder,
              onChanged: (v) => setState(() => _isBoarder = v)),
          FormCheckTile(
              label: 'Affecté par le MEPSA/METP',
              value: _isAffecte,
              onChanged: (v) => setState(() => _isAffecte = v)),
          FormCheckTile(
              label: 'Bénéficie d\'une bourse',
              value: _hasScholarship,
              onChanged: (v) => setState(() => _hasScholarship = v)),
          if (_hasScholarship)
            FormTextField(controller: _scholarshipType, label: 'Type de bourse'),
          FormCheckTile(
              label: 'Bénéficie d\'une aide sociale',
              value: _hasSocialAid,
              onChanged: (v) => setState(() => _hasSocialAid = v)),
          if (_hasSocialAid)
            FormTextField(
                controller: _socialAidType, label: 'Type d\'aide sociale'),
          const FormSectionTitle('Santé & Adresse'),
          FormDropdown<String>(
            label: 'Groupe sanguin',
            value: _bloodGroup,
            items: _bloodGroups,
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          FormTextField(
              controller: _allergies,
              label: 'Allergies / Antécédents médicaux',
              maxLines: 2),
          FormTextField(controller: _address, label: 'Adresse'),
          Row(children: [
            Expanded(child: FormTextField(controller: _city, label: 'Ville')),
            const SizedBox(width: 12),
            Expanded(
                child: FormTextField(
                    controller: _region, label: 'Département / Région')),
          ]),
        ]),
      );

  Widget _stepTuteurs() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _tutors.length; i++)
            _TutorCard(
              draft: _tutors[i],
              index: i,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                final t = _tutors.removeAt(i);
                if (t.id != null) _removedTutorIds.add(t.id!);
                t.dispose();
              }),
            ),
          if (_tutors.length < 4)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un tuteur / contact'),
              style: TextButton.styleFrom(foregroundColor: kNavy),
              onPressed: () => setState(() => _tutors.add(_TutorDraft())),
            ),
        ]),
      );
}

// ─── Carte d'édition d'un tuteur ─────────────────────────────────────────────
class _TutorCard extends StatelessWidget {
  const _TutorCard({
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });
  final _TutorDraft draft;
  final int index;
  final VoidCallback onChanged, onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: draft.isPrimary ? kNavy.withValues(alpha: 0.3) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(draft.isPrimary ? 'Tuteur principal' : 'Contact ${index + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: kNavy)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: kRed, size: 18),
            tooltip: 'Supprimer ce tuteur',
            onPressed: onRemove,
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: FormTextField(controller: draft.firstName, label: 'Prénom *')),
          const SizedBox(width: 12),
          Expanded(
              child: FormTextField(controller: draft.lastName, label: 'Nom *')),
        ]),
        FormDropdown<String>(
          label: 'Lien de parenté',
          value: draft.relationship,
          items: const {
            'pere': 'Père',
            'mere': 'Mère',
            'tuteur': 'Tuteur légal',
            'autre': 'Autre',
          },
          onChanged: (v) {
            draft.relationship = v ?? 'autre';
            onChanged();
          },
        ),
        FormTextField(
            controller: draft.phone,
            label: 'Téléphone *',
            keyboardType: TextInputType.phone),
        FormTextField(
            controller: draft.email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress),
        FormTextField(controller: draft.profession, label: 'Profession'),
        FormTextField(controller: draft.address, label: 'Adresse'),
        FormCheckTile(
            label: 'Contact principal',
            value: draft.isPrimary,
            onChanged: (v) {
              draft.isPrimary = v;
              onChanged();
            }),
        FormCheckTile(
            label: 'Contact d\'urgence',
            value: draft.isEmergency,
            onChanged: (v) {
              draft.isEmergency = v;
              onChanged();
            }),
      ]),
    );
  }
}

class _TutorDraft {
  _TutorDraft({
    this.id,
    String firstName = '',
    String lastName = '',
    this.relationship = 'mere',
    String phone = '',
    String email = '',
    String profession = '',
    String address = '',
    this.isPrimary = false,
    this.isEmergency = false,
  })  : firstName = TextEditingController(text: firstName),
        lastName = TextEditingController(text: lastName),
        phone = TextEditingController(text: phone),
        email = TextEditingController(text: email),
        profession = TextEditingController(text: profession),
        address = TextEditingController(text: address);

  factory _TutorDraft.fromInfo(StudentTutorInfo t) => _TutorDraft(
        id: t.id,
        firstName: t.firstName,
        lastName: t.lastName,
        relationship:
            const {'pere', 'mere', 'tuteur', 'autre'}.contains(t.relationship)
                ? t.relationship
                : 'autre',
        phone: t.phonePrimary ?? '',
        email: t.email ?? '',
        profession: t.profession ?? '',
        address: t.address ?? '',
        isPrimary: t.isPrimary,
        isEmergency: t.isEmergency,
      );

  final String? id;
  final TextEditingController firstName, lastName, phone, email, profession,
      address;
  String relationship;
  bool isPrimary, isEmergency;

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    profession.dispose();
    address.dispose();
  }
}

// ─── Sélecteur de photo ───────────────────────────────────────────────────────
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker(
      {required this.bytes,
      required this.url,
      required this.initials,
      required this.onPick});
  final Uint8List? bytes;
  final String? url;
  final String initials;
  final VoidCallback? onPick;
  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (bytes != null) {
      avatar = CircleAvatar(radius: 46, backgroundImage: MemoryImage(bytes!));
    } else if (url != null && url!.isNotEmpty) {
      avatar = CircleAvatar(
          radius: 46,
          backgroundColor: kSurface,
          backgroundImage: CachedNetworkImageProvider(url!));
    } else {
      avatar = CircleAvatar(
        radius: 46,
        backgroundColor: kNavy.withValues(alpha: 0.10),
        child: Text(initials,
            style: TextStyle(
                color: kNavy, fontSize: 28, fontWeight: FontWeight.w800)),
      );
    }
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder, width: 2)),
        child: avatar,
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Material(
          color: kNavy,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPick,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.photo_camera_outlined,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }
}
