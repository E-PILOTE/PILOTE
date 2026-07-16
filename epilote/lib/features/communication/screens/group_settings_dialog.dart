import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/group_chat_provider.dart';
import '../providers/messages_provider.dart'
    show RecipientOption, scopedRecipientsProvider;
import '../widgets/comm_attachments.dart';
import '../widgets/staff_feed_ui.dart' show roleColor, roleLabelFr;

// ════════════════════════════════════════════════════════════════════════════
//  Paramètres d'une conversation de groupe (style WhatsApp « Infos du groupe ») :
//  avatar, nom, membres, ajout/retrait, quitter / supprimer. Scope-aware via les
//  actions de group_chat_provider. Le créateur est l'administrateur.
// ════════════════════════════════════════════════════════════════════════════

class GroupSettingsDialog extends ConsumerStatefulWidget {
  const GroupSettingsDialog({
    super.key,
    required this.group,
    required this.myId,
    required this.onChanged,
    required this.onDeleted,
  });

  final GroupConversation group;
  final String myId;

  /// Appelé après un changement (renommage, avatar, membres) → rafraîchir le fil.
  final VoidCallback onChanged;

  /// Appelé après suppression / départ du groupe → fermer le fil.
  final VoidCallback onDeleted;

  @override
  ConsumerState<GroupSettingsDialog> createState() =>
      _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends ConsumerState<GroupSettingsDialog> {
  bool _busy = false;
  bool _adding = false;
  String _addQuery = '';
  final _addSelected = <String>{};

  bool get _isAdmin => widget.group.createdBy == widget.myId;
  String get _convId => widget.group.id;
  String get _groupId => widget.group.groupId;

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: error ? kRed : kGreen));
  }

  // ── Renommer ────────────────────────────────────────────────────────────────
  Future<void> _rename() async {
    final ctrl = TextEditingController(text: widget.group.title ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer le groupe'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom du groupe'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    setState(() => _busy = true);
    try {
      await renameGroupConversationScoped(ref, _convId, newName);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Changer / retirer l'avatar ────────────────────────────────────────────────
  Future<void> _changeAvatar() async {
    setState(() => _busy = true);
    try {
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: _groupId,
        bucket: 'message-attachments',
      );
      final img = added.where((a) => a.isImage).firstOrNull;
      if (img == null) {
        if (added.isNotEmpty) _toast('Choisissez une image.', error: true);
        return;
      }
      await updateGroupAvatarScoped(ref, _convId, img.url);
      widget.onChanged();
      _toast('Photo du groupe mise à jour');
      if (mounted) Navigator.pop(context);
    } on AttachmentUploadException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _busy = true);
    try {
      await updateGroupAvatarScoped(ref, _convId, null);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Membres ────────────────────────────────────────────────────────────────
  Future<void> _removeMember(ConvMember m) async {
    final ok = await _confirm('Retirer ${m.name ?? 'ce membre'} ?',
        'Cette personne n\'aura plus accès à la conversation.', 'Retirer');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await removeGroupMemberScoped(ref, convId: _convId, userId: m.userId);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitAddMembers() async {
    if (_addSelected.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await addGroupMembersScoped(ref,
          convId: _convId,
          groupId: _groupId,
          userIds: _addSelected.toList());
      widget.onChanged();
      if (n == 0) {
        _toast('Aucun membre ajouté (groupe sans administrateur actif).',
            error: true);
      } else {
        _toast('$n membre(s) ajouté(s)');
      }
      setState(() {
        _adding = false;
        _addSelected.clear();
      });
    } catch (e) {
      _toast('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Quitter / supprimer ───────────────────────────────────────────────────────
  Future<void> _leave() async {
    final ok = await _confirm('Quitter le groupe ?',
        'Vous ne recevrez plus les messages de cette conversation.', 'Quitter');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await removeGroupMemberScoped(ref, convId: _convId, userId: widget.myId);
      if (mounted) Navigator.pop(context);
      widget.onDeleted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm('Supprimer le groupe ?',
        'La conversation et tous ses messages seront définitivement supprimés '
            'pour tous les membres.',
        'Supprimer');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await deleteConversationScoped(ref, _convId);
      if (mounted) Navigator.pop(context);
      widget.onDeleted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action)),
        ],
      ),
    );
    return res == true;
  }

  // ── UI ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Réactif : reflète immédiatement renommage / avatar / membres ajoutés sans
    // rouvrir le dialog (le provider est invalidé après chaque action).
    final live = ref
        .watch(groupConversationsProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.group.id)
        .firstOrNull;
    final g = live ?? widget.group;
    final members = g.members;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête : fermer
          Row(children: [
            Icon(Icons.groups_rounded, size: 19, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Infos du groupe',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 6),
          // Avatar + nom
          _GroupHero(
            avatarUrl: g.avatarUrl,
            title: g.displayTitle(widget.myId),
            memberCount: members.length,
            isAdmin: _isAdmin,
            busy: _busy,
            onChangeAvatar: _changeAvatar,
            onRemoveAvatar: g.avatarUrl != null ? _removeAvatar : null,
            onRename: _rename,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: kBorder),
          // Liste membres / ajout
          Expanded(
            child: _adding
                ? _AddMembersPanel(
                    existing: members.map((m) => m.userId).toSet(),
                    query: _addQuery,
                    selected: _addSelected,
                    onQuery: (v) => setState(() => _addQuery = v),
                    onToggle: (id) => setState(() => _addSelected.contains(id)
                        ? _addSelected.remove(id)
                        : _addSelected.add(id)),
                  )
                : _MembersList(
                    members: members,
                    myId: widget.myId,
                    creatorId: g.createdBy,
                    canRemove: _isAdmin,
                    onRemove: _removeMember,
                  ),
          ),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 10),
          // Actions bas de page
          if (_adding)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _adding = false;
                            _addSelected.clear();
                          }),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: _busy ? null : _commitAddMembers,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(_addSelected.isEmpty
                      ? 'Ajouter'
                      : 'Ajouter (${_addSelected.length})'),
                ),
              ),
            ])
          else ...[
            if (_isAdmin)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => setState(() => _adding = true),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Ajouter des membres'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kNavy,
                      side: BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : (_isAdmin ? _delete : _leave),
                icon: Icon(
                    _isAdmin
                        ? Icons.delete_outline_rounded
                        : Icons.logout_rounded,
                    size: 18,
                    color: kRed),
                label: Text(
                    _isAdmin ? 'Supprimer le groupe' : 'Quitter le groupe',
                    style: TextStyle(
                        color: kRed, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Bandeau avatar + nom + actions admin ─────────────────────────────────────
class _GroupHero extends StatelessWidget {
  const _GroupHero({
    required this.avatarUrl,
    required this.title,
    required this.memberCount,
    required this.isAdmin,
    required this.busy,
    required this.onChangeAvatar,
    required this.onRename,
    this.onRemoveAvatar,
  });
  final String? avatarUrl, title;
  final int memberCount;
  final bool isAdmin, busy;
  final VoidCallback onChangeAvatar, onRename;
  final VoidCallback? onRemoveAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 6),
      Stack(children: [
        GroupAvatarImage(avatarUrl: avatarUrl, radius: 44),
        if (isAdmin)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: kNavy,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy ? null : onChangeAvatar,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.photo_camera_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      if (isAdmin && onRemoveAvatar != null)
        TextButton(
          onPressed: busy ? null : onRemoveAvatar,
          child: Text('Retirer la photo',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text(title ?? 'Groupe',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: busy ? null : onRename,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit_outlined, size: 16, color: kNavy),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 2),
      Text('$memberCount membre${memberCount > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: kTextMuted)),
    ]);
  }
}

// ─── Liste des membres ─────────────────────────────────────────────────────────
class _MembersList extends StatelessWidget {
  const _MembersList({
    required this.members,
    required this.myId,
    required this.creatorId,
    required this.canRemove,
    required this.onRemove,
  });
  final List<ConvMember> members;
  final String myId, creatorId;
  final bool canRemove;
  final ValueChanged<ConvMember> onRemove;

  @override
  Widget build(BuildContext context) {
    final sorted = [...members]..sort((a, b) {
        if (a.userId == creatorId) return -1;
        if (b.userId == creatorId) return 1;
        return (a.name ?? '').compareTo(b.name ?? '');
      });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final m = sorted[i];
        final isCreator = m.userId == creatorId;
        final isMe = m.userId == myId;
        final color = roleColor(m.role);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color,
              child: Text(_initials(m.name ?? '?'),
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
                  Text(isMe ? '${m.name ?? 'Moi'} (vous)' : (m.name ?? '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  if (m.role != null)
                    Text(roleLabelFr(m.role),
                        style:
                            TextStyle(fontSize: 11, color: kTextMuted)),
                ],
              ),
            ),
            if (isCreator)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Admin',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              )
            else if (canRemove && !isMe)
              IconButton(
                tooltip: 'Retirer',
                visualDensity: VisualDensity.compact,
                onPressed: () => onRemove(m),
                icon: Icon(Icons.remove_circle_outline_rounded,
                    size: 19, color: kRed),
              ),
          ]),
        );
      },
    );
  }
}

