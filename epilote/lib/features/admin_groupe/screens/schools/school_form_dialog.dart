part of '../admin_schools_screen.dart';

// Formulaire école (création / édition)

// ─── Form dialog école (style Groupe Scolaire) ────────────────────────────────

class SchoolFormDialog extends ConsumerStatefulWidget {
  const SchoolFormDialog({super.key, this.school});
  final SchoolDetail? school;

  @override
  ConsumerState<SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends ConsumerState<SchoolFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _arrondissement;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _founded;
  late final TextEditingController _capacity;
  late final TextEditingController _motto;
  String  _type       = 'prive';

  /// Type d'établissement (CEG, CET, lycée technique…). ⚠️ Rien à voir avec
  /// [_type], qui est le statut juridique public/privé.
  String? _institutionTypeId;
  String? _department;
  bool    _saving     = false;
  String? _error;

  // ── Géolocalisation : contrôleur pont formulaire (cascade) ↔ carte ──
  SchoolLocation? _initialLoc;
  late final SchoolLocationController _locCtrl;
  final _cityFocus = FocusNode();

  // ── Logo de l'école ──
  String?    _logoUrl;
  Uint8List? _logoPreviewBytes;
  bool       _uploadingLogo = false;

  // ── Offre éducative : déléguée à `SchoolEducationSection` ──
  final _eduCtrl = SchoolEducationController();

  late final AnimationController _btnCtrl;
  late final Animation<double>   _btnScale;
  bool _btnHov = false;

