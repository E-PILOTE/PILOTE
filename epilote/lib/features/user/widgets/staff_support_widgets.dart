import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communication/providers/messages_provider.dart'
    show MessageAttachment;
import '../../communication/widgets/comm_attachments.dart';
import '../providers/staff_support_provider.dart';

// ─── Donut « Répartition par statut » ────────────────────────────────────────
class _StatusSlice {
  const _StatusSlice(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

class TicketStatusChart extends StatelessWidget {
  const TicketStatusChart({super.key, required this.data});
  final StaffTicketsData data;

  @override
  Widget build(BuildContext context) {
    final slices = [
      _StatusSlice('Ouverts', data.open, kAccent),
      _StatusSlice('En cours', data.inProgress, kNavy),
      _StatusSlice('Traités', data.resolved, kGreen),
    ].where((s) => s.count > 0).toList();
    if (slices.isEmpty) return const SizedBox.shrink();

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.donut_large_rounded, size: 16, color: kNavy),
          SizedBox(width: 8),
          Text('Répartition par statut',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ]),
        SizedBox(
          height: 190,
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.right,
              textStyle: TextStyle(fontSize: 11.5, color: kTextPrimary),
            ),
            annotations: [
              CircularChartAnnotation(
                widget: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${data.total}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const Text('demandes',
                      style: TextStyle(fontSize: 10, color: kTextMuted)),
                ]),
              ),
            ],
            series: [
              DoughnutSeries<_StatusSlice, String>(
                dataSource: slices,
                xValueMapper: (s, _) => s.label,
                yValueMapper: (s, _) => s.count.toDouble(),
                pointColorMapper: (s, _) => s.color,
                innerRadius: '68%',
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Helpers d'affichage statut / priorité ────────────────────────────────────
({String label, Color color}) ticketStatusInfo(String s) => switch (s) {
      'open'        => (label: 'Ouvert',   color: kAccent),
      'in_progress' => (label: 'En cours', color: kNavy),
      'resolved'    => (label: 'Résolu',   color: kGreen),
      'closed'      => (label: 'Fermé',    color: kTextMuted),
      _             => (label: s,          color: kTextMuted),
    };

({String label, Color color}) ticketPriorityInfo(String p) => switch (p) {
      'urgent' => (label: 'Urgente', color: kRed),
      'high'   => (label: 'Haute',   color: kAccent),
      'medium' => (label: 'Normale', color: kNavy),
      'low'    => (label: 'Basse',   color: kTextMuted),
      _        => (label: p,         color: kTextMuted),
    };

// (Le détail d'une demande est désormais la CONVERSATION partagée
//  `TicketThreadDialog` — voir communication/widgets/ticket_thread_view.dart.)

// ─── Dialogue de création — écrit en LOCAL (offline-first) ───────────────────
class CreateTicketDialog extends ConsumerStatefulWidget {
  const CreateTicketDialog({super.key});

  @override
  ConsumerState<CreateTicketDialog> createState() =>
      _CreateTicketDialogState();
}

class _CreateTicketDialogState extends ConsumerState<CreateTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String _category = 'technique';
  String _priority = 'medium';
  bool   _saving = false;
  bool   _uploading = false;
  // Images / documents de plainte (téléversés à l'envoi → nécessitent internet).
  final List<MessageAttachment> _pending = [];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments({required bool imagesOnly}) async {
    if (_uploading || _saving) return;
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) return;
    setState(() => _uploading = true);
    try {
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: groupId,
        imagesOnly: imagesOnly,
      );
      if (mounted && added.isNotEmpty) {
        setState(() => _pending.addAll(added));
      }
    } on AttachmentUploadException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.support_agent_rounded,
      title: 'Nouvelle demande au support',
      subtitle: 'Enregistrée localement, transmise à la synchronisation',
      saving: _saving,
      submitLabel: 'Envoyer',
      submitIcon: Icons.send_rounded,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Objet'),
          TextField(
              controller: _subjectCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Résumez votre demande')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Catégorie'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                onChanged: (v) => setState(() => _category = v ?? 'autre'),
                items: staffTicketCategories.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                decoration: _deco(null),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Priorité'),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                isExpanded: true,
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                items: staffTicketPriorities.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                decoration: _deco(null),
              ),
            ])),
          ]),
          const SizedBox(height: 12),
          _label('Description'),
          TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Décrivez votre demande en détail…')),
          const SizedBox(height: 14),
          _label('Pièces jointes (images, documents)'),
          Row(children: [
            OutlinedButton.icon(
              onPressed:
                  _uploading ? null : () => _pickAttachments(imagesOnly: true),
              icon: const Icon(Icons.image_rounded, size: 16),
              label: const Text('Image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: const BorderSide(color: kBorder),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed:
                  _uploading ? null : () => _pickAttachments(imagesOnly: false),
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: const BorderSide(color: kBorder),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_uploading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
          const Text('Le téléversement nécessite une connexion internet.',
              style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 10),
            CommAttachmentEditList(
              items: _pending,
              onRemove: (i) => setState(() => _pending.removeAt(i)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kTextPrimary)),
      );

  InputDecoration _deco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kNavy)),
        filled: true,
        fillColor: kSurface,
      );

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      _toast('L\'objet est requis');
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      _toast('La description est requise');
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final uid     = ref.read(currentUserProvider)?.id;
    if (profile?.groupId == null || uid == null) {
      _toast('Session invalide');
      return;
    }
    setState(() => _saving = true);
    try {
      await createStaffTicketLocal(
        groupId:     profile!.groupId!,
        submittedBy: uid,
        subject:     _subjectCtrl.text,
        category:    _category,
        priority:    _priority,
        body:        _bodyCtrl.text,
        attachments: _pending,
      );
      if (mounted) {
        Navigator.pop(context);
        _toast('Demande enregistrée — transmise à la synchronisation',
            ok: true);
      }
    } catch (e) {
      if (mounted) _toast('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: ok ? kGreen : kRed));
  }
}
