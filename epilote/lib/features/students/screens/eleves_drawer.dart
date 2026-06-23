part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TIROIR DÉTAIL ÉLÈVE (slide droit) — dossier complet (identité, statuts,
//  inscription de l'année, tuteurs, pièces) + actions : Modifier · Inscrire
//  (si non inscrit) · Désactiver. Réutilise studentDossierProvider.
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
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: Column(children: [
            _DwHeader(row: row),
            Expanded(
              child: dossier.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $e',
                      style: const TextStyle(color: kRed)),
                ),
                data: (d) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: _DwBody(row: row, d: d, docs: docs),
                ),
              ),
            ),
            if (!readOnly) _DwActionBar(row: row),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: kTextMuted),
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
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AdminBadge(_enrollLabel(row.enrollmentStatus),
                    color: _enrollColor(row.enrollmentStatus)),
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
          ('Statut', _enrollLabel(row.enrollmentStatus)),
          ('Classe', row.className ?? 'Non inscrit'),
          if ((row.levelCode ?? '').isNotEmpty) ('Niveau', row.levelCode!),
          if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
        ],
      ),
      ResumeCard(
        title: 'Identité',
        icon: Icons.person_outline,
        rows: [
          ('Matricule', row.matricule.isEmpty ? '—' : row.matricule),
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
          ('Situation familiale', _od(d.s('situation_familiale'))),
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
  static String _rel(String c) => switch (c) {
        'pere' => 'Père',
        'mere' => 'Mère',
        'tuteur' => 'Tuteur légal',
        'autre' => 'Autre',
        _ => c.isEmpty ? '—' : c,
      };
}

class _DwActionBar extends ConsumerWidget {
  const _DwActionBar({required this.row});
  final StudentRow row;

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Désactiver cet élève ?'),
        content: Text(
            '« ${row.fullName} » sera retiré du registre actif. '
            'Son dossier et ses inscriptions sont conservés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await runModuleWrite(context,
        () => deactivateStudent(row.id),
        success: 'Élève désactivé');
    if (done) {
      ref.invalidate(studentsRegistryProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
      child: Row(children: [
        PermissionGate(
          slug: 'eleves',
          action: 'update',
          child: Expanded(
            child: AdminPrimaryButton(
              label: 'Modifier',
              icon: Icons.edit_outlined,
              color: kNavy,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    _StudentEditModal(studentId: row.id, fullName: row.fullName),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (!row.isEnrolled)
          PermissionGate(
            slug: 'inscriptions',
            action: 'create',
            child: _DwOutline(
              label: 'Inscrire',
              icon: Icons.how_to_reg_rounded,
              color: kGreen,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    _EnrollDialog(studentId: row.id, fullName: row.fullName),
              ),
            ),
          ),
        if (!row.isEnrolled) const SizedBox(width: 10),
        PermissionGate(
          slug: 'eleves',
          action: 'delete',
          child: _DwOutline(
            label: '',
            icon: Icons.person_off_outlined,
            color: kRed,
            onTap: () => _deactivate(context, ref),
          ),
        ),
      ]),
    );
  }
}

class _DwOutline extends StatelessWidget {
  const _DwOutline(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 12 : 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
        ),
      );
}

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
                    Text('Erreur : $e', style: const TextStyle(color: kRed)))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: draft.isPrimary ? kNavy.withValues(alpha: 0.3) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(draft.isPrimary ? 'Tuteur principal' : 'Contact ${index + 1}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: kNavy)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: kRed, size: 18),
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
            style: const TextStyle(
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

// ════════════════════════════════════════════════════════════════════════════
//  INSCRIRE UN ÉLÈVE EXISTANT — cascade Cycle ▸ Niveau ▸ Classe + type +
//  redoublant → enrollStudent (statut « en attente »).
// ════════════════════════════════════════════════════════════════════════════
class _EnrollDialog extends ConsumerStatefulWidget {
  const _EnrollDialog({required this.studentId, required this.fullName});
  final String studentId, fullName;
  @override
  ConsumerState<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends ConsumerState<_EnrollDialog> {
  String? _classId;
  String _type = 'new';
  bool _isRepeating = false;
  bool _saving = false;

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  ClassPickerEntry _entry(ClassModel c) {
    final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
    return ClassPickerEntry(
      id: c.id,
      name: c.name,
      cycleCode: cyc.code,
      cycleLabel: cyc.label,
      cycleOrder: cyc.order,
      levelCode: c.levelCode ?? '',
      levelOrder: c.levelOrder ?? 999,
      capacity: c.capacity,
      count: c.studentCount,
    );
  }

  Future<void> _save() async {
    if (_classId == null) {
      _snack('Sélectionnez la classe (cycle ▸ niveau ▸ classe).', kRed);
      return;
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) {
      _snack('Aucune année scolaire active.', kRed);
      setState(() => _saving = false);
      return;
    }
    final ok = await runModuleWrite(
      context,
      () => enrollStudent(
        schoolId: profile?.schoolId ?? '',
        groupId: profile?.groupId ?? '',
        studentId: widget.studentId,
        classId: _classId!,
        academicYearId: yearId,
        isRepeating: _isRepeating,
        inscriptionType: _type,
        createdBy: profile?.id,
      ),
      success: 'Inscription créée (en attente de validation)',
    );
    if (ok) {
      ref.invalidate(studentsRegistryProvider);
      if (mounted) Navigator.pop(context);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    return AdminFormDialog(
      icon: Icons.how_to_reg_rounded,
      title: 'Inscrire l\'élève',
      subtitle: widget.fullName,
      width: 520,
      saving: _saving,
      submitLabel: 'Inscrire',
      submitIcon: Icons.check_rounded,
      submitColor: kGreen,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormDropdown<String>(
          label: 'Type d\'inscription',
          value: _type,
          items: const {
            'new': 'Nouvelle inscription',
            'reinscription': 'Réinscription',
            'transfer': 'Transfert',
          },
          onChanged: (v) => setState(() => _type = v ?? 'new'),
        ),
        classesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              Text('Erreur : $e', style: const TextStyle(color: kRed)),
          data: (classes) {
            if (classes.isEmpty) {
              return const Text('Aucune classe disponible.',
                  style: TextStyle(color: kTextMuted, fontSize: 13));
            }
            return CycleLevelClassPicker(
              entries: [for (final c in classes) _entry(c)],
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
      ]),
    );
  }
}
