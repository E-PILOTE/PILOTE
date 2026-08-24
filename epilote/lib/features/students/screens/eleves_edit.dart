part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MODIFICATION ÉLÈVE (personne) — assistant 2 étapes Identité · Tuteurs
//  (la scolarité se gère via Inscriptions). Même habillage que l'inscription.
//
//  ── CE QUI A ÉTÉ REPRIS ICI ────────────────────────────────────────────────
//  Cet écran était la COPIE de celui du guichet (`inscriptions_edit.dart`), et
//  il en avait gardé les défauts après que l'original eut été corrigé :
//   • aucune garde d'écriture — d'où un `group_id` vide qui faisait perdre le
//     lot de synchronisation, et des fiches de tuteur jetées en silence ;
//   • la case « contact principal » se décochait, laissant un élève sans le
//     numéro que l'école compose en premier ;
//   • un échec de téléversement de la photo — c'est-à-dire une simple coupure
//     réseau — emportait toute la saisie, dans une application offline-first.
//
//  La fiche tuteur et le sélecteur de photo vivent désormais dans
//  `widgets/tuteur_edit_card.dart`, partagés avec le guichet : la prochaine
//  correction ne pourra plus n'atteindre qu'une moitié de l'application.
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

  final List<TuteurBrouillon> _tutors = [];
  final List<String> _removedTutorIds = [];

  bool _primed = false, _saving = false;

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
    // Pré-remplissage identique à celui de l'éditeur du guichet — volontairement.
    // Il mérite discussion : un élève importé par CSV n'a pas de nationalité, et
    // ouvrir sa fiche pour corriger un téléphone la fixera à « Congolaise » au
    // premier enregistrement. La valeur est visible à l'écran avant d'être
    // écrite, donc ce n'est pas silencieux — mais si on décide de la changer,
    // c'est aux DEUX écrans à la fois, pas ici seulement.
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
    if (writeRefusedForLicense(context)) return;

    // Les règles de refus vivent dans `services/edition_eleve_garde.dart` — les
    // mêmes qu'au guichet, où elles existent parce qu'un dégât s'est produit en
    // production. Ici on ne fait qu'obéir, et ramener l'agent sur la page où le
    // problème se corrige.
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    final refus = refusEditionRegistre(
      prenom: _firstName.text,
      nom: _lastName.text,
      tuteurs: [for (final t in _tutors) t.saisi],
      groupId: groupId,
      schoolId: schoolId,
    );
    if (refus != null) {
      if (refus.etape != kEtapeAucune && refus.etape != _step) {
        setState(() => _step = refus.etape);
        _page.jumpToPage(refus.etape);
      }
      _snack(refus.message, kRed);
      return;
    }

    setState(() => _saving = true);
    final id = widget.studentId;
    var photoDiffere = false;
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        // La photo ne demande plus le réseau : `queueAvatarUpload` calcule
        // son URL publique sans connexion, pose les octets sur le disque et
        // les envoie au retour du réseau. Le `try` local reste — une file
        // pleine ou un disque saturé ne doit pas emporter la saisie.
        try {
          photoUrl = await queueAvatarUpload(
            client: ref.read(supabaseClientProvider),
            folder: 'students',
            ownerId: id,
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
      for (final tid in _removedTutorIds) {
        await deleteTutor(tid);
      }
      for (final t in _tutors) {
        final fn = t.firstName.text.trim();
        final ln = t.lastName.text.trim();
        final ph = t.phone.text.trim();
        // À ce stade, une fiche neuve ne peut plus être à moitié remplie : la
        // garde l'a refusée. Ce qui reste ici, ce sont les fiches JAMAIS
        // touchées — celles qu'on ignore sans bruit, à dessein.
        if (fn.isEmpty || ln.isEmpty || ph.isEmpty) continue;
        if (t.id == null) {
          // Non-nuls par construction : la garde a refusé l'enregistrement
          // s'il existait un tuteur neuf sans `group_id` ou sans `school_id`
          // utilisable.
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
            // `_nullIfEmpty` et non `.trim()` : vider un champ doit remettre la
            // colonne à NULL, pas y poser une chaîne vide que l'annuaire
            // compterait ensuite comme une adresse renseignée.
            email: _nullIfEmpty(t.email.text),
            profession: _nullIfEmpty(t.profession.text),
            address: _nullIfEmpty(t.address.text),
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
        _snack(
            photoDiffere
                ? 'Modifications enregistrées — la photo n\'a pas pu être '
                    'mise en file d\'envoi, reprenez-la.'
                : 'Modifications enregistrées.',
            photoDiffere ? kAccent : kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(messageErreur(e), kRed);
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
                    Text(messageErreur(e), style: TextStyle(color: kRed)))),
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
                child:
                    FormTextField(controller: _nationality, label: 'Nationalité')),
          ]),
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
            items: kGroupesSanguins,
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
            TuteurEditCard(
              key: ObjectKey(_tutors[i]),
              draft: _tutors[i],
              index: i,
              onChanged: () => setState(() {}),
              onPromote: () =>
                  setState(() => promouvoirContactPrincipal(_tutors, _tutors[i])),
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
              onPressed: () => setState(() => _tutors.add(TuteurBrouillon())),
            ),
        ]),
      );
}
