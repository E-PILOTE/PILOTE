part of 'transferts_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Formulaire « Nouveau transfert » + fiche détail (avec workflow).
// ════════════════════════════════════════════════════════════════════════════

class _NewTransferDialog extends ConsumerStatefulWidget {
  const _NewTransferDialog();
  @override
  ConsumerState<_NewTransferDialog> createState() => _NewTransferDialogState();
}

class _NewTransferDialogState extends ConsumerState<_NewTransferDialog> {
  final _studentSearch = TextEditingController();
  final _toSchool = TextEditingController();
  final _reason = TextEditingController();
  String? _studentId;
  String _studentLabel = '';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _studentSearch.dispose();
    _toSchool.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Date du transfert',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    if (_studentId == null) {
      _err('Sélectionnez l\'élève à transférer');
      return;
    }
    if (_toSchool.text.trim().isEmpty) {
      _err('Indiquez l\'établissement de destination');
      return;
    }
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null) {
      _err('Profil incomplet');
      return;
    }
    setState(() => _saving = true);
    final yearId = ref.read(activeYearIdProvider);
    final ok = await runModuleWrite(
      context,
      () => createTransfer(
        groupId: groupId,
        fromSchoolId: schoolId,
        studentId: _studentId!,
        toSchoolName: _toSchool.text,
        transferDate: _date,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        academicYearId: yearId,
      ),
      success: 'Transfert enregistré (en attente d\'approbation)',
    );
    if (ok && mounted) Navigator.of(context).pop();
    if (mounted) setState(() => _saving = false);
  }

  void _err(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: kRed));

  @override
  Widget build(BuildContext context) {
    final candidates =
        ref.watch(transferCandidatesProvider).valueOrNull ?? const [];
    final q = _studentSearch.text.trim().toLowerCase();
    final filtered = _studentId != null
        ? const <TransferCandidate>[]
        : (q.isEmpty
            ? candidates.take(6).toList()
            : candidates
                .where((c) =>
                    c.fullName.toLowerCase().contains(q) ||
                    c.matricule.toLowerCase().contains(q))
                .take(8)
                .toList());

    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: 'Nouveau transfert',
      subtitle: 'Départ d\'un élève vers un autre établissement',
      saving: _saving,
      submitLabel: 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _FieldLabel('Élève à transférer'),
        if (_studentId == null) ...[
          TextField(
            controller: _studentSearch,
            onChanged: (_) => setState(() {}),
            decoration: adminFilledInput('Rechercher un élève actif…',
                icon: Icons.search_rounded),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucun élève correspondant.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted)),
            )
          else
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  for (var i = 0; i < filtered.length; i++)
                    _CandidateTile(
                      c: filtered[i],
                      last: i == filtered.length - 1,
                      onTap: () => setState(() {
                        _studentId = filtered[i].studentId;
                        _studentLabel =
                            '${filtered[i].fullName} · ${filtered[i].matricule}';
                      }),
                    ),
                ],
              ),
            ),
        ] else
          _SelectedStudent(
            label: _studentLabel,
            onClear: () => setState(() {
              _studentId = null;
              _studentLabel = '';
            }),
          ),
        const SizedBox(height: 16),
        const _FieldLabel('Établissement de destination'),
        TextField(
          controller: _toSchool,
          decoration: adminFilledInput('Nom de l\'école d\'accueil',
              icon: Icons.school_outlined),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Date du transfert'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              const Icon(Icons.event_outlined, size: 18, color: kTextMuted),
              const SizedBox(width: 10),
              Text(_fmtDate(_date),
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              const Spacer(),
              const Icon(Icons.edit_calendar_outlined,
                  size: 16, color: kTextMuted),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Motif (optionnel)'),
        TextField(
          controller: _reason,
          maxLines: 3,
          decoration: adminFilledInput('Raison du transfert…'),
        ),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile(
      {required this.c, required this.last, required this.onTap});
  final TransferCandidate c;
  final bool last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: kNavy.withValues(alpha: 0.1),
              child: Text(
                c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: kNavy, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                        '${c.matricule}${c.className != null ? ' · ${c.className}' : ''}',
                        style:
                            const TextStyle(fontSize: 11, color: kTextMuted)),
                  ]),
            ),
            const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: kNavy),
          ]),
        ),
      );
}

class _SelectedStudent extends StatelessWidget {
  const _SelectedStudent({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.person_rounded, size: 18, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          IconButton(
            tooltip: 'Changer',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18, color: kTextMuted),
            onPressed: onClear,
          ),
        ]),
      );
}

// ─── Fiche détail (avec workflow) ─────────────────────────────────────────────
class _TransferDetail extends ConsumerWidget {
  const _TransferDetail({
    required this.row,
    required this.onApprove,
    required this.onReject,
    required this.onComplete,
    required this.onDelete,
  });
  final TransferRow row;
  final VoidCallback onApprove, onReject, onComplete, onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canValidate =
        ref.watch(canProvider((slug: _kSlug, action: 'validate'))) ||
            ref.watch(canProvider((slug: _kSlug, action: 'approve')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final col = _statusColor(row.status);

    void act(VoidCallback fn) {
      Navigator.pop(context);
      fn();
    }

    final actions = <Widget>[];
    if (row.status == 'pending' && canValidate) {
      actions.addAll([
        _ActionBtn(
            label: 'Approuver',
            icon: Icons.check_circle_outline_rounded,
            color: kGreen,
            onTap: () => act(onApprove)),
        _ActionBtn(
            label: 'Rejeter',
            icon: Icons.cancel_outlined,
            color: kRed,
            outlined: true,
            onTap: () => act(onReject)),
      ]);
    } else if (row.status == 'approved' && canValidate) {
      actions.add(_ActionBtn(
          label: 'Marquer terminé',
          icon: Icons.task_alt_rounded,
          color: kGreen,
          onTap: () => act(onComplete)));
    }

    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: row.fullName,
      subtitle: 'Transfert · ${_statusLabel(row.status)}',
      submitLabel: null,
      footer: Row(children: [
        if (canDelete)
          TextButton.icon(
            onPressed: () => act(onDelete),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Supprimer'),
            style: TextButton.styleFrom(foregroundColor: kRed),
          ),
        const Spacer(),
        ...actions,
        if (actions.isEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
      ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: _StatusBadge(row.status)),
        const SizedBox(height: 14),
        AdminDetailCard([
          AdminDetailRow(Icons.badge_outlined, 'Matricule', row.matricule,
              mono: true),
          AdminDetailRow(
              Icons.class_outlined, 'Classe', row.className ?? '—'),
          AdminDetailRow(Icons.school_outlined, 'Destination',
              row.toSchoolName ?? '—'),
          AdminDetailRow(
              Icons.event_outlined, 'Date', _fmtDate(row.transferDate)),
          AdminDetailRow(Icons.flag_outlined, 'Statut', _statusLabel(row.status),
              valueColor: col,
              last: row.reason == null || row.reason!.trim().isEmpty),
          if (row.reason != null && row.reason!.trim().isNotEmpty)
            AdminDetailRow(
                Icons.notes_rounded, 'Motif', row.reason!.trim(), last: true),
        ]),
        if (row.status == 'pending' && canValidate) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withValues(alpha: 0.25)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Approuver sortira l\'élève de l\'effectif (statut « transféré »).',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: outlined
            ? OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 16),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                ),
              )
            : AdminPrimaryButton(
                label: label, icon: icon, color: color, onTap: onTap),
      );
}
