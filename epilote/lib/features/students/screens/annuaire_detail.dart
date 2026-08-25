part of 'annuaire_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉTAIL FAMILLE — tuteurs/contacts d'un élève (lecture live), avec ajout,
//  édition, appel et retrait. Écritures gardées par permissions du module.
// ════════════════════════════════════════════════════════════════════════════
class _FamilyDetail extends ConsumerWidget {
  const _FamilyDetail({required this.family});
  final FamilyRow family;

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    await launchUrl(uri);
  }

  void _addOrEdit(BuildContext context, {StudentTutorModel? tutor}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _TutorForm(studentId: family.student.id, tutor: tutor),
      );

  Future<void> _delete(
      BuildContext context, WidgetRef ref, StudentTutorModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer ce contact ?'),
        content: Text('« ${t.fullName} » sera retiré de la fiche famille.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(context, () => deleteTutor(t.id),
        success: 'Contact retiré');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = family.student;
    final tutors =
        ref.watch(studentTutorsProvider(s.id)).valueOrNull ?? family.tutors;
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête élève.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.04),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kNavy.withValues(alpha: 0.12),
                child: Text(
                  s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.lastFirst,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (s.className != null) s.className!,
                            s.matricule
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 12.5, color: kTextMuted)),
                    ]),
              ),
              AdminBadge(
                  '${tutors.length} contact${tutors.length > 1 ? 's' : ''}',
                  color: tutors.isEmpty ? kRed : kNavy),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: tutors.isEmpty
                ? _EmptyTutors(
                    canCreate: canCreate,
                    onAdd: () => _addOrEdit(context),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final t in tutors)
                        _TutorTile(
                          t: t,
                          canUpdate: canUpdate,
                          canDelete: canDelete,
                          onCall: (p) => _call(context, p),
                          onEdit: () => _addOrEdit(context, tutor: t),
                          onDelete: () => _delete(context, ref, t),
                        ),
                    ],
                  ),
          ),
          if (canCreate && tutors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: AdminPrimaryButton(
                  label: 'Ajouter un contact',
                  icon: Icons.person_add_alt_1_rounded,
                  color: kNavy,
                  onTap: () => _addOrEdit(context),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _EmptyTutors extends StatelessWidget {
  const _EmptyTutors({required this.canCreate, required this.onAdd});
  final bool canCreate;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.contact_phone_outlined, size: 42, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucun tuteur enregistré',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text('Ajoutez un parent ou contact pour joindre la famille.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          if (canCreate) ...[
            const SizedBox(height: 16),
            AdminPrimaryButton(
                label: 'Ajouter un contact',
                icon: Icons.person_add_alt_1_rounded,
                color: kNavy,
                onTap: onAdd),
          ],
        ]),
      );
}

class _TutorTile extends StatelessWidget {
  const _TutorTile({
    required this.t,
    required this.canUpdate,
    required this.canDelete,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });
  final StudentTutorModel t;
  final bool canUpdate, canDelete;
  final ValueChanged<String> onCall;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final col = _relColor(t.relationship);
    final phones = <String>[
      if (t.phonePrimary.trim().isNotEmpty) t.phonePrimary.trim(),
      if ((t.phoneSecondary ?? '').trim().isNotEmpty) t.phoneSecondary!.trim(),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: col.withValues(alpha: 0.12),
            child: Text(
                t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: col, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  Text(t.relationshipLabel,
                      style: TextStyle(fontSize: 11.5, color: col)),
                ]),
          ),
          if (t.isPrimaryContact) _MiniTag('Principal', kNavy),
          if (t.isEmergencyContact) _MiniTag('Urgence', kRed),
          if (canUpdate)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: kTextMuted,
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              tooltip: 'Retirer',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: kRed,
              onPressed: onDelete,
            ),
        ]),
        if (phones.isNotEmpty || (t.email ?? '').isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in phones)
              _PhoneChip(phone: p, onCall: () => onCall(p)),
            if ((t.email ?? '').trim().isNotEmpty)
              _InfoPill(Icons.mail_outline_rounded, t.email!.trim()),
          ]),
        ],
        if ((t.profession ?? '').trim().isNotEmpty ||
            (t.address ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          if ((t.profession ?? '').trim().isNotEmpty)
            _SubLine(Icons.work_outline_rounded, t.profession!.trim()),
          if ((t.address ?? '').trim().isNotEmpty)
            _SubLine(Icons.place_outlined, t.address!.trim()),
        ],
      ]),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: kSurface, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kTextMuted),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(fontSize: 12, color: kTextPrimary)),
        ]),
      );
}

class _SubLine extends StatelessWidget {
  const _SubLine(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: kTextMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        ]),
      );
}
