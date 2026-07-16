import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/group_chat_provider.dart';
import '../providers/messages_provider.dart' show RecipientOption, scopedRecipientsProvider;
import '../widgets/staff_feed_ui.dart' show roleColor, roleLabelFr;

// ════════════════════════════════════════════════════════════════════════════
//  Création d'une conversation de groupe — nom + sélection multi-membres depuis
//  l'annuaire (scopedRecipientsProvider). Scope-aware via createGroupConversationScoped.
// ════════════════════════════════════════════════════════════════════════════

class GroupCreateDialog extends ConsumerStatefulWidget {
  const GroupCreateDialog({super.key, required this.onCreated});
  final void Function(String conversationId) onCreated;

  @override
  ConsumerState<GroupCreateDialog> createState() => _GroupCreateDialogState();
}

class _GroupCreateDialogState extends ConsumerState<GroupCreateDialog> {
  final _nameCtrl   = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _selected = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _create(List<RecipientOption> all) async {
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Donnez un nom au groupe');
      return;
    }
    if (_selected.length < 2) {
      _toast('Choisissez au moins 2 membres');
      return;
    }
    setState(() => _busy = true);
    try {
      final convId = await createGroupConversationScoped(
        ref,
        title: _nameCtrl.text,
        memberIds: _selected.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(convId);
      }
    } catch (e) {
      _toast('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: kRed));
  }

  @override
  Widget build(BuildContext context) {
    final recipients = ref.watch(scopedRecipientsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 660),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.group_add_rounded, size: 19, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Nouveau groupe',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Nom du groupe (ex. Conseil de classe 3e A)…',
              hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
              prefixIcon: Icon(Icons.badge_outlined,
                  size: 18, color: kTextMuted),
              isDense: true,
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kNavy)),
            ),
          ),
          const SizedBox(height: 10),
          // Pastilles des membres sélectionnés
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in _selected)
                    _SelectedChip(
                      label: recipients.valueOrNull
                              ?.firstWhere((o) => o.value == id,
                                  orElse: () => const RecipientOption(
                                      value: '', label: '—'))
                              .label ??
                          '—',
                      onRemove: () => setState(() => _selected.remove(id)),
                    ),
                ],
              ),
            ),
          if (_selected.isNotEmpty) const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher un collègue…',
              hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: kTextMuted),
              isDense: true,
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: recipients.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Erreur : $e',
                    style: TextStyle(color: kTextMuted, fontSize: 12)),
              ),
              data: (all) {
                final filtered = _query.isEmpty
                    ? all
                    : all
                        .where((o) =>
                            o.label.toLowerCase().contains(_query) ||
                            (o.subtitle ?? '').toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aucun collègue trouvé',
                        style: TextStyle(color: kTextMuted, fontSize: 12.5)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final o = filtered[i];
                    final checked = _selected.contains(o.value);
                    return _MemberTile(
                      option: o,
                      checked: checked,
                      onTap: () => setState(() => checked
                          ? _selected.remove(o.value)
                          : _selected.add(o.value)),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _create(recipients.valueOrNull ?? const []),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_selected.isEmpty
                  ? 'Créer le groupe'
                  : 'Créer le groupe (${_selected.length})'),
              style: FilledButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile(
      {required this.option, required this.checked, required this.onTap});
  final RecipientOption option;
  final bool            checked;
  final VoidCallback    onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(option.subtitle);
    final initials = option.label.trim().isEmpty
        ? '?'
        : option.label
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.25)!]),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                if (option.subtitle != null)
                  Text(roleLabelFr(option.subtitle),
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
              ],
            ),
          ),
          Icon(
            checked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: checked ? kNavy : kBorder,
            size: 22,
          ),
        ]),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.onRemove});
  final String       label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label.split(' ').first,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: kNavy)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: kNavy),
          ),
        ]),
      );
}
