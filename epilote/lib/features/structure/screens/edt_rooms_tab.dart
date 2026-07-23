part of 'edt_settings_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ONGLET SALLES — registre des locaux typés (KPI → cartes groupées par type →
//  formulaire). Suppression DOUCE (désactivation) pour préserver l'historique.
// ════════════════════════════════════════════════════════════════════════════

IconData _roomTypeIcon(String type) => switch (type) {
      'labo_physique' || 'labo_chimie' || 'labo_svt' => Icons.science_outlined,
      'informatique' => Icons.computer_outlined,
      'multimedia' => Icons.headphones_outlined,
      'atelier' => Icons.build_outlined,
      'sport' => Icons.sports_soccer_outlined,
      'amphitheatre' => Icons.groups_outlined,
      'bibliotheque' => Icons.menu_book_outlined,
      _ => Icons.meeting_room_outlined,
    };

class _RoomsTab extends ConsumerWidget {
  const _RoomsTab();

  void _openForm(BuildContext context, {Room? room}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RoomForm(room: room),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref, Room r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer cette salle ?'),
        content: Text('« ${r.name} » sera retirée du registre. Les créneaux '
            'passés qui la référencent restent inchangés.'),
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
    await runModuleWrite(context, () => deactivateRoom(r.id),
        success: 'Salle retirée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roomsProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (rooms) {
        // Regroupement par type, dans l'ordre du catalogue.
        final byType = <String, List<Room>>{};
        for (final r in rooms) {
          (byType[r.roomType] ??= []).add(r);
        }
        final orderedTypes = [
          for (final t in kRoomTypes)
            if (byType.containsKey(t.$1)) t.$1
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _RoomKpis(rooms: rooms),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(
                child: AdminSectionTitle('Salles & ressources',
                    icon: Icons.meeting_room_outlined,
                    subtitle:
                        'Registre des locaux — fiabilise la détection des conflits de salle'),
              ),
              if (canCreate)
                AdminActionButton(
                    label: 'Ajouter une salle',
                    icon: Icons.add_rounded,
                    onPressed: () => _openForm(context)),
            ]),
            const SizedBox(height: 16),
            if (rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'Aucune salle enregistrée',
                  message:
                      'Enregistrez les locaux de l\'établissement (salles, labos, '
                      'atelier, gymnase…). Une salle référencée rend les conflits '
                      'd\'emploi du temps fiables.',
                  actionLabel: canCreate ? 'Ajouter une salle' : null,
                  onAction: canCreate ? () => _openForm(context) : null,
                ),
              )
            else
              for (final type in orderedTypes) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Row(children: [
                    Icon(_roomTypeIcon(type), size: 16, color: kNavy),
                    const SizedBox(width: 8),
                    Text(roomTypeLabel(type).toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: kNavy)),
                    const SizedBox(width: 6),
                    Text('· ${byType[type]!.length}',
                        style: TextStyle(fontSize: 12, color: kTextMuted)),
                  ]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final r in byType[type]!)
                      SizedBox(
                        width: 280,
                        child: _RoomCard(
                          room: r,
                          onEdit:
                              canUpdate ? () => _openForm(context, room: r) : null,
                          onDelete:
                              canDelete ? () => _delete(context, ref, r) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}

class _RoomKpis extends StatelessWidget {
  const _RoomKpis({required this.rooms});
  final List<Room> rooms;
  @override
  Widget build(BuildContext context) {
    final specialized = rooms.where((r) => r.isSpecialized).length;
    final totalCap =
        rooms.fold<int>(0, (s, r) => s + (r.capacity ?? 0));
    final items = <(IconData, String, String, Color)>[
      (Icons.meeting_room_outlined, 'Salles', '${rooms.length}', kNavy),
      (Icons.science_outlined, 'Salles spécialisées', '$specialized',
          const Color(0xFF8B5CF6)),
      (Icons.event_seat_outlined, 'Capacité cumulée',
          totalCap > 0 ? '$totalCap' : '—', kGreen),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final cols = cns.maxWidth >= 720 ? 3 : (cns.maxWidth >= 460 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 160,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color) = items[i];
          return AdminStatCard(
              label: label, value: value, icon: icon, color: color);
        },
      );
    });
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, this.onEdit, this.onDelete});
  final Room room;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_roomTypeIcon(room.roomType), size: 20, color: kNavy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(
              [
                if ((room.code ?? '').trim().isNotEmpty) room.code!.trim(),
                if (room.capacity != null) '${room.capacity} places',
                if ((room.building ?? '').trim().isNotEmpty) room.building!.trim(),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ]),
        ),
        if (onEdit != null)
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 17, color: kTextMuted),
            onPressed: onEdit,
            tooltip: 'Modifier',
          ),
        if (onDelete != null)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
            onPressed: onDelete,
            tooltip: 'Retirer',
          ),
      ]),
    );
  }
}

// ─── Formulaire salle ────────────────────────────────────────────────────────
class _RoomForm extends ConsumerStatefulWidget {
  const _RoomForm({this.room});
  final Room? room;
  @override
  ConsumerState<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends ConsumerState<_RoomForm> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _capacity;
  late final TextEditingController _building;
  String _type = 'ordinaire';
  bool _saving = false;

  bool get _isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _name = TextEditingController(text: r?.name ?? '');
    _code = TextEditingController(text: r?.code ?? '');
    _capacity = TextEditingController(
        text: r?.capacity != null ? '${r!.capacity}' : '');
    _building = TextEditingController(text: r?.building ?? '');
    if (r != null) _type = r.roomType;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _capacity.dispose();
    _building.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Le nom de la salle est requis'),
          backgroundColor: kAccent));
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    if (!_isEdit) {
      final missing = missingWriteIds(
          groupId: profile?.groupId,
          schoolId: profile?.schoolId,
          actorId: profile?.id);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(writeIdentityMessage(missing)),
            backgroundColor: kRed));
        return;
      }
    }
    final cap = int.tryParse(_capacity.text.trim());
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateRoom(
            id: widget.room!.id,
            code: _code.text,
            name: _name.text,
            roomType: _type,
            capacity: cap,
            building: _building.text,
          );
        } else {
          await createRoom(
            groupId: profile!.groupId!,
            schoolId: profile.schoolId!,
            code: _code.text,
            name: _name.text,
            roomType: _type,
            capacity: cap,
            building: _building.text,
          );
        }
      },
      success: _isEdit ? 'Salle modifiée' : 'Salle ajoutée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.meeting_room_outlined,
      title: _isEdit ? 'Modifier la salle' : 'Nouvelle salle',
      width: 460,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Ajouter',
      onSubmit: _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const AdminFormSectionLabel('IDENTITÉ'),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration:
              adminFilledInput('Nom (ex. Salle 12)', icon: Icons.label_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          decoration: adminFilledInput('Code court (facultatif, ex. S12)',
              icon: Icons.tag_rounded),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('TYPE & CAPACITÉ'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _type,
          isExpanded: true,
          decoration: adminFilledInput('Type', icon: Icons.category_outlined),
          items: [
            for (final t in kRoomTypes)
              DropdownMenuItem(value: t.$1, child: Text(t.$2)),
          ],
          onChanged: (v) => setState(() => _type = v ?? 'ordinaire'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: adminFilledInput('Places (facultatif)',
                  icon: Icons.event_seat_outlined),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _building,
              decoration: adminFilledInput('Bâtiment (facultatif)',
                  icon: Icons.apartment_rounded),
            ),
          ),
        ]),
      ]),
    );
  }
}
