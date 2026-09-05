part of '../administrators_screen.dart';

// Formulaire administrateur : état, cycle de vie, enregistrement.

class _AdminFormModal extends ConsumerStatefulWidget {
  const _AdminFormModal({this.editing});
  final AdminDetail? editing;
  @override
  ConsumerState<_AdminFormModal> createState() => _AdminFormModalState();
}

class _AdminFormModalState extends ConsumerState<_AdminFormModal> {
  final _formKey        = GlobalKey<FormState>();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();

  String  _role         = 'admin_groupe';
  String? _groupId;
  bool    _saving       = false;
  bool    _obscurePwd   = true;

  // Avatar upload
  String?    _uploadedAvatarUrl;
  Uint8List? _avatarPreviewBytes;
  bool       _uploadingAvatar = false;

  bool get _isEditing => widget.editing != null;

  String get _initials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    return '?';
  }

  @override
  void initState() {
    super.initState();
    final a = widget.editing;
    if (a != null) {
      _firstNameCtrl.text  = a.firstName;
      _lastNameCtrl.text   = a.lastName;
      _emailCtrl.text      = a.email;
      _phoneCtrl.text      = a.phone ?? '';
      _role                = a.role;
      _groupId             = a.groupId;
      _uploadedAvatarUrl   = a.avatarUrl;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    // Webcam OU fichier — la même porte que la fiche élève, la fiche agent et
    // le formulaire utilisateur du groupe. Un administrateur se crée souvent
    // devant la personne : lui demander un fichier prêt était une contrainte
    // que rien ne justifiait. Là où il n'y a pas de webcam, le sélecteur
    // s'ouvre directement.
    final choix =
        await choisirPhotoPersonne(context, extensions: kAvatarExtensions);
    if (choix == null) return;

    setState(() {
      _avatarPreviewBytes = choix.octets;
      _uploadingAvatar = true;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final media = await compressAvatar(
        bytes: choix.octets,
        fileName: choix.nomFichier,
        mime: mimeForImageExtension(extensionPhoto(choix.nomFichier)),
      );
      final ext = media.fileName.split('.').last;
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'admins/$fileName';

      await client.storage.from('avatars').uploadBinary(
        path,
        media.bytes,
        fileOptions: FileOptions(contentType: media.mime, upsert: true),
      );

      final url = client.storage.from('avatars').getPublicUrl(path);
      setState(() => _uploadedAvatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(messageErreur(e, contexte: 'Envoi du fichier')),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _avatarPreviewBytes = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      if (_isEditing) {
        await client.from('profiles').update({
          'first_name': _firstNameCtrl.text.trim(),
          'last_name':  _lastNameCtrl.text.trim(),
          'phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'role':       _role,
          'group_id':   _role == 'admin_groupe' ? _groupId : null,
          'avatar_url': _uploadedAvatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.editing!.id);
      } else {
        await client.rpc('create_admin_user', params: {
          'p_email':      _emailCtrl.text.trim(),
          'p_password':   _passwordCtrl.text,
          'p_first_name': _firstNameCtrl.text.trim(),
          'p_last_name':  _lastNameCtrl.text.trim(),
          'p_role':       _role,
          'p_group_id':   _role == 'admin_groupe' ? _groupId : null,
          'p_phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'p_avatar_url': _uploadedAvatarUrl,
        });
      }
      ref.invalidate(administratorsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e)),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  /// Rafraîchit l’écran depuis la mise en page sortie en extension.
  /// `setState` est protégé : une seule porte nommée vaut mieux que six
  /// appels que le découpage aurait rendus illégaux.
  void rafraichir(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) => construireFormulaire(context);
}
