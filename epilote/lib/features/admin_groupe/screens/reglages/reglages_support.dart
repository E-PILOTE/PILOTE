part of '../admin_settings_screen.dart';

// Historique du support et demande de mise à jour.

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 18, color: kTextMuted),
        const SizedBox(width: 12),
        SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: kTextMuted))),
        Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kTextPrimary))),
      ]),
    );
  }
}

// ─── Historique des demandes au support ──────────────────────────────────────
class _SupportHistoryCard extends ConsumerWidget {
  const _SupportHistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(adminSupportTicketsProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(
          'Mes demandes au support',
          icon: Icons.support_agent_rounded,
          subtitle: 'Suivi de vos demandes envoyées à la plateforme',
          trailing: OutlinedButton.icon(
            onPressed: () =>
                showDialog(context: context, builder: (_) => const _RequestUpdateDialog()),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nouvelle demande'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              side: BorderSide(color: kBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ticketsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (_, _) => const AdminErrorBanner(message: 'Impossible de charger les demandes.'),
          data: (tickets) => tickets.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Icon(Icons.inbox_outlined, color: kTextMuted, size: 20),
                    const SizedBox(width: 10),
                    Text('Aucune demande envoyée.',
                        style: TextStyle(fontSize: 13, color: kTextMuted)),
                  ]),
                )
              : Column(
                  children: [
                    for (final t in tickets) _SupportTicketRow(ticket: t),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _SupportTicketRow extends StatelessWidget {
  const _SupportTicketRow({required this.ticket});
  final SupportTicketItem ticket;

  (Color, String, IconData) _statusMeta(String s) => switch (s) {
        'open'        => (kAccent,    'En attente',    Icons.hourglass_top_rounded),
        'in_progress' => (kNavy,      'En traitement', Icons.autorenew_rounded),
        'resolved'    => (kGreen,     'Résolu',        Icons.check_circle_rounded),
        'closed'      => (kTextMuted, 'Clôturé',       Icons.check_circle_outline),
        _             => (kTextMuted, ticket.status,   Icons.circle),
      };

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final (color, label, icon) = _statusMeta(t.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(t.subject,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          AdminBadge(label, color: color),
        ]),
        if (t.body != null && t.body!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(t.body!,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
        ],
        if (t.response != null && t.response!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGreen.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.support_agent_rounded, size: 15, color: kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.response!,
                    style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          t.createdAt != null
              ? 'Envoyée le ${t.createdAt!.day.toString().padLeft(2, '0')}/'
                '${t.createdAt!.month.toString().padLeft(2, '0')}/${t.createdAt!.year}'
              : '—',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
        ),
      ]),
    );
  }
}

// ─── Dialog : demande de modification du groupe (support_tickets) ────────────
class _RequestUpdateDialog extends ConsumerStatefulWidget {
  const _RequestUpdateDialog();

  @override
  ConsumerState<_RequestUpdateDialog> createState() => _RequestUpdateDialogState();
}

class _RequestUpdateDialogState extends ConsumerState<_RequestUpdateDialog> {
  final _msg = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_msg.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez décrire la modification souhaitée');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).requestGroupUpdate(_msg.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        _toast(context, 'Demande envoyée au support.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AdminDialogHeader(
            title: 'Demander une modification',
            icon: Icons.edit_note_rounded,
            subtitle: "Transmis à l'administration de la plateforme",
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _msg,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(800)],
                decoration: adminInputDecoration('Modification souhaitée',
                    hint: 'Ex. : mettre à jour le numéro de téléphone du groupe…'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: _error!),
              ],
            ]),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: 'Envoyer',
            submitIcon: Icons.send_rounded,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ]),
      ),
    );
  }
}

/// Ce que la plateforme tient réellement en matière de conservation.
///
/// Aucun réglage ici : la conservation n'est pas un préréglage d'interface,
/// c'est un engagement. On l'énonce, on ne le propose pas.
