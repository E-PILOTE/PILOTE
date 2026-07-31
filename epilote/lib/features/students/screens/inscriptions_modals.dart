part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MODALS ÉLÈVE — détail (lecture) + modification (édition). Les TROIS modals
//  (inscription, modification, détail) partagent le MÊME habillage via le kit
//  `inscription_form_kit.dart` : cadre blanc, en-tête à icône dégradée,
//  indicateur d'étapes, barre de navigation, champs et cartes récap.
// ════════════════════════════════════════════════════════════════════════════

// ─── Badges colorés (statut / type) sur fond clair ───────────────────────────
Widget _statusBadge(String status) {
  final (label, color) = switch (status) {
    'active' => ('Validée', kGreen),
    'pending_validation' => ('En attente', kAccent),
    'rejected' => ('Rejetée', kRed),
    'withdrawn' => ('Retirée', kTextMuted),
    'transferred' => ('Transférée', kNavy),
    'graduated' => ('Diplômée', kGreen),
    _ => (status, kTextMuted),
  };
  return AdminBadge(label, color: color);
}

Widget _typeBadge(String type) {
  final (label, color) = switch (type) {
    'new' => ('Nouvelle', kGreen),
    'reinscription' => ('Réinscription', kNavy),
    'transfer' => ('Transfert', kAccent),
    _ => (type, kTextMuted),
  };
  return AdminBadge(label, color: color);
}

String _tutorRel(String code) => switch (code) {
      'pere' => 'Père',
      'mere' => 'Mère',
      'tuteur' => 'Tuteur légal',
      'autre' => 'Autre',
      _ => _orDash(code),
    };

// Convertit une classe en entrée de cascade Cycle ▸ Niveau ▸ Classe.
ClassPickerEntry _pickerEntry(ClassModel c) {
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

// ════════════════════════════════════════════════════════════════════════════
//  FICHE DÉTAIL (icône œil) — même habillage que l'inscription (en-tête blanc à
//  icône dégradée) + récap façon « Résumé », enrichi (photo, badges, actions).
// ════════════════════════════════════════════════════════════════════════════
class _InscriptionDetailModal extends ConsumerWidget {
  const _InscriptionDetailModal({
    required this.row,
    required this.onEdit,
    this.onValidate,
    this.onReject,
    this.onChangeClass,
    this.onWithdraw,
    this.onDelete,
    this.readOnly = false,
  });
  final InscriptionRow row;
  final VoidCallback onEdit;
  final VoidCallback? onValidate, onReject;
  final VoidCallback? onChangeClass, onWithdraw, onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossier = ref.watch(studentDossierProvider(row.studentId));
    return InscriptionModalFrame(
      maxHeight: 820,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InscriptionHeader(
          icon: Icons.badge_outlined,
          title: row.fullName,
          subtitle: '${row.className} · ${row.matricule}',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: dossier.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      Text('Erreur : $e', style: TextStyle(color: kRed))),
              data: (d) => _DossierBody(row: row, d: d),
            ),
          ),
        ),
        _DetailActionBar(
          readOnly: readOnly,
          isPending: row.status == 'pending_validation',
          onValidate: onValidate,
          onReject: onReject,
          onEdit: onEdit,
          onChangeClass: onChangeClass,
          onWithdraw: onWithdraw,
          onDelete: onDelete,
        ),
      ]),
    );
  }
}

// ─── Corps du dossier (bandeau identité + cartes récap façon inscription) ────
class _DossierBody extends ConsumerWidget {
  const _DossierBody({required this.row, required this.d});
  final InscriptionRow row;
  final StudentDossier d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enroll =
        ref.watch(enrollmentDetailProvider(row.id)).valueOrNull ?? const {};
    final docs =
        ref.watch(studentDocumentsProvider(row.studentId)).valueOrNull ??
            const <StudentDocument>[];

