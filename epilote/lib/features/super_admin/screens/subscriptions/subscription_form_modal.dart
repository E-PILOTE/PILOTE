import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/subscriptions_provider.dart';
import 'subs_form_fields.dart';
import 'subs_style.dart';

// ─── Modal de modification ──────────────────────────────────────────
//  Il MODIFIE l'abonnement d'un groupe existant — il ne le crée pas : il ne
//  demande ni tutelle, ni agrément, ni secteur, et un groupe amputé de sa
//  tutelle n'apparaît dans le réseau d'aucun ministère (0155, 0158).

class SubFormModal extends ConsumerStatefulWidget {
  const SubFormModal({super.key, this.editing});
  final SubscriptionDetail? editing;
  @override
  ConsumerState<SubFormModal> createState() => _SubFormModalState();
}

class _SubFormModalState extends ConsumerState<SubFormModal> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _deptCtrl   = TextEditingController();

  String    _groupType = 'prive';
  String    _status    = 'trial';
  String?   _planId;
  DateTime? _start;
  DateTime? _end;
  bool      _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.editing;
    if (s != null) {
      _nameCtrl.text  = s.groupName;
      _emailCtrl.text = s.adminEmail;
      _phoneCtrl.text = s.phone ?? '';
      _deptCtrl.text  = s.department ?? '';
      _groupType      = s.groupType;
      _status         = s.status;
      _planId         = s.planId;
      _start          = s.start;
      _end            = s.end;
    } else {
      _start = DateTime.now();
      _end   = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() { if (isStart) { _start = picked; } else { _end = picked; } });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':                _nameCtrl.text.trim(),
        'admin_email':         _emailCtrl.text.trim(),
        'phone':               _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'department':          _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
        'group_type':          _groupType,
        'plan_id':             _planId,
        'subscription_status': _status,
        'subscription_start':  _start?.toIso8601String(),
        'subscription_end':    _end?.toIso8601String(),
        'is_active':           _status == 'active' || _status == 'trial',
        'updated_at':          DateTime.now().toIso8601String(),
      };

      // Ce formulaire MODIFIE l'abonnement d'un groupe existant. Il ne le crée
      // pas : il ne demande ni la tutelle, ni l'agrément, ni le secteur, et un
      // groupe amputé de sa tutelle n'apparaît dans le réseau d'aucun ministère.
      if (!_isEditing) {
        throw StateError(
            'Ce formulaire ne crée pas de groupe : passer par « Groupes '
            'Scolaires », seul endroit qui demande la tutelle.');
      }
      await client.from('school_groups')
          .update(payload).eq('id', widget.editing!.id);

      ref.invalidate(subscriptionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cleanDbError(e)),
        backgroundColor: kSubRed,
        behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(subscriptionsProvider).valueOrNull?.plans ?? const [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: kSubBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: kSubBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), kSubNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: kSubNavy.withValues(alpha: 0.25),
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
                  _isEditing ? 'Modifier l\'abonnement' : 'Nouvel abonnement',
                  style: TextStyle(color: kSubText, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Mise à jour du groupe scolaire',
                  style: TextStyle(color: kSubMuted, fontSize: 11),
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
                    color: kSubSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kSubBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 15, color: kSubMuted),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SubFormField(
                    controller: _nameCtrl,
                    label: 'Nom du groupe *',
                    icon: Icons.business_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  SubFormField(
                    controller: _emailCtrl,
                    label: 'E-mail administrateur *',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: SubFormField(
                      controller: _phoneCtrl,
                      label: 'Téléphone',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: SubFormField(
                      controller: _deptCtrl,
                      label: 'Département',
                      icon: Icons.location_on_rounded,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  const SubFormSectionTitle('Type d\'établissement'),
                  const SizedBox(height: 10),
                  SubFormDropdown<String>(
                    value: _groupType,
                    icon: subTypeIcon(_groupType),
                    items: const {'public': 'Public', 'prive': 'Privé'},
                    onChanged: (v) => setState(() => _groupType = v),
                  ),
                  const SizedBox(height: 14),
                  const SubFormSectionTitle('Plan d\'abonnement'),
                  const SizedBox(height: 10),
                  SubPlanDropdown(
                    plans: plans,
                    value: _planId,
                    onChanged: (v) => setState(() => _planId = v),
                  ),
                  const SizedBox(height: 14),
                  const SubFormSectionTitle('Statut'),
                  const SizedBox(height: 10),
                  SubFormDropdown<String>(
                    value: _status,
                    icon: subStatusIcon(_status),
                    iconColor: subStatusColor(_status),
                    items: const {
                      'trial':     'Essai',
                      'active':    'Actif',
                      'suspended': 'Suspendu',
                      'expired':   'Expiré',
                      'cancelled': 'Annulé',
                    },
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 14),
                  const SubFormSectionTitle('Période d\'abonnement'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: SubDateField(
                      label: 'Début',
                      value: _start,
                      onTap: () => _pickDate(isStart: true),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: SubDateField(
                      label: 'Fin',
                      value: _end,
                      onTap: () => _pickDate(isStart: false),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: BoxDecoration(
              color: kSubSurface,
              border: Border(top: BorderSide(color: kSubBorder)),
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
                      border: Border.all(color: kSubBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Annuler', style: TextStyle(
                        color: kSubMuted, fontSize: 13, fontWeight: FontWeight.w600)),
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
                      color: _saving ? kSubNavy.withValues(alpha: 0.5) : kSubNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: kSubNavy.withValues(alpha: 0.30),
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
                            : (_isEditing ? 'Enregistrer' : 'Créer l\'abonnement'),
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
