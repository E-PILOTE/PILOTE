import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../providers/support_requester_provider.dart';
import 'comm_attachments.dart';

// ─── Helpers d'affichage statut / priorité ────────────────────────────────────
({String label, Color color}) requesterStatusInfo(String s) => switch (s) {
      'open'        => (label: 'Ouvert',   color: kAccent),
      'in_progress' => (label: 'En cours', color: kNavy),
      'resolved'    => (label: 'Résolu',   color: kGreen),
      'closed'      => (label: 'Fermé',    color: kTextMuted),
      _             => (label: s,          color: kTextMuted),
    };

({String label, Color color}) requesterPriorityInfo(String p) => switch (p) {
      'urgent' => (label: 'Urgente', color: kRed),
      'high'   => (label: 'Haute',   color: kAccent),
      'medium' => (label: 'Normale', color: kNavy),
      'low'    => (label: 'Basse',   color: kTextMuted),
      _        => (label: p,         color: kTextMuted),
    };

// ─── Dialogue de création — scope-aware (online direct / offline local) ──────
class RequesterCreateDialog extends ConsumerStatefulWidget {
  const RequesterCreateDialog({super.key, required this.scope});
  final CommScope scope;

  @override
  ConsumerState<RequesterCreateDialog> createState() => _RequesterCreateDialogState();
}

class _RequesterCreateDialogState extends ConsumerState<RequesterCreateDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String _category = 'technique';
  String _priority = 'medium';
  bool   _saving = false;
  bool   _uploading = false;
  final List<MessageAttachment> _pending = [];

  bool get _offline => widget.scope == CommScope.school;

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
    final categories = requesterCategories(widget.scope);
    return AdminFormDialog(
      icon: Icons.support_agent_rounded,
      title: 'Nouvelle demande au support',
      subtitle: _offline
          ? 'Enregistrée localement, transmise à la synchronisation'
          : 'Posez votre question à la plateforme E-PILOTE',
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Catégorie'),
              DropdownButtonFormField<String>(
                initialValue: categories.containsKey(_category) ? _category : categories.keys.first,
                isExpanded: true,
                onChanged: (v) => setState(() => _category = v ?? 'autre'),
                items: categories.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 12))))
                    .toList(),
                decoration: _deco(null),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Priorité'),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                isExpanded: true,
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                items: requesterPriorities.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 12))))
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
              onPressed: _uploading ? null : () => _pickAttachments(imagesOnly: true),
              icon: const Icon(Icons.image_rounded, size: 16),
              label: const Text('Image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : () => _pickAttachments(imagesOnly: false),
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_uploading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Le téléversement nécessite une connexion internet.',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ),
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
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary)),
      );

  InputDecoration _deco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kNavy)),
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
    setState(() => _saving = true);
    try {
      await createRequesterTicket(
        ref,
        subject: _subjectCtrl.text,
        category: _category,
        priority: _priority,
        body: _bodyCtrl.text,
        attachments: _pending,
      );
      if (mounted) {
        Navigator.pop(context);
        _toast(
            _offline
                ? 'Demande enregistrée — transmise à la synchronisation'
                : 'Demande envoyée au support',
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
