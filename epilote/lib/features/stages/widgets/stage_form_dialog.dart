import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/stage_detail.dart';
import '../providers/stage_actions.dart';
import '../providers/stages_provider.dart';
import '../../../core/utils/date_scolaire.dart';
import 'stage_student_picker.dart';

part 'stage_form_fields.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIR OU CORRIGER UN STAGE
//
//  ── CE QUI MANQUAIT (2026-08-30) ──────────────────────────────────────────
//  Ce formulaire ne savait que CRÉER. `updateInternship` existait, complète,
//  et n'avait aucun appelant : un stage saisi de travers — mauvaise entreprise,
//  dates inversées, téléphone du tuteur erroné — était DÉFINITIF. L'agent
//  n'avait d'autre recours que d'en créer un second, et l'école se retrouvait
//  avec deux stages pour un élève.
//
//  Et ce qui sort d'ici mène à l'attestation, pièce du dossier du bac
//  technique : une date fausse y reste fausse jusqu'au jury.
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

/// Ouvre le formulaire. [stage] non nul = CORRECTION d'un stage existant.
Future<bool> showStageFormDialog(BuildContext context,
        {StageDetail? stage}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _StageFormDialog(stage: stage),
    ) ??
    false;

class _StageFormDialog extends ConsumerStatefulWidget {
  const _StageFormDialog({this.stage});

  /// `null` en création.
  final StageDetail? stage;

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

  bool get _correction => widget.stage != null;

  @override
  void initState() {
    super.initState();
    final d = widget.stage;
    if (d == null) return;
    // ⚠️ L'ÉLÈVE ne se change pas. Déplacer un stage d'un élève à un autre
    // n'est pas une correction, c'est un autre stage — et l'attestation déjà
    // délivrée porterait le nom du premier. Le formulaire l'affiche, il ne le
    // propose pas.
    _companyId = d.companyId;
    _title.text = d.title ?? '';
    _tutorName.text = d.companyTutorName ?? '';
    _tutorPhone.text = d.companyTutorPhone ?? '';
    _start = d.startDate;
    _end = d.endDate;
    _conventionAt = d.conventionSignedAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _tutorName.dispose();
    _tutorPhone.dispose();
    super.dispose();
  }

  bool get _valid =>
      (_correction || _student != null) && _companyId != null;

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_correction ? 'Corriger le stage' : 'Nouveau stage',
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
              if (_correction)
                _EleveFige(nom: widget.stage!.studentName,
                    classe: widget.stage!.className)
              else
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
          child: Text(_saving
              ? 'Enregistrement…'
              : _correction
                  ? 'Enregistrer les corrections'
                  : 'Créer le stage'),
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
      // ── Correction ────────────────────────────────────────────────────────
      if (_correction) {
        // Le statut n'est pas demandé : il se REDÉDUIT des dates corrigées.
        // C'est le même parti pris qu'à la création, et c'est ce qu'on veut —
        // corriger une date de fin doit faire passer le stage de « en cours »
        // à « terminé », sinon l'alerte d'attestation resterait muette.
        await updateInternship(
          widget.stage!.id,
          companyId: _companyId,
          title: _title.text,
          startDate: _start,
          endDate: _end,
          companyTutorName: _tutorName.text,
          companyTutorPhone: _tutorPhone.text,
          conventionSignedAt: _conventionAt,
        );
        ref.invalidate(stagesOverviewProvider);
        ref.invalidate(stageDetailProvider(widget.stage!.id));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

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

