import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/stage_actions.dart';
import '../providers/stages_provider.dart';
import 'stage_student_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  NOUVEAU STAGE — le formulaire qui manquait.
//
//  Ce qu'il produit mène à l'attestation, et l'attestation est une pièce du
//  dossier du baccalauréat. D'où deux partis pris :
//
//   • Le STATUT n'est pas demandé. Il se déduit des dates (statusFromDates).
//     Un agent qui saisit un stage de mars n'a aucune raison de cocher
//     « terminé » — et l'oublierait, ce qui masquerait l'alerte d'attestation.
//   • Seuls l'ÉLÈVE et l'ENTREPRISE sont exigés. Tout le reste peut arriver
//     plus tard : refuser un stage faute de date de fin, c'est empêcher
//     d'enregistrer ce que l'école sait déjà.
// ════════════════════════════════════════════════════════════════════════════

Future<bool> showStageFormDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _StageFormDialog(),
    ) ??
    false;

class _StageFormDialog extends ConsumerStatefulWidget {
  const _StageFormDialog();

  @override
  ConsumerState<_StageFormDialog> createState() => _State();
}

class _State extends ConsumerState<_StageFormDialog> {
  StagiaireCandidate? _student;
  String? _companyId;
  final _title = TextEditingController();
  final _tutorName = TextEditingController();
  final _tutorPhone = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  DateTime? _conventionAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _tutorName.dispose();
    _tutorPhone.dispose();
    super.dispose();
  }

  bool get _valid => _student != null && _companyId != null;

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Nouveau stage',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
      content: SizedBox(
        width: 480,
        // shrinkWrap : un modal-form s'ajuste au contenu, jamais pleine hauteur
        // (convention du projet).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StageStudentPicker(
                value: _student,
                onChanged: (s) => setState(() => _student = s),
              ),
              const SizedBox(height: 14),
              companies.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
                data: (list) => _CompanyField(
                  companies: list,
                  value: _companyId,
                  onChanged: (id) => setState(() => _companyId = id),
                  onCreated: (id) {
                    ref.invalidate(companiesProvider);
                    setState(() => _companyId = id);
                  },
                ),
              ),
              const SizedBox(height: 14),
              _Text(_title, 'Intitulé du stage',
                  hint: 'ex. Stage en atelier de soudure'),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _DateField(
                    label: 'Début',
                    value: _start,
                    onPick: (d) => setState(() => _start = d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'Fin',
                    value: _end,
                    onPick: (d) => setState(() => _end = d),
                  ),
                ),
              ]),
              if (_start != null) ...[
                const SizedBox(height: 8),
                _StatusHint(status: statusFromDates(_start, _end)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Text(_tutorName, 'Tuteur en entreprise')),
                const SizedBox(width: 10),
                Expanded(child: _Text(_tutorPhone, 'Téléphone')),
              ]),
              const SizedBox(height: 14),
              _DateField(
                label: 'Convention signée le',
                value: _conventionAt,
                onPick: (d) => setState(() => _conventionAt = d),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || !_valid ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(_saving ? 'Enregistrement…' : 'Créer le stage'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      setState(() => _error = 'La fin ne peut pas précéder le début.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await createInternship(
        ref,
        studentId: _student!.studentId,
        classId: _student!.classId,
        academicYearId: _student!.academicYearId,
        companyId: _companyId,
        title: _title.text,
        startDate: _start,
        endDate: _end,
        companyTutorName: _tutorName.text,
        companyTutorPhone: _tutorPhone.text,
        conventionSignedAt: _conventionAt,
      );
      if (id == null) {
        setState(() => _error = 'Session incomplète — stage non enregistré.');
        return;
      }
      ref.invalidate(stagesOverviewProvider);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Rendre visible la déduction, plutôt que de la laisser surprendre l'agent.
class _StatusHint extends StatelessWidget {
  const _StatusHint({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'en_cours' => 'En cours',
      'termine' => 'Terminé',
      _ => 'Prévu',
    };
    return Row(children: [
      Icon(Icons.auto_awesome_rounded, size: 13, color: kTextMuted),
      const SizedBox(width: 6),
      Text('Statut déduit des dates : $label',
          style: TextStyle(fontSize: 11, color: kTextMuted)),
    ]);
  }
}

class _CompanyField extends StatelessWidget {
  const _CompanyField({
    required this.companies,
    required this.value,
    required this.onChanged,
    required this.onCreated,
  });

  final List<CompanyRow> companies;
  final String? value;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Entreprise *',
              border: const OutlineInputBorder(),
              isDense: true,
              labelStyle: TextStyle(color: kTextMuted),
            ),
            style: TextStyle(fontSize: 13, color: kTextPrimary),
            items: [
              for (final c in companies)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${c.name}${c.sector != null ? ' · ${c.sector}' : ''}'
                    '${c.isShared ? ' · groupe' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () async {
            final id = await showCompanyDialog(context);
            if (id != null) onCreated(id);
          },
          icon: const Icon(Icons.add_business_rounded, size: 18),
          tooltip: 'Nouvelle entreprise',
        ),
      ]);
}

// ── Création d'entreprise ───────────────────────────────────────────────────

Future<String?> showCompanyDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _CompanyDialog(),
    );

class _CompanyDialog extends ConsumerStatefulWidget {
  const _CompanyDialog();

  @override
  ConsumerState<_CompanyDialog> createState() => _CompanyState();
}

class _CompanyState extends ConsumerState<_CompanyDialog> {
  final _name = TextEditingController();
  final _sector = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  bool _shared = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _sector, _address, _contact, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Nouvelle entreprise',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Text(_name, 'Nom *', hint: 'ex. SOTEC'),
              const SizedBox(height: 12),
              _Text(_sector, 'Secteur', hint: 'ex. Métallurgie'),
              const SizedBox(height: 12),
              _Text(_address, 'Adresse'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Text(_contact, 'Contact')),
                const SizedBox(width: 10),
                Expanded(child: _Text(_phone, 'Téléphone')),
              ]),
              const SizedBox(height: 8),
              // Par défaut PARTAGÉE : les écoles d'un même groupe envoient leurs
              // élèves chez les mêmes employeurs. Re-saisir « SOTEC » par école
              // produirait des doublons impossibles à recouper.
              SwitchListTile(
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kGreen,
                title: Text('Partagée avec tout le groupe',
                    style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
                subtitle: Text(
                  _shared
                      ? 'Les autres écoles du groupe pourront l\'utiliser.'
                      : 'Visible par cette école seulement.',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            child: Text(_saving ? 'Création…' : 'Créer'),
          ),
        ],
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await createCompany(
        ref,
        name: _name.text,
        sector: _sector.text,
        address: _address.text,
        contactName: _contact.text,
        contactPhone: _phone.text,
        shared: _shared,
      );
      if (mounted) Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Champs ──────────────────────────────────────────────────────────────────

class _Text extends StatelessWidget {
  const _Text(this.controller, this.label, {this.hint});
  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          labelStyle: TextStyle(color: kTextMuted),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? label
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 2),
          helpText: label,
        );
        if (d != null) onPick(d);
      },
      icon: Icon(Icons.event_rounded, size: 15, color: kTextMuted),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: value == null ? kTextMuted : kTextPrimary)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      ),
    );
  }
}
