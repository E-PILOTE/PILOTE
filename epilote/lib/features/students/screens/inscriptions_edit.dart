part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MODIFIER UN DOSSIER — identité, scolarité, tuteurs, en trois pages.
//
//  ── POURQUOI CE FICHIER RESTE AU-DESSUS DE LA CIBLE ────────────────────────
//  Une trentaine de contrôleurs, trois pages de formulaire et un enregistrement
//  qui les relit tous : c'est UN objet cohérent, pas trois. Le découper le long
//  du patron de l'assistant (`add_inscription_steps_*`, un widget par étape
//  avec état partagé) supposerait de réécrire `_save()` — le chemin qui porte
//  les gardes anti-perte silencieuse : `group_id` exigé avant d'écrire un
//  tuteur neuf, fiches de tuteur incomplètes refusées plutôt que jetées, photo
//  différée sans emporter le reste. Ce chantier mérite sa propre session.
//
//  Ce qui POUVAIT en sortir en est sorti : les sous-widgets (carte tuteur,
//  sélecteur de photo) dans `inscriptions_edit_parts.dart`, et les règles de
//  refus dans `services/edition_eleve_garde.dart`, où elles se testent.
// ════════════════════════════════════════════════════════════════════════════

//  MODIFICATION DE L'ÉLÈVE — MÊME assistant que l'inscription (en-tête à icône
//  dégradée + indicateur d'étapes + barre de navigation), prérempli.
//  Étapes : Élève · Tuteurs. Un seul « Enregistrer » persiste tout (offline).
// ════════════════════════════════════════════════════════════════════════════
class _EditStudentModal extends ConsumerStatefulWidget {
  const _EditStudentModal({required this.row});
  final InscriptionRow row;
  @override
  ConsumerState<_EditStudentModal> createState() => _EditStudentModalState();
}

class _EditStudentModalState extends ConsumerState<_EditStudentModal> {
  final _page = PageController();
  int _step = 0;
  static const _steps = ['Élève', 'Scolarité', 'Tuteurs'];

  // Identité
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
  bool _isBoarder = false;
  bool _isAffecte = false;
  bool _hasScholarship = false;
  bool _hasSocialAid = false;
  String? _bloodGroup;

  // Photo
  String? _photoUrl;
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  // Scolarité (inscription)
  late String? _classId = widget.row.classId;
  late String _inscriptionType = widget.row.inscriptionType;
  late bool _isRepeating = widget.row.isRepeating;
  final _prevSchool = TextEditingController();
  final _prevClass = TextEditingController();
  final _transferReason = TextEditingController();
  final _notes = TextEditingController();
  bool _enrollPrimed = false;

  // Tuteurs
  final List<TuteurBrouillon> _tutors = [];
  final List<String> _removedTutorIds = [];

  bool _primed = false;
  bool _saving = false;

  // Les tables de libellés (situations familiales, groupes sanguins, liens de
  // parenté) vivent dans `models/eleve_libelles.dart` et `models/tutor_draft.dart` :
  // elles étaient recopiées ici, dans l'assistant et dans l'éditeur du registre,
  // et le récapitulatif — qui n'en avait aucune — affichait le code brut.

  @override
  void dispose() {
    _page.dispose();
    for (final c in [
      _firstName, _lastName, _placeOfBirth, _nationality, _siblings,
      _scholarshipType, _socialAidType, _allergies, _address, _city, _region,
      _prevSchool, _prevClass, _transferReason, _notes,
    ]) {
      c.dispose();
    }
    for (final t in _tutors) {
      t.dispose();
    }
    super.dispose();
  }

