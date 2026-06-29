part of 'edt_settings_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ONGLET DISPONIBILITÉS — déclare les plages où un enseignant N'EST PAS
//  disponible (DUR, bloque le placement) ou à éviter / privilégier (SOUPLE).
//  Absence de ligne = disponible. La construction de l'emploi du temps en tient
//  compte (le formulaire de créneau bloque/avertit). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

const _availDays = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi',
    'Samedi', 'Dimanche'];

Color _availColor(String status) => switch (status) {
      'unavailable' => kRed,
      'preference_against' => const Color(0xFFF59E0B),
      'preference_for' => kGreen,
      _ => kTextMuted,
    };

class _AvailabilityTab extends ConsumerWidget {
  const _AvailabilityTab();

  void _openForm(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AvailabilityForm(),
      );

  Future<void> _delete(BuildContext context, TeacherAvailability a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette disponibilité ?'),
        content: Text('${a.staffName ?? 'Enseignant'} · ${_availDays[a.dayOfWeek]} '
            '${a.rangeLabel}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(context, () => deleteTeacherAvailability(a.id),
        success: 'Disponibilité retirée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherAvailabilityProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (items) {
        // Regroupé par enseignant.
        final byStaff = <String, List<TeacherAvailability>>{};
        for (final a in items) {
          (byStaff[a.staffId] ??= []).add(a);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              const Expanded(
                child: Text(
                    'Plages d\'indisponibilité et préférences. Le placement d\'un '
                    'cours sur une plage « indisponible » est bloqué.',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
              if (canCreate) ...[
                const SizedBox(width: 10),
                AdminPrimaryButton(
                  label: 'Déclarer',
                  icon: Icons.add_rounded,
                  color: kNavy,
                  onTap: () => _openForm(context),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Tous les enseignants disponibles',
                  message:
                      'Aucune contrainte déclarée. Ajoutez les jours/heures où un '
                      'enseignant n\'est pas disponible.',
                ),
              )
            else
              for (final entry in byStaff.entries)
                _StaffAvailCard(
                  name: entry.value.first.staffName ?? 'Enseignant',
                  items: entry.value,
                  canDelete: canDelete,
                  onDelete: (a) => _delete(context, a),
                ),
          ],
        );
      },
    );
  }
}

class _StaffAvailCard extends StatelessWidget {
  const _StaffAvailCard({
    required this.name,
    required this.items,
    required this.canDelete,
    required this.onDelete,
  });
  final String name;
  final List<TeacherAvailability> items;
  final bool canDelete;
  final ValueChanged<TeacherAvailability> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Text(name,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in items)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: _availColor(a.status).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _availColor(a.status).withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${_availDays[a.dayOfWeek]} · ${a.rangeLabel}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text(availStatusLabel(a.status),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _availColor(a.status))),
                if (canDelete)
                  InkWell(
                    onTap: () => onDelete(a),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close_rounded, size: 14, color: kTextMuted),
                    ),
                  ),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ─── Formulaire de déclaration ───────────────────────────────────────────────
class _AvailabilityForm extends ConsumerStatefulWidget {
  const _AvailabilityForm();
  @override
  ConsumerState<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends ConsumerState<_AvailabilityForm> {
  String? _staffId;
  int _day = 1;
  bool _wholeDay = true;
  String _start = '08:00';
  String _end = '12:00';
  String _status = 'unavailable';
  bool _saving = false;

  Future<void> _pick(bool start) async {
    final v = await _pickHhmm(context, start ? _start : _end);
    if (v == null) return;
    setState(() => start ? _start = v : _end = v);
  }

  Future<void> _save() async {
    if (_staffId == null) return;
    if (!_wholeDay && _hhmmToMin(_end) <= _hhmmToMin(_start)) return;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => createTeacherAvailability(
        groupId: profile?.groupId ?? '',
        schoolId: profile?.schoolId ?? '',
        staffId: _staffId!,
        academicYearId: yearId,
        dayOfWeek: _day,
        startTime: _wholeDay ? null : _start,
        endTime: _wholeDay ? null : _end,
        status: _status,
      ),
      success: 'Disponibilité enregistrée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              const Icon(Icons.event_busy_outlined, size: 18, color: kNavy),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Déclarer une disponibilité',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: ListView(
                padding: const EdgeInsets.all(18),
                shrinkWrap: true,
                children: [
              DropdownButtonFormField<String>(
                initialValue: _staffId,
                isExpanded: true,
                decoration: adminFilledInput('Enseignant',
                    icon: Icons.person_outline_rounded),
                items: [
                  for (final t in staff)
                    DropdownMenuItem(
                        value: t.id,
                        child: Text(t.fullName,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _staffId = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _day,
                isExpanded: true,
                decoration:
                    adminFilledInput('Jour', icon: Icons.today_rounded),
                items: [
                  for (var d = 1; d <= 6; d++)
                    DropdownMenuItem(value: d, child: Text(_availDays[d])),
                ],
                onChanged: (v) => setState(() => _day = v ?? 1),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toute la journée',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _wholeDay,
                activeThumbColor: kNavy,
                onChanged: (v) => setState(() => _wholeDay = v),
              ),
              if (!_wholeDay) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: _TimeField(
                          label: 'Début', value: _start, onTap: () => _pick(true))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _TimeField(
                          label: 'Fin', value: _end, onTap: () => _pick(false))),
                ]),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: adminFilledInput('Type',
                    icon: Icons.flag_outlined),
                items: [
                  for (final (v, l) in kAvailStatuses)
                    DropdownMenuItem(value: v, child: Text(l)),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'unavailable'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: _saving || _staffId == null ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
