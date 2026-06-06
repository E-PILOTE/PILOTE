import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import 'notification_types.dart';

/// Dialogue d'envoi de notification, scope-aware.
/// - platform (super_admin) : cible « toute la plateforme » ou un groupe précis.
/// - group (admin_groupe)   : verrouillé sur le groupe de l'utilisateur.
class SendNotificationDialog extends ConsumerStatefulWidget {
  const SendNotificationDialog({super.key, required this.onSent});
  final VoidCallback onSent;

  @override
  ConsumerState<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends ConsumerState<SendNotificationDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _type   = 'system';
  String _target = 'all';                 // platform : 'all' | groupId
  bool   _sending = false;

  List<({String id, String name})> _groups = [];

  @override
  void initState() {
    super.initState();
    final ctx = ref.read(communicationContextProvider);
    if (ctx.isPlatform) _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('school_groups')
          .select('id, name')
          .eq('is_active', true)
          .order('name') as List;
      if (mounted) {
        setState(() => _groups = rows
            .map((r) => (id: (r as Map)['id'] as String, name: r['name'] as String? ?? ''))
            .toList());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(communicationContextProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: kCommNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.notifications_active_rounded, color: kCommNavy, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Envoyer une notification',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kCommNavy)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded), color: kCommSub),
              ]),
              const SizedBox(height: 20),

              // Destinataire : sélecteur uniquement pour la plateforme
              if (ctx.isPlatform) ...[
                const _Label('Destinataire'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _target = v ?? _target),
                  items: [
                    const DropdownMenuItem(value: 'all',
                        child: Text('Toute la plateforme', style: TextStyle(fontSize: 12))),
                    ..._groups.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name,
                            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  ],
                  decoration: _fieldDeco(),
                ),
                const SizedBox(height: 12),
              ],

              const _Label('Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _type,
                onChanged: (v) => setState(() => _type = v ?? _type),
                items: const [
                  DropdownMenuItem(value: 'system',       child: Text('Système',    style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'alert',        child: Text('Alerte',     style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'subscription', child: Text('Abonnement', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'invoice',      child: Text('Facture',    style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'group',        child: Text('Groupe',     style: TextStyle(fontSize: 12))),
                ],
                decoration: _fieldDeco(),
              ),
              const SizedBox(height: 12),
              const _Label('Titre'),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDeco(hint: 'Titre de la notification…'),
              ),
              const SizedBox(height: 12),
              const _Label('Message'),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDeco(hint: 'Corps de la notification…'),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCommSub,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : () => _submit(ctx),
                    icon: _sending
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kCommNavy, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: kCommSub),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCommBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCommBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCommNavy)),
    filled: true, fillColor: const Color(0xFFF8FAFC),
  );

  Future<void> _submit(CommContext ctx) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le titre est requis')));
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);

      // Cible : groupe verrouillé (admin) ou choix (plateforme)
      final String? targetGroup =
          ctx.isGroup ? ctx.groupId : (_target == 'all' ? null : _target);

      var q = client
          .from('profiles')
          .select('id, group_id')
          .eq('is_active', true)
          .not('group_id', 'is', null);
      if (targetGroup != null) q = q.eq('group_id', targetGroup);
      final recipients = (await q as List).cast<Map>();

      if (recipients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucun destinataire actif pour cette cible')));
          setState(() => _sending = false);
        }
        return;
      }

      final now = DateTime.now().toIso8601String();
      final payload = recipients.map((p) => {
        'group_id':     p['group_id'],
        'recipient_id': p['id'],
        'type':         _type,
        'title':        _titleCtrl.text.trim(),
        'body':         _bodyCtrl.text.trim(),
        'is_read':      false,
        'created_at':   now,
        'updated_at':   now,
      }).toList();
      await client.from('notifications').insert(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Notification envoyée à ${recipients.length} destinataire(s) !'),
            backgroundColor: kCommGreen));
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCommNavy));
}