  bool get _isEdit => widget.school != null;

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _name           = TextEditingController(text: s?.name ?? '');
    _code           = TextEditingController(text: s?.code ?? '');
    _city           = TextEditingController(text: s?.city ?? '');
    _province       = TextEditingController(text: s?.province ?? '');
    _arrondissement = TextEditingController(text: s?.arrondissement ?? '');
    _address        = TextEditingController(text: s?.address ?? '');
    _phone          = TextEditingController(text: s?.phone ?? '');
    _email          = TextEditingController(text: s?.email ?? '');
    _website        = TextEditingController(text: s?.website ?? '');
    _founded        = TextEditingController(text: s?.foundedYear?.toString() ?? '');
    _capacity       = TextEditingController(text: s?.capacity?.toString() ?? '');
    _motto          = TextEditingController(text: s?.motto ?? '');
    _logoUrl        = s?.logoUrl;
    _type = s?.type ?? 'prive';
    _institutionTypeId = s?.institutionTypeId;
    _department = (s?.department != null && _kDepartements.contains(s!.department))
        ? s.department
        : null;
    if (s != null && s.hasGps) {
      _initialLoc = SchoolLocation(
        lat: s.latitude!, lng: s.longitude!,
        source: s.locationSource ?? 'manual');
    }
    _locCtrl = SchoolLocationController(_initialLoc);
    _btnCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(_btnCtrl);

  }

  @override
  void dispose() {
    for (final c in [_name, _code, _city, _province, _arrondissement,
                     _address, _phone, _email, _website, _founded, _capacity, _motto]) {
      c.dispose();
    }
    _cityFocus.dispose();
    _locCtrl.dispose();
    _eduCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    // `FileType.custom` (et non `.image`) : le bucket n'accepte que ces formats
    // — un .gif/.bmp serait rejeté côté serveur avec un message opaque.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kSchoolLogoExts,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final srcExt = (file.extension ?? 'png').toLowerCase();
      // Compression AVANT upload : redimensionne ≤512 px et ré-encode.
      final media = await compressLogo(
        bytes: file.bytes!,
        fileName: file.name,
        mime: schoolLogoMimeForExt(srcExt),
      );
      if (!mounted) return;
      setState(() => _logoPreviewBytes = media.bytes);

      final client = ref.read(supabaseClientProvider);
      final ext = media.fileName.split('.').last.toLowerCase();
      final path = 'schools/school_${DateTime.now().millisecondsSinceEpoch}.$ext';
      // Pas d'`upsert` : le nom est déjà unique (horodaté), et `upsert` force un
      // `ON CONFLICT DO UPDATE` qui exige un droit SELECT sur storage.objects →
      // rejet RLS 403 (c'était la cause du bug d'upload).
      await client.storage.from('group-logos').uploadBinary(
        path,
        media.bytes,
        fileOptions: FileOptions(
          contentType: media.mime,
          cacheControl: '86400',
        ),
      );
      final url = client.storage.from('group-logos').getPublicUrl(path);
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        setState(() => _logoPreviewBytes = null);
        _eduSnack(messageErreur(e, contexte: 'Envoi du logo'), error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Le secteur d'une école suit TOUJOURS celui de son groupe (public XOR
    // privé) — il n'est pas saisi. La base le verrouille (migration 0060) ;
    // on envoie la valeur héritée pour rester cohérent côté client.
    _type = ref.read(adminSchoolsProvider).valueOrNull?.groupType ?? _type;
    setState(() { _saving = true; _error = null; });
    try {
      final svc    = ref.read(adminSchoolsServiceProvider);
      final eduSvc = ref.read(educationServiceProvider);
      final year   = int.tryParse(_founded.text.trim());
      final cap    = int.tryParse(_capacity.text.trim());
      final String schoolId;
      if (_isEdit) {
        await svc.update(
          id: widget.school!.id,
          name: _name.text.trim(), type: _type, code: _code.text.trim(),
          address: _address.text.trim(), city: _city.text.trim(),
          province: _province.text.trim(), arrondissement: _arrondissement.text.trim(),
          department: _department, phone: _phone.text.trim(),
          email: _email.text.trim(), website: _website.text.trim(),
          motto: _motto.text.trim(), foundedYear: year, logoUrl: _logoUrl,
          capacity: cap, institutionTypeId: _institutionTypeId,
        );
        schoolId = widget.school!.id;
      } else {
        schoolId = await svc.create(
          name: _name.text.trim(), type: _type, code: _code.text.trim(),
          address: _address.text.trim(), city: _city.text.trim(),
          province: _province.text.trim(), arrondissement: _arrondissement.text.trim(),
          department: _department, phone: _phone.text.trim(),
          email: _email.text.trim(), website: _website.text.trim(),
          motto: _motto.text.trim(), foundedYear: year, logoUrl: _logoUrl,
          capacity: cap, institutionTypeId: _institutionTypeId,
        );
      }
      await _persistLocation(schoolId);
      // Enregistrer l'offre éducative (cycles / filières / niveaux).
      await eduSvc.saveSchoolEducation(
        schoolId: schoolId,
        cycleIds: _eduCtrl.cycleIds,
        levelIds: _eduCtrl.levelIds,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'École mise à jour' : 'École créée avec succès'),
        ));
      }
    } catch (e) {
      setState(() { _error = '$e'; _saving = false; });
    }
  }

  /// Persiste la position selon le sélecteur cartographique. Fail-soft : une
  /// erreur de géolocalisation ne doit jamais faire échouer l'école elle-même.
  Future<void> _persistLocation(String schoolId) async {
    final gps = ref.read(adminProjectServiceProvider);
    final loc = _locCtrl.value;
    try {
      if (loc != null) {
        // N'écrit que si la position a changé (évite un patch inutile en édition).
        if (loc != _initialLoc) {
          await gps.patchSchoolGps(
            schoolId: schoolId,
            latitude: loc.lat,
            longitude: loc.lng,
            source: loc.source,
          );
        }
      } else if (_isEdit) {
        // L'utilisateur a retiré la position d'une école qui en avait une.
        if (_initialLoc != null) await gps.clearSchoolGps(schoolId);
      } else {
        // Création sans repère : repli géocodage auto via la ville (approximatif),
        // corrigeable ensuite sur la carte. Préserve le comportement historique.
        final places = await ref.read(congoPlacesProvider.future);
        final coords = geocodeCity(places, _city.text.trim());
        if (coords != null) {
          await gps.patchSchoolGps(
            schoolId: schoolId,
            latitude: coords.latitude,
            longitude: coords.longitude,
            source: 'geocoded',
          );
        }
      }
    } catch (_) {
      // Fail-soft : position corrigeable via « Corriger la position » sur la carte.
    }
  }

  InputDecoration _inputDec(String hint) => schoolInputDec(hint);

  void _eduSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? kRed : kGreen,
      content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 36),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40, offset: const Offset(0, 10),
          )],
        ),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                    color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEdit ? 'Modifier l\'école' : 'Nouvelle école',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? 'Modifiez les informations de l\'établissement'
                      : 'Renseignez les informations du nouvel établissement',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ])),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
                ),
              ),
            ]),
          ),
          // ── Body ────────────────────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SchFormLabel('IDENTITÉ DE L\'ÉCOLE'),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SchoolLogoUploadBox(
                    name: _name.text.isNotEmpty ? _name.text : 'É',
                    logoUrl: _logoUrl,
                    previewBytes: _logoPreviewBytes,
                    uploading: _uploadingLogo,
                    onPick: _pickAndUploadLogo,
                    onRemove: () => setState(() {
                      _logoUrl = null;
                      _logoPreviewBytes = null;
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                        decoration: _inputDec('Nom de l\'établissement *'),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Expanded(child: SchoolSecteurHerite()),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _code,
                          decoration: _inputDec('Code établissement'),
                        )),
                      ]),
                    ],
                  )),
                ]),
                const _SchFormDivider(),
                SchoolInstitutionTypeField(
                  value: _institutionTypeId,
                  onChanged: (v) => setState(() => _institutionTypeId = v),
                ),
                const _SchFormDivider(),
                const _SchFormLabel('LOCALISATION'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    initialValue: _department,
                    isExpanded: true,
                    decoration: _inputDec('Département'),
                    items: _kDepartements.map((d) => DropdownMenuItem(
                      value: d, child: Text(d, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _department = v),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SchoolLocalityField(
                      department: _department,
                      city: _city,
                      cityFocus: _cityFocus,
                      location: _locCtrl,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _province,
                    decoration: _inputDec('Province'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _arrondissement,
                    decoration: _inputDec('Arrondissement / Quartier'),
                  )),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: _inputDec('Adresse complète'),
                ),
                const SizedBox(height: 18),
                const _SchFormLabel('POSITION SUR LA CARTE'),
                const SizedBox(height: 4),
                Text(
                  'Posez le repère précis de l\'établissement (facultatif). Une '
                  'position réelle alimente la carte territoriale, les distances '
                  'et les analyses d\'implantation.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                SchoolLocationField(
                  controller: _locCtrl,
                  cityName: () => _city.text,
                ),
                const _SchFormDivider(),
                SchoolContactSection(
                  phone: _phone, email: _email, website: _website,
                  founded: _founded, capacity: _capacity, motto: _motto,
                ),
                const _SchFormDivider(),
                SchoolEducationSection(
                  controller: _eduCtrl,
                  schoolId: widget.school?.id,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AdminErrorBanner(message: _error!),
                ],
              ]),
            ),
          )),
          // ── Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Annuler'),
                style: TextButton.styleFrom(foregroundColor: kTextMuted),
              ),
              const Spacer(),
              if (_saving)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [const Color(0xFF1A2F5A), kNavy],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text('Enregistrement…',
                        style: TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                )
              else
                _SchSaveBtn(
                  isEdit: _isEdit,
                  btnCtrl: _btnCtrl,
                  btnScale: _btnScale,
                  btnHov: _btnHov,
                  onHover: (h) => setState(() => _btnHov = h),
                  onTap: _submit,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

