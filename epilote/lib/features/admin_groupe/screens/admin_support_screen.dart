import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/admin_support_provider.dart';
import '../widgets/admin_ui.dart';

final _fmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

// ─── Helpers d'affichage statut / priorité ────────────────────────────────────
({String label, Color color}) _statusInfo(String s) => switch (s) {
      'open'        => (label: 'Ouvert',  color: kAccent),
      'in_progress' => (label: 'En cours', color: kNavy),
      'resolved'    => (label: 'Résolu',  color: kGreen),
      'closed'      => (label: 'Fermé',   color: kTextMuted),
      _             => (label: s,         color: kTextMuted),
    };

({String label, Color color}) _priorityInfo(String p) => switch (p) {
      'urgent' => (label: 'Urgente', color: kRed),
      'high'   => (label: 'Haute',   color: kAccent),
      'medium' => (label: 'Normale', color: kNavy),
      'low'    => (label: 'Basse',   color: kTextMuted),
      _        => (label: p,         color: kTextMuted),
    };

/// Espace Support de l'admin groupe : émettre et suivre les demandes adressées
/// à la plateforme (E-PILOTE). Symétrique de l'espace Tickets du super_admin.
class AdminSupportScreen extends ConsumerWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminTicketsProvider);

    return AppShell(
      title: 'Support',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AdminErrorBanner(message: 'Impossible de charger les demandes : $e'),
        ),
        data: (data) => _Body(data: data),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final AdminTicketsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminTicketStatusFilter);
    var tickets = data.tickets;
    if (filter != 'all') {
      tickets = filter == 'resolved'
          ? tickets.where((t) => t.isClosed).toList()
          : tickets.where((t) => t.status == filter).toList();
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle(
              'Demandes au support',
              icon: Icons.support_agent_rounded,
              subtitle: 'Posez vos questions et signalez vos problèmes à la plateforme',
            ),
          ),
          FilledButton.icon(
            onPressed: () => _openCreate(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle demande'),
            style: FilledButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: AdminStatCard(label: 'Total', value: '${data.total}', icon: Icons.confirmation_num_rounded, color: kNavy)),
          const SizedBox(width: 12),
          Expanded(child: AdminStatCard(label: 'Ouverts', value: '${data.open}', icon: Icons.markunread_mailbox_rounded, color: kAccent)),
          const SizedBox(width: 12),
          Expanded(child: AdminStatCard(label: 'En cours', value: '${data.inProgress}', icon: Icons.autorenew_rounded, color: kNavy)),
          const SizedBox(width: 12),
          Expanded(child: AdminStatCard(label: 'Traités', value: '${data.resolved}', icon: Icons.check_circle_rounded, color: kGreen)),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          _Chip(label: 'Tous', value: 'all', current: filter),
          _Chip(label: 'Ouverts', value: 'open', current: filter),
          _Chip(label: 'En cours', value: 'in_progress', current: filter),
          _Chip(label: 'Traités', value: 'resolved', current: filter),
        ]),
        const SizedBox(height: 16),
        if (tickets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: AdminEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'Aucune demande',
              message: 'Vous n\'avez encore envoyé aucune demande au support.',
            ),
          )
        else
          ...tickets.map((t) => _TicketCard(ticket: t)),
      ],
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateTicketDialog(),
    );
  }
}

class _Chip extends ConsumerWidget {
  const _Chip({required this.label, required this.value, required this.current});
  final String label, value, current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => ref.read(adminTicketStatusFilter.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kNavy : kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? kNavy : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kTextMuted)),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final AdminTicket ticket;

  @override
  Widget build(BuildContext context) {
    final st = _statusInfo(ticket.status);
    final pr = _priorityInfo(ticket.priority);
    final cat = adminTicketCategories[ticket.category] ?? ticket.category;
    final dt = DateTime.tryParse(ticket.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        accent: st.color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(ticket.subject,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ),
              AdminBadge(st.label, color: st.color),
              const SizedBox(width: 6),
              AdminBadge(pr.label, color: pr.color),
            ]),
            const SizedBox(height: 8),
            Text(ticket.body,
                style: const TextStyle(fontSize: 13, color: kTextMuted, height: 1.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _Meta(icon: Icons.category_rounded, label: cat),
              if (dt != null) _Meta(icon: Icons.schedule_rounded, label: _fmt.format(dt.toLocal())),
            ]),
            if (ticket.hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kGreen.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.support_agent_rounded, size: 15, color: kGreen),
                      SizedBox(width: 6),
                      Text('Réponse du support',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
                    ]),
                    const SizedBox(height: 6),
                    Text(ticket.response!,
                        style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: kTextMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
      ]);
}

// ─── Dialogue de création ─────────────────────────────────────────────────────
class _CreateTicketDialog extends ConsumerStatefulWidget {
  const _CreateTicketDialog();

  @override
  ConsumerState<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends ConsumerState<_CreateTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String _category = 'technique';
  String _priority = 'medium';
  bool   _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.support_agent_rounded, color: kNavy, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Nouvelle demande au support',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: kTextMuted),
              ]),
              const SizedBox(height: 18),
              _label('Objet'),
              TextField(controller: _subjectCtrl, style: const TextStyle(fontSize: 13), decoration: _deco('Résumez votre demande')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Catégorie'),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    onChanged: (v) => setState(() => _category = v ?? 'autre'),
                    items: adminTicketCategories.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    decoration: _deco(null),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Priorité'),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    isExpanded: true,
                    onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                    items: adminTicketPriorities.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    decoration: _deco(null),
                  ),
                ])),
              ]),
              const SizedBox(height: 12),
              _label('Description'),
              TextField(controller: _bodyCtrl, maxLines: 5, style: const TextStyle(fontSize: 13), decoration: _deco('Décrivez votre demande en détail…')),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextMuted,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kNavy,
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary)),
      );

  InputDecoration _deco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kNavy)),
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
    final groupId = profile?.groupId;
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (groupId == null || uid == null) {
      _toast('Session invalide');
      return;
    }
    setState(() => _saving = true);
    try {
      await createSupportTicket(
        client: ref.read(supabaseClientProvider),
        groupId: groupId,
        submittedBy: uid,
        subject: _subjectCtrl.text,
        category: _category,
        priority: _priority,
        body: _bodyCtrl.text,
      );
      ref.invalidate(adminTicketsProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast('Demande envoyée au support', ok: true);
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