    final dob = d.dob;
    final age = row.age;
    final naissance = dob == null
        ? '—'
        : '${dob.toIso8601String().substring(0, 10)}${age != null ? '  ($age ans)' : ''}';
    final adresse = [d.s('address'), d.s('city'), d.s('region')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final siblings = d.student['nombre_freres_soeurs'];
    final siblingsLabel =
        (siblings is int && siblings > 0) ? '$siblings' : '';

    final statuts = <(String, String)>[
      if (_b(d.student['is_boarder'])) ('Interne', '✓'),
      if (_b(d.student['is_affecte'])) ('Affecté MEPSA/METP', '✓'),
      if (_b(d.student['has_scholarship']))
        ('Boursier', _vOr(d.s('scholarship_type'), '✓')),
      if (_b(d.student['has_social_aid']))
        ('Aide sociale', _vOr(d.s('social_aid_type'), '✓')),
    ];

    final prevSchool = (enroll['previous_school_name'] as String?)?.trim() ?? '';
    final prevClass = (enroll['previous_class_name'] as String?)?.trim() ?? '';
    final notes = (enroll['notes'] as String?)?.trim() ?? '';
    final rejection = (enroll['rejection_reason'] as String?)?.trim() ?? '';
    final withdrawal = (enroll['withdrawal_reason'] as String?)?.trim() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Bandeau identité (photo + badges) — le « mieux ».
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          _Avatar(row: row, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _statusBadge(row.status),
                  _typeBadge(row.inscriptionType),
                  if (row.isRepeating)
                    AdminBadge('Redoublant', color: kRed),
                ]),
              ],
            ),
          ),
        ]),
      ),
      ResumeCard(
        title: 'Inscription',
        icon: Icons.how_to_reg_outlined,
        rows: [
          ('Matricule', row.matricule),
          ('Classe', row.className),
          ('Cycle', row.cycle.label),
          ('Niveau', _orDash(row.levelCode)),
          if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
          ('Type', row.typeLabel),
          ('Statut', row.statusLabel),
          ('Redoublant', row.isRepeating ? 'Oui' : 'Non'),
          ('Date d\'inscription',
              row.enrollmentDate?.toIso8601String().substring(0, 10) ?? '—'),
          if (row.validatedAt != null)
            ('Validée le', row.validatedAt!.toIso8601String().substring(0, 10)),
          if (prevSchool.isNotEmpty) ('École précédente', prevSchool),
          if (prevClass.isNotEmpty) ('Classe précédente', prevClass),
          if (rejection.isNotEmpty) ('Motif du rejet', rejection),
          if (withdrawal.isNotEmpty) ('Motif du retrait', withdrawal),
          if (notes.isNotEmpty) ('Notes internes', notes),
        ],
      ),
      ResumeCard(
        title: 'Identité',
        icon: Icons.person_outline,
        rows: [
          (
            'Sexe',
            row.gender == 'F'
                ? 'Féminin'
                : row.gender == 'M'
                    ? 'Masculin'
                    : '—'
          ),
          ('Naissance', naissance),
          ('Lieu de naissance', _orDash(d.s('place_of_birth'))),
          ('Nationalité', _orDash(d.s('nationality'))),
          ('Situation familiale', _situationLabel(d.s('situation_familiale'))),
          if (siblingsLabel.isNotEmpty) ('Frères et sœurs', siblingsLabel),
          ('Groupe sanguin', _orDash(d.s('blood_group'))),
          if (d.s('allergies').isNotEmpty) ('Antécédents', d.s('allergies')),
          ('Adresse', _orDash(adresse)),
        ],
      ),
      if (statuts.isNotEmpty)
        ResumeCard(
          title: 'Statuts particuliers',
          icon: Icons.verified_outlined,
          rows: statuts,
        ),
      ResumeCard(
        title: 'Tuteurs (${d.tutors.length})',
        icon: Icons.family_restroom_outlined,
        rows: d.tutors.isEmpty
            ? [('Aucun tuteur enregistré', '')]
            : [
                for (final t in d.tutors)
                  (
                    t.isPrimary ? 'Principal' : _tutorRel(t.relationship),
                    [
                      t.fullName,
                      if ((t.phonePrimary ?? '').trim().isNotEmpty)
                        '· ${t.phonePrimary}',
                      if ((t.profession ?? '').trim().isNotEmpty)
                        '· ${t.profession}',
                      if (t.isEmergency) '· urgence',
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
                    doc.isVerified ? '✓ vérifiée' : 'à vérifier',
                  ),
              ],
      ),
    ]);
  }

  static String _vOr(String v, String fallback) => v.isEmpty ? fallback : v;
  bool _b(Object? v) => v == 1 || v == true;
}