  bool _b(Object? v) => v == 1 || v == true;

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
      _tutors.add(TuteurBrouillon.fromInfo(t));
    }
    _primed = true;
  }

  // Préremplit la scolarité depuis la ligne d'inscription brute.
  void _primeEnroll(Map<String, dynamic> e) {
    _classId = (e['class_id'] as String?) ?? widget.row.classId;
    _inscriptionType =
        (e['inscription_type'] as String?) ?? widget.row.inscriptionType;
    _isRepeating = _b(e['is_repeating']);
    _prevSchool.text = (e['previous_school_name'] as String?) ?? '';
    _prevClass.text = (e['previous_class_name'] as String?) ?? '';
    _transferReason.text = (e['transfer_reason'] as String?) ?? '';
    _notes.text = (e['notes'] as String?) ?? '';
    _enrollPrimed = true;
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
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
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _page.previousPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  /// Les fiches de tuteur, telles que la garde a besoin de les voir.
  List<TuteurSaisi> get _tuteursSaisis =>
      [for (final t in _tutors) t.saisi];

  Future<void> _save() async {
    if (writeRefusedForLicense(context)) return;

    // Les quatre règles de refus vivent dans `services/edition_eleve_garde.dart`
    // — trois d'entre elles existent parce qu'un dégât s'est produit en
    // production, et elles s'y testent. Ici on ne fait qu'obéir, et ramener
    // l'agent sur la page où le problème se corrige.
    final refus = refusEdition(
      prenom: _firstName.text,
      nom: _lastName.text,
      classId: _classId,
      tuteurs: _tuteursSaisis,
      groupId: ref.read(authNotifierProvider).valueOrNull?.groupId,
      schoolId: ref.read(authNotifierProvider).valueOrNull?.schoolId,
    );
    if (refus != null) {
      if (refus.etape != kEtapeAucune && refus.etape != _step) {
        setState(() => _step = refus.etape);
        _page.jumpToPage(refus.etape);
      }
      _snack(refus.message, kRed);
      return;
    }

    final id = widget.row.studentId;
    final profil = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profil?.groupId;
    final schoolId = profil?.schoolId;

    setState(() => _saving = true);
    var photoDiffere = false;
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        // La photo passe par Storage, donc par le réseau. Tout le reste de cet
        // écran est faisable hors ligne : un échec de téléversement ne doit pas
        // emporter la correction d'identité, de scolarité et de tuteurs.
        try {
          final client = ref.read(supabaseClientProvider);
          photoUrl = await uploadStudentPhoto(
            client: client,
            studentId: id,
            bytes: _photoBytes!,
            ext: _photoExt,
          );
        } catch (_) {
          photoDiffere = true;
        }
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
      // Scolarité (classe / type / redoublant / origine / notes).
      final isTransfer = _inscriptionType == 'transfer';
      await updateEnrollmentDetails(
        enrollmentId: widget.row.id,
        classId: _classId!,
        inscriptionType: _inscriptionType,
        isRepeating: _isRepeating,
        previousSchoolName:
            isTransfer ? _nullIfEmpty(_prevSchool.text) : null,
        previousClassName: isTransfer ? _nullIfEmpty(_prevClass.text) : null,
        transferReason: isTransfer ? _nullIfEmpty(_transferReason.text) : null,
        notes: _nullIfEmpty(_notes.text),
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
          // Non-nuls par construction : la garde d'identité en tête de `_save`
          // a déjà refusé l'enregistrement s'il existait un tuteur neuf sans
          // `group_id` ou sans `school_id` utilisable.
          await addTutor(
            studentId: id,
            groupId: groupId!.trim(),
            schoolId: schoolId!.trim(),
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
      ref.invalidate(enrollmentDetailProvider(widget.row.id));
      if (mounted) {
        Navigator.of(context).pop();
        _snack(
          photoDiffere
              ? 'Modifications enregistrées — la photo n\'a pas pu être '
                  'envoyée (connexion requise), reprenez-la plus tard.'
              : 'Modifications enregistrées.',
          photoDiffere ? kAccent : kGreen,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(messageErreur(e), kRed);
      }
    }
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final dossier = ref.watch(studentDossierProvider(widget.row.studentId));
    return InscriptionModalFrame(
      child: dossier.when(
        loading: () => const SizedBox(
            height: 240, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
            height: 240,
            child: Center(
                child:
                    Text(messageErreur(e), style: TextStyle(color: kRed)))),
        data: (d) {
          if (!_primed) _prime(d);
          final em = ref.watch(enrollmentDetailProvider(widget.row.id)).valueOrNull;
          if (em != null && !_enrollPrimed) _primeEnroll(em);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            InscriptionHeader(
              icon: Icons.edit_outlined,
              title: '${_firstName.text} ${_lastName.text}'.trim().isEmpty
                  ? widget.row.fullName
                  : '${_firstName.text} ${_lastName.text}'.trim(),
              subtitle:
                  'Modifier · Étape ${_step + 1}/${_steps.length} · ${_steps[_step]}',
            ),
            InscriptionStepIndicator(current: _step, steps: _steps),
            Flexible(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [_stepEleve(), _stepScolarite(), _stepTuteurs()],
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

  // ── Étape 1 — Élève (identique à l'inscription, prérempli + photo) ──────────
  Widget _stepEleve() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: PhotoPickerEleve(
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
                child: FormTextField(
                    controller: _nationality, label: 'Nationalité')),
          ]),
          const SizedBox(height: 4),
          const FormSectionTitle('Situation familiale'),
          FormDropdown<String>(
            label: 'Situation familiale',
            value: _situation,
            items: kSituationsFamiliales,
            onChanged: (v) => setState(() => _situation = v),
          ),
          FormTextField(
            controller: _siblings,
            label: 'Nombre de frères et sœurs',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 4),
          const FormSectionTitle('Statuts particuliers'),
          FormCheckTile(
            label: 'Pensionnaire / Interne',
            value: _isBoarder,
            onChanged: (v) => setState(() => _isBoarder = v),
          ),
          FormCheckTile(
            label: 'Affecté par le MEPSA/METP',
            value: _isAffecte,
            onChanged: (v) => setState(() => _isAffecte = v),
          ),
          FormCheckTile(
            label: 'Bénéficie d\'une bourse',
            value: _hasScholarship,
            onChanged: (v) => setState(() => _hasScholarship = v),
          ),
          if (_hasScholarship)
            FormTextField(
                controller: _scholarshipType, label: 'Type de bourse'),
          FormCheckTile(
            label: 'Bénéficie d\'une aide sociale',
            value: _hasSocialAid,
            onChanged: (v) => setState(() => _hasSocialAid = v),
          ),
          if (_hasSocialAid)
            FormTextField(
                controller: _socialAidType, label: 'Type d\'aide sociale'),
          const SizedBox(height: 4),
          const FormSectionTitle('Santé & Adresse'),
          FormDropdown<String>(
            label: 'Groupe sanguin',
            value: _bloodGroup,
            items: kGroupesSanguins,
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          FormTextField(
            controller: _allergies,
            label: 'Allergies / Antécédents médicaux',
            maxLines: 2,
          ),
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

  // ── Étape 2 — Scolarité (réaffectation + type + origine + notes) ────────────
  Widget _stepScolarite() {
    final classesAsync = ref.watch(classesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FormSectionTitle('Type d\'inscription'),
        FormDropdown<String>(
          label: 'Type',
          value: _inscriptionType,
          items: const {
            'new': 'Nouvelle inscription',
            'reinscription': 'Réinscription',
            'transfer': 'Transfert',
          },
          onChanged: (v) => setState(() => _inscriptionType = v ?? 'new'),
        ),
        const SizedBox(height: 4),
        const FormSectionTitle('Affectation'),
        classesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              Text(messageErreur(e), style: TextStyle(color: kRed)),
          data: (classes) {
            if (classes.isEmpty) {
              return Text('Aucune classe disponible.',
                  style: TextStyle(color: kTextMuted, fontSize: 13));
            }
            return CycleLevelClassPicker(
              entries: [for (final c in classes) _pickerEntry(c)],
              classId: _classId,
              onChanged: (v) => setState(() => _classId = v),
            );
          },
        ),
        FormCheckTile(
          label: 'Élève redoublant',
          value: _isRepeating,
          onChanged: (v) => setState(() => _isRepeating = v),
        ),
        if (_inscriptionType == 'transfer') ...[
          const SizedBox(height: 4),
          const FormSectionTitle('École d\'origine'),
          FormTextField(
              controller: _prevSchool, label: 'Nom de l\'école précédente'),
          FormTextField(controller: _prevClass, label: 'Classe précédente'),
          FormTextField(
              controller: _transferReason,
              label: 'Motif du transfert',
              maxLines: 2),
        ],
        const SizedBox(height: 4),
        const FormSectionTitle('Notes internes'),
        FormTextField(
            controller: _notes,
            label: 'Observations (optionnel)',
            maxLines: 3),
      ]),
    );
  }

  // ── Étape 3 — Tuteurs ───────────────────────────────────────────────────────
  Widget _stepTuteurs() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _tutors.length; i++)
            TuteurEditCard(
              draft: _tutors[i],
              index: i,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                final t = _tutors.removeAt(i);
                if (t.id != null) _removedTutorIds.add(t.id!);
                t.dispose();
              }),
              onPromote: () => setState(() {
                final cible = _tutors[i];
                for (final t in _tutors) {
                  t.isPrimary = identical(t, cible);
                }
              }),
            ),
          const SizedBox(height: 4),
          if (_tutors.length < 4)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un tuteur / contact'),
              style: TextButton.styleFrom(foregroundColor: kNavy),
              onPressed: () => setState(() => _tutors.add(TuteurBrouillon())),
            ),
        ]),
      );

  String _initials() {
    final a = _firstName.text.trim();
    final b = _lastName.text.trim();
    final r =
        '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }
}
