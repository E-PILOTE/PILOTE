import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/platform_service_messages_provider.dart';
import '../../../core/utils/message_erreur.dart';

final _fmt = DateFormat('dd/MM/yyyy', 'fr_FR');

/// Messages de service diffusés sur la VITRINE des postes partagés (carrousel de
/// l'écran-verrou au repos). Diffusion globale offline via PowerSync.
class PlatformServiceMessagesScreen extends ConsumerWidget {
  const PlatformServiceMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceMessagesAdminProvider);
    return AppShell(
      title: 'Messages d’accueil des postes',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: kRed, size: 40),
              const SizedBox(height: 12),
              Text(messageErreur(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMuted)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(serviceMessagesAdminProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (messages) => _Body(messages: messages),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.messages});
  final List<ServiceMessageModel> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(count: messages.length, onAdd: () => _openForm(context, ref)),
              const SizedBox(height: 8),
              const _Explainer(),
              const SizedBox(height: 16),
              if (messages.isEmpty)
                const AdminEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Aucun message',
                  message:
                      'Ajoutez un message institutionnel : il s’affichera sur '
                      'la vitrine de tous les postes, même hors-ligne.',
                )
              else
                ...messages.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MessageCard(
                        message: m,
                        onEdit: () => _openForm(context, ref, m),
                        onToggle: () => ref
                            .read(serviceMessagesAdminServiceProvider)
                            .toggleActive(m.id, !m.isActive),
                        onDelete: () => _confirmDelete(context, ref, m),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
          [ServiceMessageModel? existing]) =>
      showDialog(
          context: context,
          builder: (_) => _MessageFormDialog(existing: existing));

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ServiceMessageModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Il disparaîtra de la vitrine de tous les postes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(serviceMessagesAdminServiceProvider).delete(m.id);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onAdd});
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text('$count message${count > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted)),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouveau message'),
          ),
        ],
      );
}

class _Explainer extends StatelessWidget {
  const _Explainer();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 18, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Jusqu’à 3 messages actifs s’affichent en carrousel sur la '
              'vitrine (écran d’ouverture de session) de chaque poste. '
              'La fenêtre de dates est optionnelle.',
              style: TextStyle(
                  fontSize: 12.5, color: kTextPrimary.withValues(alpha: 0.8)),
            ),
          ),
        ]),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final ServiceMessageModel message;
  final VoidCallback onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    final window = _windowLabel(message);
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: message.isActive ? kGreen : kTextMuted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.body,
                    style: TextStyle(
                        fontSize: 14,
                        color: kTextPrimary,
                        height: 1.35)),
                const SizedBox(height: 6),
                Row(children: [
                  AdminBadge(message.isActive ? 'Actif' : 'Inactif',
                      color: message.isActive ? kGreen : kTextMuted,
                      icon: message.isActive
                          ? Icons.check_circle
                          : Icons.cancel),
                  if (window != null) ...[
                    const SizedBox(width: 8),
                    Text(window,
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ]),
              ],
            ),
          ),
          IconButton(
              tooltip: message.isActive ? 'Désactiver' : 'Activer',
              icon: Icon(
                  message.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: message.isActive ? kGreen : kTextMuted,
                  size: 26),
              onPressed: onToggle),
          IconButton(
              tooltip: 'Modifier',
              icon: Icon(Icons.edit_outlined, color: kNavy, size: 20),
              onPressed: onEdit),
          IconButton(
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline_rounded,
                  color: kRed, size: 20),
              onPressed: onDelete),
        ],
      ),
    );
  }

  String? _windowLabel(ServiceMessageModel m) {
    if (m.startsAt == null && m.endsAt == null) return null;
    final s = m.startsAt != null ? _fmt.format(m.startsAt!) : '…';
    final e = m.endsAt != null ? _fmt.format(m.endsAt!) : '…';
    return 'Du $s au $e';
  }
}

class _MessageFormDialog extends ConsumerStatefulWidget {
  const _MessageFormDialog({this.existing});
  final ServiceMessageModel? existing;

  @override
  ConsumerState<_MessageFormDialog> createState() => _MessageFormDialogState();
}

class _MessageFormDialogState extends ConsumerState<_MessageFormDialog> {
  late final TextEditingController _body =
      TextEditingController(text: widget.existing?.body ?? '');
  late bool _active = widget.existing?.isActive ?? true;
  late DateTime? _starts = widget.existing?.startsAt;
  late DateTime? _ends = widget.existing?.endsAt;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _starts : _ends) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => start ? _starts = d : _ends = d);
  }

  Future<void> _save() async {
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Le message ne peut pas être vide.');
      return;
    }
    if (_starts != null && _ends != null && _ends!.isBefore(_starts!)) {
      setState(() => _error = 'La date de fin précède la date de début.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(serviceMessagesAdminServiceProvider);
      if (widget.existing == null) {
        await svc.create(
          body: body,
          isActive: _active,
          startsAt: _starts,
          endsAt: _ends,
          createdBy: ref.read(currentUserProvider)?.id,
        );
      } else {
        await svc.update(
          id: widget.existing!.id,
          body: body,
          isActive: _active,
          startsAt: _starts,
          endsAt: _ends,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = messageErreur(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Nouveau message de service'
          : 'Modifier le message'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _body,
              maxLines: 3,
              maxLength: 180,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Ex. E-PILOTE 3.0 — les bulletins PDF sont disponibles.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              subtitle: const Text('Visible sur les postes'),
              value: _active,
              activeThumbColor: kGreen,
              onChanged: (v) => setState(() => _active = v),
            ),
            Row(children: [
              Expanded(
                  child: _DateField(
                      label: 'Début',
                      date: _starts,
                      onTap: () => _pickDate(true),
                      onClear: () => setState(() => _starts = null))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DateField(
                      label: 'Fin',
                      date: _ends,
                      onTap: () => _pickDate(false),
                      onClear: () => setState(() => _ends = null))),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: kRed, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label,
      required this.date,
      required this.onTap,
      required this.onClear});
  final String label;
  final DateTime? date;
  final VoidCallback onTap, onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: date == null
                ? const Icon(Icons.calendar_today_rounded, size: 16)
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: onClear),
          ),
          child: Text(date != null ? _fmt.format(date!) : 'Optionnel',
              style: TextStyle(
                  color: date != null ? kTextPrimary : kTextMuted,
                  fontSize: 13.5)),
        ),
      );
}
