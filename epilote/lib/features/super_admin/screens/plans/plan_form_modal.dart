part of '../plans_screen.dart';

// Formulaire de formule.

class _PlanFormModal extends ConsumerStatefulWidget {
  const _PlanFormModal({this.editing});
  final PlanDetail? editing;
  @override
  ConsumerState<_PlanFormModal> createState() => _PlanFormModalState();
}

class _PlanFormModalState extends ConsumerState<_PlanFormModal> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _priceCtrl     = TextEditingController();
  final _t2a5Ctrl      = TextEditingController(text: '0');
  final _t6a10Ctrl     = TextEditingController(text: '0');
  final _t11a20Ctrl    = TextEditingController(text: '0');
  final _t21pCtrl      = TextEditingController(text: '0');
  final _maxSchoolsCtrl= TextEditingController();
  final _maxStudentsCtrl=TextEditingController();
  final _maxStaffCtrl  = TextEditingController();
  final _descCtrl      = TextEditingController();

  String  _slug      = 'premium';
  String  _period    = kDefaultBillingPeriod;
  bool    _isPublic  = false;
  bool    _isActive  = true;
  bool    _saving    = false;
  Set<String> _selectedModules = {};
  bool    _loadingModules = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    if (p != null) {
      _nameCtrl.text        = p.name;
      _priceCtrl.text       = p.priceXaf.toString();
      _t2a5Ctrl.text        = p.extra2a5.toString();
      _t6a10Ctrl.text       = p.extra6a10.toString();
      _t11a20Ctrl.text      = p.extra11a20.toString();
      _t21pCtrl.text        = p.extra21p.toString();
      _maxSchoolsCtrl.text  = p.maxSchools.toString();
      _maxStudentsCtrl.text = p.maxStudents.toString();
      _maxStaffCtrl.text    = p.maxStaff.toString();
      _descCtrl.text        = p.description ?? '';
      _slug                 = p.slug;
      _period               = p.billingPeriod;
      _isPublic             = p.isPublicPlan;
      _isActive             = p.isActive;
      _loadingModules       = true;
      fetchPlanModuleIds(ref, p.id).then((ids) {
        if (mounted) setState(() { _selectedModules = ids; _loadingModules = false; });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _t2a5Ctrl.dispose();
    _t6a10Ctrl.dispose();
    _t11a20Ctrl.dispose();
    _t21pCtrl.dispose();
    _maxSchoolsCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _maxStaffCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseInt(String s, {int fallback = 0}) =>
      int.tryParse(s.trim().replaceAll(' ', '')) ?? fallback;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':           _nameCtrl.text.trim(),
        'slug':           _slug,
        'price_xaf':      _parseInt(_priceCtrl.text),
        // Les quatre tranches : c'est ici que se décide le prix de TOUS les
        // clients du plan au-delà de leur première école.
        'extra_school_2_5_xaf':   _parseInt(_t2a5Ctrl.text),
        'extra_school_6_10_xaf':  _parseInt(_t6a10Ctrl.text),
        'extra_school_11_20_xaf': _parseInt(_t11a20Ctrl.text),
        'extra_school_21p_xaf':   _parseInt(_t21pCtrl.text),
        'max_schools':    _parseInt(_maxSchoolsCtrl.text),
        'max_students':   _parseInt(_maxStudentsCtrl.text),
        'max_staff':      _parseInt(_maxStaffCtrl.text),
        'billing_period': _period,
        // `module_count` n'est PAS envoyé : depuis la migration 0076 il est
        // recalculé par trigger à partir de `plan_modules`. Deux écrivains pour
        // un même fait, c'était la dérive garantie — le plan « pro » annonçait
        // 26 modules et en donnait 28.
        'description':    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'is_public_plan': _isPublic,
        'is_active':      _isActive,
        'updated_at':     DateTime.now().toIso8601String(),
      };

      String planId;
      if (_isEditing) {
        await client.from('subscription_plans')
            .update(payload).eq('id', widget.editing!.id);
        planId = widget.editing!.id;
        await client.from('plan_modules').delete().eq('plan_id', planId);
      } else {
        final inserted = await client.from('subscription_plans')
            .insert(payload).select('id').single();
        planId = inserted['id'] as String;
      }

      if (_selectedModules.isNotEmpty) {
        await client.from('plan_modules').insert(
          _selectedModules.map((mid) => {
            'plan_id':   planId,
            'module_id': mid,
          }).toList(),
        );
      }

      ref.invalidate(plansProvider);
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

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(plansProvider).valueOrNull?.modules ?? const [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(
                  _isEditing ? Icons.edit_rounded : Icons.add_rounded,
                  color: Colors.white, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEditing ? 'Modifier le plan' : 'Nouveau plan',
                  style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  _isEditing ? 'Mise à jour de la tarification' : 'Définissez tarifs et quotas',
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
          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom du plan *',
                    icon: Icons.inventory_2_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Type & Visibilité'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _slug,
                        isExpanded: true,
                        icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: TextStyle(color: _kText, fontSize: 13),
                        items: _slugLabels.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(_slugIcon(e.key), size: 14, color: _slugColor(e.key)),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _slug = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Le tarif et sa durée vont ensemble : un montant sans période
                  // ne veut rien dire, et c'est exactement l'ambiguïté qui
                  // faisait facturer un « prix mensuel » pour douze mois.
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 3,
                      child: _FormField(
                        controller: _priceCtrl,
                        label: 'Tarif (FCFA) *',
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        hint: '0 = gratuit',
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            int.tryParse(v!.trim().replaceAll(' ', '')) == null
                                ? 'Nombre requis'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: PlanPeriodPicker(
                      value: _period,
                      onChanged: (v) => setState(() => _period = v),
                    )),
                  ]),
                  const SizedBox(height: 6),
                  PlanPriceEquivalence(
                      priceXaf: _parseInt(_priceCtrl.text), period: _period),
                  const SizedBox(height: 14),
                  _TranchesEcoles(
                    base: _parseInt(_priceCtrl.text),
                    period: _period,
                    t2a5: _t2a5Ctrl,
                    t6a10: _t6a10Ctrl,
                    t11a20: _t11a20Ctrl,
                    t21p: _t21pCtrl,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Quotas & Limites'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _FormField(
                      controller: _maxSchoolsCtrl,
                      label: 'Écoles max *',
                      icon: Icons.school_rounded,
                      keyboardType: TextInputType.number,
                      hint: '-1 = illimité',
                      validator: validatePlanQuota,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _FormField(
                      controller: _maxStudentsCtrl,
                      label: 'Élèves max *',
                      icon: Icons.groups_rounded,
                      keyboardType: TextInputType.number,
                      hint: '-1 = illimité',
                      validator: validatePlanQuota,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _maxStaffCtrl,
                    label: 'Personnel max *',
                    icon: Icons.badge_rounded,
                    keyboardType: TextInputType.number,
                    hint: '-1 = illimité',
                    validator: validatePlanQuota,
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Modules inclus (${_selectedModules.length})'),
                  const SizedBox(height: 10),
                  _ModulePickerBox(
                    modules: modules,
                    selected: _selectedModules,
                    loading: _loadingModules,
                    onToggle: (id) => setState(() {
                      if (_selectedModules.contains(id)) {
                        _selectedModules.remove(id);
                      } else {
                        _selectedModules.add(id);
                      }
                    }),
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _descCtrl,
                    label: 'Description (optionnel)',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Disponibilité'),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    icon: Icons.public_rounded,
                    label: 'Plan public',
                    sub: 'Visible lors de l\'inscription',
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  _SwitchRow(
                    icon: Icons.check_circle_rounded,
                    label: 'Plan actif',
                    sub: 'Disponible à la souscription',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Annuler', style: TextStyle(
                        color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        _saving ? 'Enregistrement…'
                            : (_isEditing ? 'Enregistrer' : 'Créer le plan'),
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
