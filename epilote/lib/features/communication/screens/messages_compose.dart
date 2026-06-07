part of 'messages_screen.dart';

// ─── Dialogue de composition (scope-aware) ────────────────────────────────────
class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog({required this.onSent, this.initialSubject, this.initialBody});
  final VoidCallback onSent;
  final String? initialSubject;
  final String? initialBody;

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  late final TextEditingController _subjectCtrl =
      TextEditingController(text: widget.initialSubject ?? '');
  late final TextEditingController _bodyCtrl =
      TextEditingController(text: widget.initialBody ?? '');
  String? _recipientValue;
  bool    _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx            = ref.watch(communicationContextProvider);
    final recipientsAsync = ref.watch(messageRecipientsProvider);
    final isGroup        = ctx.isGroup;
    final destLabel      = isGroup ? 'Destinataire (utilisateur)' : 'Destinataire (groupe)';
    final subtitle       = isGroup
        ? 'Envoyer un message à un membre de votre groupe'
        : 'Envoyer un message à un groupe scolaire';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_rounded, color: _kNavy, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nouveau message',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: _kSub)),
                  ],
                )),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _kSub),
              ]),
              const SizedBox(height: 20),
              Text(destLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              recipientsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('Erreur chargement destinataires',
                    style: TextStyle(color: _kRed, fontSize: 12)),
                data: (options) => DropdownButtonFormField<String>(
                  initialValue: _recipientValue,
                  isExpanded: true,
                  hint: const Text('Sélectionner…', style: TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => _recipientValue = v),
                  items: options
                      .map((o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(
                              o.subtitle != null ? '${o.label} · ${o.subtitle}' : o.label,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  decoration: _fieldDeco(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Objet',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              TextField(
                controller: _subjectCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDeco(hint: 'Objet du message…'),
              ),
              const SizedBox(height: 12),
              const Text('Message',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 6,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDeco(hint: 'Rédigez votre message…'),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      side: const BorderSide(color: _kBorder),
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
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
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
        hintStyle: const TextStyle(fontSize: 12, color: _kSub),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kNavy)),
        filled: true,
        fillColor: _kBg,
      );

  Future<void> _submit(CommContext ctx) async {
    if (_recipientValue == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sélectionnez un destinataire')));
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("L'objet est requis")));
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le message est vide')));
      return;
    }

    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id ?? '';

      // Résolution scope-aware du destinataire + groupe
      String recipientId;
      String groupId;
      if (ctx.isGroup) {
        recipientId = _recipientValue!;       // un utilisateur du groupe
        groupId     = ctx.groupId ?? '';
      } else {
        groupId     = _recipientValue!;       // un groupe scolaire
        final admin = await groupAdminRecipient(client, groupId);
        if (admin == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Ce groupe n'a pas d'administrateur actif"),
                backgroundColor: _kRed));
            setState(() => _sending = false);
          }
          return;
        }
        recipientId = admin;
      }

      await sendMessage(
        client: client,
        senderId: userId,
        recipientId: recipientId,
        groupId: groupId,
        subject: _subjectCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Message envoyé avec succès !'), backgroundColor: _kGreen));
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