// ─── Barre d'actions de la fiche détail ──────────────────────────────────────
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.readOnly,
    required this.isPending,
    required this.onValidate,
    required this.onReject,
    required this.onEdit,
    required this.onChangeClass,
    required this.onWithdraw,
    required this.onDelete,
  });
  final bool readOnly, isPending;
  final VoidCallback? onValidate, onReject, onChangeClass, onWithdraw, onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kCardBg,
            border: Border(top: BorderSide(color: kBorder))),
        child: Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Année archivée — consultation seule.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
          color: kCardBg,
          border: Border(top: BorderSide(color: kBorder))),
      child: Row(children: [
        if (isPending && onValidate != null) ...[
          Expanded(
            child: AdminPrimaryButton(
              label: 'Valider',
              icon: Icons.check_rounded,
              color: kGreen,
              onTap: onValidate!,
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (isPending && onReject != null) ...[
          _OutlineBtn(
            label: 'Rejeter',
            icon: Icons.close_rounded,
            color: kRed,
            onTap: onReject!,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AdminPrimaryButton(
            label: 'Modifier',
            icon: Icons.edit_outlined,
            color: kNavy,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        _MoreMenu(
          onChangeClass: onChangeClass,
          onWithdraw: onWithdraw,
          onDelete: onDelete,
        ),
      ]),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onChangeClass,
    required this.onWithdraw,
    required this.onDelete,
  });
  final VoidCallback? onChangeClass, onWithdraw, onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Plus d\'actions',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 6),
      onSelected: (v) {
        switch (v) {
          case 'class':
            onChangeClass?.call();
          case 'withdraw':
            onWithdraw?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        if (onChangeClass != null)
          const PopupMenuItem(
            value: 'class',
            child: _MenuRow(
                icon: Icons.swap_horiz_rounded, label: 'Changer de classe'),
          ),
        if (onWithdraw != null)
          const PopupMenuItem(
            value: 'withdraw',
            child: _MenuRow(
                icon: Icons.logout_rounded, label: 'Retirer de la classe'),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer l\'inscription',
                color: kRed),
          ),
        ],
      ],
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.more_horiz_rounded, color: kTextMuted),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? kTextPrimary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13.5,
                color: color ?? kTextPrimary,
                fontWeight: FontWeight.w600)),
      ]);
}

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
  final List<_TutorDraft> _tutors = [];
  final List<String> _removedTutorIds = [];

  bool _primed = false;
  bool _saving = false;

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
      _tutors.add(_TutorDraft.fromInfo(t));
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

  Future<void> _save() async {
    if (writeRefusedForLicense(context)) return;
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      if (_step != 0) {
        setState(() => _step = 0);
        _page.jumpToPage(0);
      }
      _snack('Le prénom et le nom sont obligatoires.', kRed);
      return;
    }
    if (_classId == null) {
      setState(() => _step = 1);
      _page.jumpToPage(1);
      _snack('Sélectionnez la classe (cycle ▸ niveau ▸ classe).', kRed);
      return;
    }
    final id = widget.row.studentId;
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;

    // Un tuteur NEUF est la seule écriture de cet écran qui ait besoin du
    // `group_id`. Le motif `?? ''` écrivait une chaîne vide dans une colonne
    // `uuid` NOT NULL : SQLite l'acceptait, l'écran affichait « Modifications
    // enregistrées », puis le serveur répondait `22P02` et PowerSync abandonnait
    // le LOT ENTIER — emportant l'élève et son inscription modifiés juste avant.
    // On refuse donc en le disant, au lieu de perdre en silence. Et seulement
    // quand c'est nécessaire : sans tuteur neuf, l'identifiant ne sert pas et
    // rien ne doit bloquer une correction faisable hors ligne.
    final newTutors = _tutors.where((t) =>
        t.id == null &&
        t.firstName.text.trim().isNotEmpty &&
        t.lastName.text.trim().isNotEmpty &&
        t.phone.text.trim().isNotEmpty);
    if (newTutors.isNotEmpty && !isUsableId(groupId)) {
      _snack(writeIdentityMessage(const ['groupe']), kRed);
      return;
    }

    // Une fiche de tuteur commencée puis laissée incomplète était jetée en
    // silence (`continue`) : l'agent lisait « enregistré » et repartait avec un
    // dossier sans aucun contact parental — dans une école où le tuteur est le
    // seul canal joignable.
    final incomplets = _tutors
        .where((t) => t.id == null)
        .where((t) =>
            t.firstName.text.trim().isNotEmpty ||
            t.lastName.text.trim().isNotEmpty ||
            t.phone.text.trim().isNotEmpty)
        .where((t) =>
            t.firstName.text.trim().isEmpty ||
            t.lastName.text.trim().isEmpty ||
            t.phone.text.trim().isEmpty)
        .length;
    if (incomplets > 0) {
      setState(() => _step = 2);
      _page.jumpToPage(2);
      _snack(
          '$incomplets fiche(s) de tuteur incomplète(s) : le prénom, le nom et '
          'le téléphone sont obligatoires — complétez-les ou supprimez la fiche.',
          kRed);
      return;
    }

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
          // Non-nul par construction : la garde d'identité en tête de `_save`
          // a déjà refusé l'enregistrement s'il existait un tuteur neuf sans
          // `group_id` utilisable.
          await addTutor(
            studentId: id,
            groupId: groupId!.trim(),
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
        _snack('Erreur : $e', kRed);
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
                    Text('Erreur : $e', style: TextStyle(color: kRed)))),
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
                child: FormTextField(
                    controller: _nationality, label: 'Nationalité')),
          ]),
          const SizedBox(height: 4),
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
            items: _bloodGroups,
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
              Text('Erreur : $e', style: TextStyle(color: kRed)),
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
            _TutorEditorCard(
              draft: _tutors[i],
              index: i,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                final t = _tutors.removeAt(i);
                if (t.id != null) _removedTutorIds.add(t.id!);
                t.dispose();
              }),
            ),
          const SizedBox(height: 4),
          if (_tutors.length < 4)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un tuteur / contact'),
              style: TextButton.styleFrom(foregroundColor: kNavy),
              onPressed: () => setState(() => _tutors.add(_TutorDraft())),
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

