import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/events_provider.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../widgets/comm_attachments.dart';
import '../widgets/staff_feed_ui.dart';
import '../../../core/utils/message_erreur.dart';

/// Formulaire d'événement SCOPE-AWARE — un seul dialogue pour tous les espaces.
/// • Direction école → écriture locale (offline-first).
/// • admin_groupe → online sur SON groupe ; super_admin → online, groupe choisi.
class StaffEventFormDialog extends ConsumerStatefulWidget {
  const StaffEventFormDialog({super.key, this.existing});
  final EventModel? existing;

  @override
  ConsumerState<StaffEventFormDialog> createState() =>
      _StaffEventFormDialogState();
}

class _StaffEventFormDialogState extends ConsumerState<StaffEventFormDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _location =
      TextEditingController(text: widget.existing?.location ?? '');
  late DateTime? _date = widget.existing?.date;
  late DateTime? _endDate = widget.existing?.endDate != null
      ? DateTime.tryParse(widget.existing!.endDate!)
      : null;
  late TimeOfDay? _start = _parseTime(widget.existing?.startTime);
  late TimeOfDay? _end = _parseTime(widget.existing?.endTime);
  late String _audience = widget.existing?.targetAudience ?? 'all';
  late final List<MessageAttachment> _attachments =
      List.of(widget.existing?.attachments ?? const []);
  late String? _groupId = widget.existing?.groupId;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]);
    final m = p.length > 1 ? int.tryParse(p[1]) : 0;
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _fmtTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    setState(() => _uploading = true);
    try {
      final me = ref.read(authNotifierProvider).valueOrNull;
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: me?.groupId ?? '',
      );
      if (mounted) setState(() => _attachments.addAll(added));
    } on AttachmentUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (end ? _endDate : _date) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('fr'),
    );
    if (picked != null) {
      setState(() => end ? _endDate = picked : _date = picked);
    }
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (end ? _end : _start) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => end ? _end = picked : _start = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Le titre est obligatoire.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'La date de l\'événement est obligatoire.');
      return;
    }
    final ctx = ref.read(communicationContextProvider);
    final me  = ref.read(authNotifierProvider).valueOrNull;
    if (ctx.isSchool && (me?.groupId == null || me?.schoolId == null)) {
      setState(() => _error = 'Session invalide (école introuvable).');
      return;
    }
    if (ctx.isPlatform && (_groupId == null || _groupId!.isEmpty)) {
      setState(() => _error = 'Choisissez un groupe destinataire.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await saveEventScoped(
        ref,
        id: _isEdit ? widget.existing!.id : null,
        title: _title.text,
        description: _desc.text,
        eventDate: _fmtDate(_date!),
        endDate: _endDate != null ? _fmtDate(_endDate!) : null,
        startTime: _fmtTime(_start),
        endTime: _fmtTime(_end),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        targetAudience: _audience,
        attachments: _attachments,
        groupIdOverride: _groupId,
      );
      if (mounted) {
        final offline = ctx.isSchool;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen,
            content: Text(_isEdit
                ? 'Événement mis à jour.'
                : offline
                    ? 'Événement créé pour votre école — visible même hors '
                        'ligne, transmis à la synchronisation.'
                    : 'Événement créé.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap,
          {IconData icon = Icons.event_rounded}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: adminInputDecoration(label, icon: icon),
          child: Text(value == null ? '—' : fmtDateFr(value),
              style: const TextStyle(fontSize: 12.5)),
        ),
      );

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: adminInputDecoration(label, icon: Icons.schedule_rounded),
          child: Text(value == null ? '—' : _fmtTime(value)!,
              style: const TextStyle(fontSize: 12.5)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ctx    = ref.watch(communicationContextProvider);
    final groups = ref.watch(eventGroupsProvider);
    final showGroupPicker = ctx.isPlatform && !_isEdit;
    final subtitle = ctx.isSchool
        ? 'Pour votre école — le texte part même hors ligne'
        : ctx.isGroup
            ? 'Diffusé à tout votre groupe scolaire'
            : 'Diffusé au groupe scolaire choisi';

    return AdminFormDialog(
      icon: Icons.event_rounded,
      title: _isEdit ? 'Modifier l\'événement' : 'Créer un événement',
      subtitle: subtitle,
      width: 560,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.event_available_rounded,
      onSubmit: _submit,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGroupPicker) ...[
            const AdminFormSectionLabel('Groupe destinataire'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _groupId,
              isExpanded: true,
              onChanged: (v) => setState(() => _groupId = v),
              items: groups
                  .map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5))))
                  .toList(),
              decoration: adminInputDecoration('Choisir un groupe',
                  icon: Icons.apartment_rounded),
            ),
            const SizedBox(height: 14),
          ],
          const AdminFormSectionLabel('Événement'),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 13),
            decoration: adminInputDecoration('Titre de l\'événement',
                icon: Icons.title_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 8,
            style: const TextStyle(fontSize: 13),
            decoration: adminInputDecoration('Description (optionnel)'),
          ),
          const SizedBox(height: 14),
          const AdminFormSectionLabel('Date et lieu'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _dateField(
                    'Date *', _date, () => _pickDate(end: false))),
            const SizedBox(width: 12),
            Expanded(
                child: _dateField('Fin (optionnel)', _endDate,
                    () => _pickDate(end: true),
                    icon: Icons.event_repeat_rounded)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _timeField(
                    'Heure début', _start, () => _pickTime(end: false))),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _timeField('Heure fin', _end, () => _pickTime(end: true))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _location,
                style: const TextStyle(fontSize: 13),
                decoration: adminInputDecoration('Lieu (optionnel)',
                    icon: Icons.place_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
                items: kAudienceLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 12.5))))
                    .toList(),
                decoration: adminInputDecoration('Audience',
                    icon: Icons.groups_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          const AdminFormSectionLabel('Pièces jointes'),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _attach,
              icon: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Joindre des fichiers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                textStyle: const TextStyle(fontSize: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Affiche, programme PDF, photos… — internet requis',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ),
          ]),
          CommAttachmentEditList(
            items: _attachments,
            onRemove: (i) => setState(() => _attachments.removeAt(i)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

/// Confirmation + suppression SCOPE-AWARE d'un événement (local OU online).
Future<void> confirmDeleteEvent(
    WidgetRef ref, BuildContext context, EventModel event) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Supprimer cet événement ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text('« ${event.title} » sera supprimé définitivement. '
          'Cette action est irréversible.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: kRed),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok == true) await deleteEventScoped(ref, event.id);
}
