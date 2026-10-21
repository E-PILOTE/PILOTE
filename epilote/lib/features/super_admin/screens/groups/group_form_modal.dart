part of '../school_groups_screen.dart';

// ─── Modal Formulaire (Créer / Modifier) ──────────────────────────────────────

class _GroupFormModal extends ConsumerStatefulWidget {
  const _GroupFormModal({
    required this.plans,
    required this.groupes,
    required this.onSaved,
    this.existing,
  });
  final List<PlanInfo> plans;

  /// Les groupes déjà chargés par l'écran.
  final List<GroupDetail> groupes;
  final GroupDetail?   existing;
  final VoidCallback   onSaved;

  @override
  ConsumerState<_GroupFormModal> createState() => _GroupFormModalState();
}

class _GroupFormModalState extends ConsumerState<_GroupFormModal> {
  final _formKey        = GlobalKey<FormState>();
  final _name           = TextEditingController();
  final _email          = TextEditingController();
  final _phone          = TextEditingController();
  final _address        = TextEditingController();
  final _notes          = TextEditingController();
  final _foundedYearCtrl = TextEditingController();

  /// Caractère du groupe (migration 0180) : laïc, catholique, protestant…
  String? _caractere;

  /// Ordre d'enseignement : le ministère qui agrée les écoles du groupe.
  /// Jamais prérempli à la création : deviner « MEPSA » rangerait en silence
  /// un lycée technique sous le mauvais ministère, et personne ne le verrait
  /// avant l'inscription aux examens d'État.
  String? _tutelle;

  /// Agrément : SAISI, jamais instruit. Trois champs, aucun workflow.
  final _agrementNum = TextEditingController();
  String? _agrementType;
  DateTime? _agrementDate;
  String? _department;
  String? _planId;
  bool    _saving       = false;

  // Logo upload
  String?    _uploadedLogoUrl;  // URL finale (après upload ou URL existante)
  Uint8List? _logoPreviewBytes; // aperçu local avant upload
  bool       _uploadingLogo = false;

  static const _depts = [
    'Brazzaville', 'Pointe-Noire', 'Dolisie', 'Ouesso', 'Impfondo',
    'Owando', 'Gamboma', 'Kinkala', 'Madingou', 'Sibiti',
    'Mossendjo', 'Djambala', 'Ewo', 'Fort-Rousset',
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _name.text          = g.name;
      _email.text         = g.adminEmail;
      _phone.text         = g.phone       ?? '';
      _address.text       = g.address     ?? '';
      _notes.text         = g.notes       ?? '';
      _uploadedLogoUrl    = g.logoUrl;
      _caractere          = g.caractere;
      _tutelle            = g.tutelle;
      _agrementNum.text   = g.agrementNumero ?? '';
      _agrementType       = g.agrementType;
      _agrementDate       = g.agrementDate;
      _department         = g.department;
      _planId             = g.planId;
      if (g.foundedYear != null) {
        _foundedYearCtrl.text = g.foundedYear.toString();
      }
    } else {
      _alignerLePlan();
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose();
    _phone.dispose(); _address.dispose(); _notes.dispose();
    _foundedYearCtrl.dispose();
    _agrementNum.dispose();
    super.dispose();
  }

  /// Les plans proposables : les formules des groupes privés, et elles seules.
  List<PlanInfo> get _plansOfferts => [
        for (final p in widget.plans)
          if (!p.horsOffrePrivee) p,
      ];

  /// Sélectionne d'office une formule de l'offre privée à la création.
  void _alignerLePlan() {
    final offerts = _plansOfferts;
    if (offerts.any((p) => p.id == _planId)) return;
    _planId = offerts.isEmpty ? null : offerts.first.id;
  }

  Future<void> _pickAndUploadLogo() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final url = await choisirEtEnvoyerLogoGroupe(
        client: client,
        onApercu: (octets) => setState(() {
          _logoPreviewBytes = octets;
          _uploadingLogo = true;
        }),
      );
      if (url != null && mounted) setState(() => _uploadedLogoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(messageErreur(e, contexte: 'Envoi du fichier')),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _logoPreviewBytes = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final yearStr = _foundedYearCtrl.text.trim();
      final int? foundedYear = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;

      final payload = {
        'name':         _name.text.trim(),
        // ⚠️ Plus de `group_type` envoyé : tout groupe est privé, et la base
        // pose `prive` par défaut. L'écrire ici retarderait le retrait de la
        // colonne — un client qui l'envoie casse le jour où elle disparaît.
        'caractere':    _caractere,
        // ⚠️ La tutelle est écrite SUR LE GROUPE, jamais sur l'école : un
        // déclencheur (migration 0153) la propage à toutes ses écoles. Envoyer
        // `schools.tutelle` depuis ici serait écrire dans une copie.
        'tutelle':      _tutelle,
        // ⚠️ Écrit sur le GROUPE seulement : un déclencheur le recopie sur
        // toutes ses écoles (migration 0158). L'écrire sur `schools` depuis
        // ici serait écrire dans une copie.
        'agrement_numero': _agrementNum.text.trim().isEmpty
            ? null
            : _agrementNum.text.trim(),
        'agrement_type': _agrementType,
        'agrement_date':
            _agrementDate?.toIso8601String().split('T').first,
        'department':   _department,
        'plan_id':      _planId,
        'admin_email':  _email.text.trim(),
        'phone':        _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
        'address':      _address.text.trim().isNotEmpty ? _address.text.trim() : null,
        'logo_url':     _uploadedLogoUrl,
        'notes':        _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'founded_year': foundedYear,
      };

      if (widget.existing != null) {
        await client.from('school_groups')
            .update(payload).eq('id', widget.existing!.id);
      } else {
        await client.from('school_groups').insert({
          ...payload,
          'subscription_status': 'trial',
          'is_active': true,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
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
  /// `setState` est protégé : une seule porte nommée plutôt que dix appels
  /// que le découpage aurait rendus illégaux.
  void rafraichir(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) => construireFormulaire(context);
}
