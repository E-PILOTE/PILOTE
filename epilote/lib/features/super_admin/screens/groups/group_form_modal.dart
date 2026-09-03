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

  /// Les groupes déjà chargés par l'écran. Sert à dire, sans une requête de
  /// plus, quel groupe détient déjà le rôle de tutelle d'un ministère.
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

  String  _groupType    = 'prive';

  /// Caractère du groupe — indépendant du secteur (migration 0180).
  ///
  /// ⚠️ CES TROIS VALEURS ÉTAIENT DANS LE CHAMP « TYPE ». « Catholique »,
  /// « Islamique » et « Protestant » y côtoyaient « Public » et « Privé »,
  /// alors que l'enum `group_type` n'accepte que les deux derniers : les
  /// choisir faisait échouer la création sur un 22P02. Elles cherchaient un
  /// champ qui n'existait pas. Il existe.
  String? _caractere;

  /// Ministère de tutelle du groupe. Jamais prérempli à la création : deviner
  /// « MEPSA » parce que c'est le cas le plus fréquent rangerait en silence
  /// un lycée technique sous le mauvais ministère, et personne ne le verrait
  /// avant l'inscription aux examens d'État.
  String? _tutelle;

  /// Ce groupe EST-IL le ministère de tutelle ? Faux par défaut : le rôle
  /// s'accorde, il ne se suppose pas. Un seul groupe le porte par ministère
  /// (index unique de la migration 0178).
  bool _estTutelle = false;

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
      _groupType          = g.groupType;
      _caractere          = g.caractere;
      _tutelle            = g.tutelle;
      _estTutelle         = g.administreReferentielNational;
      _agrementNum.text   = g.agrementNumero ?? '';
      _agrementType       = g.agrementType;
      _agrementDate       = g.agrementDate;
      _department         = g.department;
      _planId             = g.planId;
      if (g.foundedYear != null) {
        _foundedYearCtrl.text = g.foundedYear.toString();
      }
    } else {
      // ⚠️ `plans.first` triait par prix : « Découverte » et « Licence de
      // tutelle » sont tous deux à 0 XAF, l'ordre entre eux n'est pas garanti.
      // Un groupe ordinaire serait né sur le plan des ministères, et la base
      // l'aurait refusé sans que personne comprenne pourquoi.
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

  /// Les plans proposables pour ce groupe.
  ///
  /// ⚠️ DEUX NATURES DE CLIENT, DEUX RELATIONS (migration 0182). Un ministère
  /// de tutelle est rattaché au plan « Licence de tutelle », dont les
  /// conditions réelles vivent dans `tutelle_licences` ; un groupe privé est
  /// rattaché à une formule mensuelle, qui est le revenu de la plateforme.
  /// La base refuse le mélange dans les deux sens — l'écran ne doit même pas
  /// l'offrir.
  List<PlanInfo> get _plansOfferts => [
        for (final p in widget.plans)
          if (p.estLicence == _estTutelle) p,
      ];

  /// Aligne le plan sur la nature du groupe quand l'interrupteur bascule.
  ///
  /// Sans ça, cocher « ce groupe est un ministère » laisserait « Standard »
  /// sélectionné et l'enregistrement partirait se faire refuser par la base.
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
        // SECTEUR — public ou privé, et rien d'autre. L'école en hérite
        // (0060) et le barème de frais en dépend.
        'group_type':   _groupType,
        // CARACTÈRE — descriptif, indépendant du secteur (0180). Remis à
        // `null` si le groupe repasse en public : un établissement public n'a
        // pas de caractère propre, et laisser l'ancienne valeur en base ferait
        // réapparaître « Catholique » sur un groupe devenu public.
        'caractere':    caractereSeSaisit(_groupType) ? _caractere : null,
        // ⚠️ La tutelle est écrite SUR LE GROUPE, jamais sur l'école : un
        // déclencheur (migration 0153) la propage à toutes ses écoles. Envoyer
        // `schools.tutelle` depuis ici serait écrire dans une copie.
        'tutelle':      _tutelle,
        // ⚠️ Le rôle de tutelle, pas un réglage d'affichage : il ouvre le
        // référentiel national, le réseau du ministère et les circulaires.
        // La base n'en accepte qu'un par ministère (index unique, 0178) et
        // refuse le second avec une phrase écrite pour l'agent.
        'administre_referentiel_national': _estTutelle,
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 36),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 40, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [const Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.domain_add_rounded,
                  color: Colors.white, size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEdit ? 'Modifier le groupe' : 'Nouveau groupe scolaire',
                  style: TextStyle(color: _kText, fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  isEdit ? 'Mise à jour des informations'
                      : 'Remplissez les champs requis',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ]),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                mouseCursor: SystemMouseCursors.click,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),

          // ── Body — colonne unique scrollable ───────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─ IDENTITÉ ─────────────────────────────────────────
                    const _FormLabel('IDENTITÉ DU GROUPE'),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── Logo upload ──────────────────────────────────
                      _LogoUploadBox(
                        name: _name.text.isNotEmpty ? _name.text : 'G',
                        logoUrl: _uploadedLogoUrl,
                        previewBytes: _logoPreviewBytes,
                        uploading: _uploadingLogo,
                        onPick: _pickAndUploadLogo,
                        onRemove: () => setState(() {
                          _uploadedLogoUrl = null;
                          _logoPreviewBytes = null;
                        }),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _name,
                            onChanged: (_) => setState(() {}),
                            decoration: _inputDeco('Nom complet du groupe *'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 8),
                          // Année de création
                          TextFormField(
                            controller: _foundedYearCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: _inputDeco('Année de création (ex : 1998)').copyWith(
                              prefixIcon: Icon(Icons.calendar_today_rounded,
                                  size: 15, color: _kMuted),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final y = int.tryParse(v);
                              if (y == null || y < 1800 || y > DateTime.now().year) {
                                return 'Année invalide';
                              }
                              return null;
                            },
                          ),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: _groupType,
                        decoration: _inputDeco('Secteur *'),
                        items: kSecteursGroupe.map((code) => DropdownMenuItem(
                            value: code,
                            child: Row(children: [
                              Icon(_typeIcon(code), size: 15, color: _kNavy),
                              const SizedBox(width: 8),
                              Text(libelleSecteur(code)),
                            ]))).toList(),
                        onChanged: (v) => setState(() => _groupType = v!),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String?>(
                        initialValue: _department,
                        decoration: _inputDeco('Département'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Aucun —')),
                          ..._depts.map((d) =>
                              DropdownMenuItem(value: d, child: Text(d))),
                        ],
                        onChanged: (v) => setState(() => _department = v),
                      )),
                    ]),

                    // ── CARACTÈRE ──────────────────────────────────────
                    // ⚠️ Un champ à part, et pas une valeur de plus dans le
                    // secteur : une école catholique EST une école privée.
                    // Les deux informations sont vraies en même temps, et
                    // c'est faute d'avoir ce champ que « Catholique » s'était
                    // posé dans celui du secteur — où la base le refusait.
                    // Proposé sur un groupe PRIVÉ seulement : un établissement
                    // public n'a pas de caractère propre.
                    if (caractereSeSaisit(_groupType)) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue:
                            caractereConnu(_caractere) ? _caractere : null,
                        decoration: _inputDeco('Caractère du groupe'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Non renseigné —')),
                          ...kCaracteresGroupe.map((code) => DropdownMenuItem(
                                value: code,
                                child: Text(libelleCaractere(code) ?? code),
                              )),
                        ],
                        onChanged: (v) => setState(() => _caractere = v),
                      ),
                    ],

                    const _FormDivider(),

                    // ─ TUTELLE ────────────────────────────────────────
                    const _FormLabel('MINISTÈRE DE TUTELLE'),
                    _TutelleSelector(
                      value: _tutelle,
                      onChanged: (v) => setState(() => _tutelle = v),
                      ecolesConcernees: widget.existing?.schoolCount ?? 0,
                      valeurInitiale: widget.existing?.tutelle,
                    ),

                    const SizedBox(height: 12),
                    _RoleDeTutelle(
                      actif: _estTutelle,
                      tutelle: _tutelle,
                      detenteur: detenteurDuRoleDeTutelle(
                        widget.groupes, _tutelle,
                        saufId: widget.existing?.id,
                      ),
                      valeurInitiale:
                          widget.existing?.administreReferentielNational ??
                              false,
                      onChanged: (v) => setState(() {
                        _estTutelle = v;
                        _alignerLePlan();
                      }),
                    ),

                    _AgrementFields(
                      numero: _agrementNum,
                      type: _agrementType,
                      date: _agrementDate,
                      onType: (v) => setState(() => _agrementType = v),
                      onDate: (v) => setState(() => _agrementDate = v),
                    ),

                    const _FormDivider(),

                    // ─ CONTACT ─────────────────────────────────────────
                    const _FormLabel('CONTACT'),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('Email administrateur *'),
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Champ requis';
                          if (!v!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _phone,
                        decoration: _inputDeco('Téléphone'),
                        keyboardType: TextInputType.phone,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: _inputDeco('Adresse complète'),
                      maxLines: 2,
                    ),

                    const _FormDivider(),

                    // ─ ABONNEMENT ─────────────────────────────────────
                    const _FormLabel("PLAN D'ABONNEMENT"),
                    DropdownButtonFormField<String>(
                      initialValue: _planId,
                      decoration: _inputDeco('Plan *'),
                      items: _plansOfferts.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _planDotColor(p.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(p.name, style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            p.priceXaf == 0
                                ? 'Gratuit'
                                : '${_fmtXaf(p.priceXaf.toDouble())}/${p.periodSuffix}',
                            style: TextStyle(
                                color: _kMuted, fontSize: 12),
                          ),
                        ]),
                      )).toList(),
                      onChanged: (v) => setState(() => _planId = v),
                      validator: (v) =>
                          v == null ? 'Sélectionner un plan' : null,
                    ),
                    PlanChangeNotice(
                      existing: widget.existing,
                      plans: _plansOfferts,
                      selectedPlanId: _planId,
                    ),

                    const _FormDivider(),

                    // ─ NOTES ──────────────────────────────────────────
                    const _FormLabel('NOTES INTERNES'),
                    TextFormField(
                      controller: _notes,
                      decoration: _inputDeco(
                          'Remarques, contexte, historique…'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer — sorti dans son propre widget : le `build` du modal
          // dépassait 300 lignes, et le pied de page n'a besoin que de trois
          // choses pour se dessiner.
          _GroupFormFooter(isEdit: isEdit, saving: _saving, onSave: _save),
        ]),
      ),
    );
  }
}