// ─── Panneau d'ajout de membres (annuaire scope-aware) ────────────────────────
class _AddMembersPanel extends ConsumerWidget {
  const _AddMembersPanel({
    required this.existing,
    required this.query,
    required this.selected,
    required this.onQuery,
    required this.onToggle,
  });
  final Set<String> existing, selected;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipients = ref.watch(scopedRecipientsProvider);
    return Column(children: [
      const SizedBox(height: 8),
      TextField(
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => onQuery(v.toLowerCase()),
        decoration: adminFilledInput('Rechercher un collègue…',
            icon: Icons.search_rounded),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: recipients.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
              child: Text('Erreur : $e',
                  style: TextStyle(color: kTextMuted, fontSize: 12))),
          data: (all) {
            final list = all
                .where((o) => !existing.contains(o.value))
                .where((o) =>
                    query.isEmpty ||
                    o.label.toLowerCase().contains(query) ||
                    (o.subtitle ?? '').toLowerCase().contains(query))
                .toList();
            if (list.isEmpty) {
              return Center(
                  child: Text('Aucun collègue à ajouter.',
                      style: TextStyle(color: kTextMuted, fontSize: 12.5)));
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final o = list[i];
                final checked = selected.contains(o.value);
                return _AddTile(
                    option: o, checked: checked, onTap: () => onToggle(o.value));
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile(
      {required this.option, required this.checked, required this.onTap});
  final RecipientOption option;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(option.subtitle);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(_initials(option.label),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                if (option.subtitle != null)
                  Text(roleLabelFr(option.subtitle),
                      style:
                          TextStyle(fontSize: 10.5, color: kTextMuted)),
              ],
            ),
          ),
          Icon(
              checked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: checked ? kGreen : kBorder),
        ]),
      ),
    );
  }
}

// ─── Avatar de groupe partagé (photo ou pastille dégradée) ────────────────────
class GroupAvatarImage extends StatelessWidget {
  const GroupAvatarImage({super.key, this.avatarUrl, this.radius = 18});
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kNavy, kAccent],
          ),
        ),
        alignment: Alignment.center,
        child:
            Icon(Icons.groups_rounded, color: Colors.white, size: radius * 1.1),
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}
