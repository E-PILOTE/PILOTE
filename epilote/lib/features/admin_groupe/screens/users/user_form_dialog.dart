part of '../admin_users_screen.dart';

// Formulaire utilisateur : état, cycle de vie, enregistrement.

String _fmtDob(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

DateTime? _parseDob(String s) {
  final p = s.trim().replaceAll('-', '/').split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  if (y < 1900 || y > DateTime.now().year) return null;
  if (m < 1 || m > 12) return null;
  if (d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, required this.data, this.user});
  final AdminUsersData data;
  final AdminUser? user;

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late final TextEditingController _matricule;
  late final TextEditingController _dob;
  late final TextEditingController _address;
  late final TextEditingController _birthPlace;
  // Volet carrière RH (migration 0023)
  late final TextEditingController _grade;
  late final TextEditingController _echelon;
  late final TextEditingController _category;
  late final TextEditingController _speciality;
  late final TextEditingController _hireDate;
  String? _schoolId;
  String  _role = 'enseignant';
  String? _accessProfileId;
  String? _gender;
  String? _employmentStatus;
  DateTime? _dobDate;
  DateTime? _hireDateD;
  bool    _obscure = true;
  bool    _saving  = false;
  String? _error;

  // Photo : choisie en mémoire, envoyée seulement à l'enregistrement. À la
  // création, l'identifiant de la personne n'existe pas encore — il n'y a donc
  // aucun chemin de stockage à calculer avant.
  Uint8List? _photoOctets;
  String?    _photoNom;
  bool       _photoRetiree = false;

  static const _kEmploymentStatuses = <(String, String)>[
    ('fonctionnaire', 'Fonctionnaire'),
    ('contractuel', 'Contractuel'),
    ('volontaire', 'Volontaire'),
    ('prestataire', 'Prestataire'),
    ('stagiaire', 'Stagiaire'),
    ('benevole', 'Bénévole'),
  ];

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _email      = TextEditingController(text: u?.email ?? '');
    _password   = TextEditingController();
    _first      = TextEditingController(text: u?.firstName ?? '');
    _last       = TextEditingController(text: u?.lastName ?? '');
    _phone      = TextEditingController(text: u?.phone ?? '');
    _matricule  = TextEditingController(text: u?.employeeNumber ?? '');
    _dobDate    = u?.dateOfBirth;
    _dob        = TextEditingController(text: _fmtDob(u?.dateOfBirth));
    _address    = TextEditingController(text: u?.address ?? '');
    _birthPlace = TextEditingController(text: u?.birthPlace ?? '');
    _grade      = TextEditingController(text: u?.grade ?? '');
    _echelon    = TextEditingController(text: u?.echelon ?? '');
    _category   = TextEditingController(text: u?.category ?? '');
    _speciality = TextEditingController(text: u?.speciality ?? '');
    _hireDateD  = u?.hireDate;
    _hireDate   = TextEditingController(text: _fmtDob(u?.hireDate));
    _employmentStatus = u?.employmentStatus;
    _gender     = u?.gender;
    _schoolId   = u?.schoolId ??
        (widget.data.schools.isNotEmpty ? widget.data.schools.first.id : null);
    _role = u?.role ?? 'enseignant';
    _accessProfileId = u?.accessProfileId;
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _first, _last, _phone,
                     _matricule, _dob, _address, _birthPlace,
                     _grade, _echelon, _category, _speciality, _hireDate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dob.text = _fmtDob(picked);
      });
    }
  }

  /// Webcam ou fichier — la même porte que la fiche élève et la fiche agent.
  /// Là où il n'y a pas de webcam, `choisirPhotoPersonne` ouvre directement le
  /// sélecteur : une boîte de dialogue à un seul choix est un clic volé.
  Future<void> _choisirPhoto() async {
    try {
      final choix =
          await choisirPhotoPersonne(context, extensions: kAvatarExtensions);
      if (choix == null || !mounted) return;
      setState(() {
        _photoOctets  = choix.octets;
        _photoNom     = choix.nomFichier;
        _photoRetiree = false;
        _error        = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = messageErreur(e));
    }
  }

  void _retirerPhoto() => setState(() {
        _photoOctets  = null;
        _photoNom     = null;
        // Sur une fiche existante, retirer veut dire EFFACER la colonne ; sur
        // une création, il n'y a rien à effacer, seulement à oublier.
        _photoRetiree = _isEdit;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_schoolId == null) {
      setState(() => _error = 'Veuillez sélectionner une école');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final svc = ref.read(adminUsersServiceProvider);
      final dob = _dob.text.trim().isNotEmpty
          ? (_dobDate ?? _parseDob(_dob.text.trim()))
          : null;
      final hire = _hireDate.text.trim().isNotEmpty
          ? (_hireDateD ?? _parseDob(_hireDate.text.trim()))
          : null;
      if (_isEdit) {
        await svc.updateUser(
          id:              widget.user!.id,
          firstName:       _first.text.trim(),
          lastName:        _last.text.trim(),
          schoolId:        _schoolId!,
          role:            _role,
          accessProfileId: _accessProfileId,
          phone:           _phone.text.trim(),
          employeeNumber:  _matricule.text.trim(),
          gender:          _gender,
          dateOfBirth:     dob,
          address:         _address.text.trim(),
          birthPlace:      _birthPlace.text.trim(),
          employmentStatus: _employmentStatus,
          grade:           _grade.text.trim(),
          echelon:         _echelon.text.trim(),
          category:        _category.text.trim(),
          speciality:      _speciality.text.trim(),
          hireDate:        hire,
          photoOctets:     _photoOctets,
          photoNom:        _photoNom,
          retirerPhoto:    _photoRetiree,
        );
      } else {
        await svc.createUser(
          email:           _email.text.trim(),
          password:        _password.text,
          firstName:       _first.text.trim(),
          lastName:        _last.text.trim(),
          schoolId:        _schoolId!,
          role:            _role,
          accessProfileId: _accessProfileId,
          phone:           _phone.text.trim(),
          employeeNumber:  _matricule.text.trim(),
          gender:          _gender,
          dateOfBirth:     dob,
          address:         _address.text.trim(),
          birthPlace:      _birthPlace.text.trim(),
          photoOctets:     _photoOctets,
          photoNom:        _photoNom,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'Utilisateur mis à jour' : 'Utilisateur créé avec succès'),
        ));
      }
    } on PhotoNonPosee catch (e) {
      // ⚠️ À la création, le COMPTE EXISTE : afficher une erreur rouge ferait
      // resoumettre le formulaire, pour se heurter à « adresse déjà utilisée ».
      // On referme et l'on dit exactement ce qui s'est passé.
      if (!mounted) return;
      if (_isEdit) {
        setState(() { _error = e.message; _saving = false; });
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kAccent,
        duration: const Duration(seconds: 6),
        content: Text(e.message),
      ));
    } catch (e) {
      setState(() { _error = _clean('$e'); _saving = false; });
    }
  }

  String _clean(String raw) {
    final m = RegExp(r'message: ([^,}]+)').firstMatch(raw);
    return m != null ? m.group(1)!.trim() : raw;
  }

  List<({String value, String label})> get _roleItems {
    final items = [...kStaffRoles];
    if (!items.any((r) => r.value == _role)) {
      items.add((value: _role, label: roleLabel(_role)));
    }
    return items;
  }

  // ── Helpers visuels ──────────────────────────────────────────────────────


  /// Rafraîchit l’écran depuis les parties de ce formulaire sorties en
  /// extensions. `setState` est protégé : l’appeler hors de la classe est
  /// signalé par l’analyseur. Une seule porte, nommée, plutôt que sept
  /// appels que le découpage aurait rendus illégaux.
  void rafraichir(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) => construireFormulaire(context);
}