// ─── Carte d'édition d'un tuteur (même style que l'inscription) ──────────────
class _TutorEditorCard extends StatelessWidget {
  const _TutorEditorCard({
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
            icon:
                Icon(Icons.delete_outline_rounded, color: kRed, size: 18),
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
          },
        ),
        FormCheckTile(
          label: 'Contact d\'urgence',
          value: draft.isEmergency,
          onChanged: (v) {
            draft.isEmergency = v;
            onChanged();
          },
        ),
      ]),
    );
  }
}

// ─── Brouillon de tuteur éditable (contrôleurs locaux) ───────────────────────
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

// ─── Sélecteur de photo (cercle + bouton appareil photo) ─────────────────────
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.url,
    required this.initials,
    required this.onPick,
  });
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
        backgroundImage: CachedNetworkImageProvider(url!),
      );
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
          border: Border.all(color: kBorder, width: 2),
        ),
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

// ─── Bouton contour (Rejeter…) ───────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

String _situationLabel(String code) => switch (code) {
      'biparentale' => 'Biparentale',
      'monoparentale_pere' => 'Monoparentale (père)',
      'monoparentale_mere' => 'Monoparentale (mère)',
      'orphelin_partiel' => 'Orphelin partiel',
      'orphelin_total' => 'Orphelin total',
      'tuteur' => 'Sous tutelle',
      _ => _orDash(code),
    };
