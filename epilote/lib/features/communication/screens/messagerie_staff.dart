import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show RealtimeChannel, RealtimeChannelConfig;

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/conversation_read_provider.dart';
import '../providers/group_chat_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/presence_provider.dart';
import '../widgets/audio_recorder_button.dart';
import '../widgets/comm_attachments.dart';
import '../widgets/staff_feed_ui.dart' show roleColor, roleLabelFr;
import '../widgets/user_avatar.dart';
import 'group_create_dialog.dart';
import 'group_settings_dialog.dart';

part 'messagerie_staff_inbox.dart';
part 'messagerie_staff_thread.dart';
part 'messagerie_staff_bubble.dart';
part 'messagerie_staff_forward.dart';
part 'messagerie_staff_compose.dart';

// ─── Helpers temps & identité ───────────────────────────────────────────────────

final _fmtClock = DateFormat('HH:mm', 'fr_FR');
final _fmtDate  = DateFormat('dd/MM/yyyy', 'fr_FR');
final _fmtFull  = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

/// Horodatage relatif : à l'instant · il y a X min/h · hier HH:mm · date.
String _relativeTime(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final now  = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24 && dt.day == now.day) return 'il y a ${diff.inHours} h';
  final yest = now.subtract(const Duration(days: 1));
  if (dt.year == yest.year && dt.month == yest.month && dt.day == yest.day) {
    return 'hier ${_fmtClock.format(dt)}';
  }
  return _fmtDate.format(dt);
}

String _roleLabel(String? role) {
  if (role == null || role.isEmpty) return '';
  return roleLabelFr(role);
}

// ─── Conversation = tous les messages échangés avec un interlocuteur ────────────

/// Fil de discussion unifié : conversation privée (1-à-1) OU groupe.
class _Conversation {
  _Conversation(this.otherId, this.otherName, this.otherRole,
      {this.isGroup = false, this.group, this.myGroupLastRead,
       this.otherAvatarUrl});
  /// 1-à-1 : id de l'interlocuteur. Groupe : id de la conversation.
  final String  otherId;
  final String  otherName;
  final String? otherRole;
  /// Photo de l'interlocuteur (1-à-1 uniquement ; les groupes ont leur logo).
  final String? otherAvatarUrl;
  final bool    isGroup;
  /// Métadonnées de groupe (membres, titre) — null pour le 1-à-1.
  final GroupConversation? group;
  final List<MessageModel> messages = []; // tri croissant par date

  /// Mon dernier accusé de lecture sur ce groupe (compteur de non-lus).
  final DateTime? myGroupLastRead;

  MessageModel get first => messages.first;
  MessageModel get last  => messages.last;

  /// Variantes sûres : un groupe fraîchement créé peut n'avoir aucun message.
  MessageModel? get firstOrNull => messages.isEmpty ? null : messages.first;
  MessageModel? get lastOrNull  => messages.isEmpty ? null : messages.last;

  /// Non lus : 1-à-1 = messages reçus non lus. Groupe = messages des AUTRES
  /// postérieurs à mon dernier accusé de lecture (last_read_at).
  int unread(String me) {
    if (isGroup) {
      final mine = myGroupLastRead;
      return messages.where((m) {
        if (m.senderId == me) return false;
        if (mine == null) return true;
        final at = DateTime.tryParse(m.insertedAt)?.toUtc();
        return at != null && at.isAfter(mine);
      }).length;
    }
    return messages.where((m) => !m.isRead && m.recipientId == me).length;
  }

  /// Conversation archivée = TOUS ses messages sont archivés (1-à-1 seulement ;
  /// un groupe n'est jamais « archivé » globalement).
  bool get isArchived =>
      !isGroup && messages.isNotEmpty && messages.every((m) => m.isArchived);

  bool matches(String q) =>
      otherName.toLowerCase().contains(q) ||
      messages.any((m) =>
          m.subject.toLowerCase().contains(q) ||
          m.body.toLowerCase().contains(q));
}

/// Construit les fils 1-à-1 (messages SANS conversation_id) regroupés par pair.
List<_Conversation> _group(List<MessageModel> all, String me) {
  final map = <String, _Conversation>{};
  for (final m in all) {
    if (m.isGroupMessage) continue; // les messages de groupe sont traités à part
    final otherId   = m.senderId == me ? m.recipientId : m.senderId;
    final otherName = m.senderId == me ? m.recipientName : m.senderName;
    final otherRole = m.counterpartRole(me);
    map
        .putIfAbsent(
            otherId,
            () => _Conversation(otherId, otherName, otherRole,
                otherAvatarUrl: m.counterpartAvatarUrl(me)))
        .messages
        .add(m);
  }
  final convs = map.values.toList();
  for (final c in convs) {
    c.messages.sort((a, b) => a.insertedAt.compareTo(b.insertedAt));
  }
  return convs;
}

/// Construit les fils de GROUPE à partir des conversations + messages associés.
List<_Conversation> _groupThreads(List<GroupConversation> convs,
    List<MessageModel> all, String me, ConvReadState reads) {
  final byConv = <String, List<MessageModel>>{};
  for (final m in all) {
    if (m.isGroupMessage) {
      byConv.putIfAbsent(m.conversationId!, () => []).add(m);
    }
  }
  final out = <_Conversation>[];
  for (final g in convs) {
    final thread = _Conversation(g.id, g.displayTitle(me), null,
        isGroup: true, group: g, myGroupLastRead: reads.myLastRead(g.id, me))
      ..messages.addAll(byConv[g.id] ?? const []);
    thread.messages.sort((a, b) => a.insertedAt.compareTo(b.insertedAt));
    out.add(thread);
  }
  return out;
}

/// Fusionne 1-à-1 + groupes, triés par dernière activité (plus récent d'abord).
List<_Conversation> _mergeThreads(
    List<_Conversation> direct, List<_Conversation> groups) {
  final all = [...direct, ...groups]
    ..sort((a, b) {
      final ax = a.messages.isEmpty ? '' : a.last.insertedAt;
      final bx = b.messages.isEmpty ? '' : b.last.insertedAt;
      return bx.compareTo(ax);
    });
  return all;
}

List<_Conversation> _applyFilter(
    List<_Conversation> convs, String me, String filter, String query) {
  Iterable<_Conversation> out = switch (filter) {
    'unread'   => convs.where((c) => c.unread(me) > 0 && !c.isArchived),
    'groups'   => convs.where((c) => c.isGroup && !c.isArchived),
    'archived' => convs.where((c) => c.isArchived),
    _          => convs.where((c) => !c.isArchived),
  };
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) out = out.where((c) => c.matches(q));
  return out.toList();
}

// ─── Écran ──────────────────────────────────────────────────────────────────────

class StaffMessagesScreen extends ConsumerStatefulWidget {
  const StaffMessagesScreen({super.key, this.initialPeerId});

  /// Interlocuteur à ouvrir directement (deep-link « Discuter » d'une
  /// publication) : ouvre la conversation existante avec cet utilisateur.
  final String? initialPeerId;

  @override
  ConsumerState<StaffMessagesScreen> createState() =>
      _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends ConsumerState<StaffMessagesScreen> {
  String? _selectedOther;

  @override
  void initState() {
    super.initState();
    _selectedOther = widget.initialPeerId;
  }
  String  _filter = 'all';
  final   _searchCtrl = TextEditingController();
  String  _query = '';

  /// Conversations cochées (sélection multiple → actions groupées).
  final _checked = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _markConversationRead(_Conversation c, String me) async {
    if (c.isGroup) {
      await markConversationReadScoped(ref, c.otherId);
      return;
    }
    for (final m in c.messages) {
      if (!m.isRead && m.recipientId == me) await markMessageReadScoped(ref, m.id);
    }
  }

  // ── Actions groupées sur les conversations cochées ──────────────────────────
  Iterable<_Conversation> _checkedConvs(List<_Conversation> all) =>
      all.where((c) => _checked.contains(c.otherId));

  Future<void> _bulkArchive(List<_Conversation> all, bool archive) async {
    for (final c in _checkedConvs(all)) {
      for (final m in c.messages) {
        await archiveMessageScoped(ref, m.id, archive);
      }
    }
    setState(() => _checked.clear());
  }

  Future<void> _bulkMarkRead(List<_Conversation> all, String me) async {
    for (final c in _checkedConvs(all)) {
      await _markConversationRead(c, me);
    }
    setState(() => _checked.clear());
  }

  void _openCompose() {
    showDialog<void>(
      context: context,
      builder: (_) => _ComposeDialog(
        onSent: (otherId) => setState(() {
          _filter = 'all';
          _selectedOther = otherId;
        }),
      ),
    );
  }

  void _openCreateGroup() {
    showDialog<void>(
      context: context,
      builder: (_) => GroupCreateDialog(
        onCreated: (convId) => setState(() {
          _filter = 'all';
          _selectedOther = convId;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me  = ref.watch(authNotifierProvider).valueOrNull;
    final uid = me?.id ?? '';
    final async = ref.watch(scopedMessagesProvider);
    final groupConvs =
        ref.watch(groupConversationsProvider).valueOrNull ?? const [];
    final reads =
        ref.watch(conversationReadProvider).valueOrNull ?? ConvReadState.empty;
    final online =
        ref.watch(onlinePresenceProvider).valueOrNull ?? const <String>{};

    return AppShell(
      title: 'Messagerie',
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const SplitSkeleton(),
        error: (e, _) => Center(
            child:
                Text('Erreur : $e', style: const TextStyle(color: kTextMuted))),
        data: (data) {
          final direct   = _group(data.messages, uid);
          final groups   = _groupThreads(groupConvs, data.messages, uid, reads);
          final convs    = _mergeThreads(direct, groups);
          final filtered = _applyFilter(convs, uid, _filter, _query);
          final selected =
              convs.where((c) => c.otherId == _selectedOther).firstOrNull;
          final wide = MediaQuery.sizeOf(context).width >= 900;

          // Plus de barre d'outils dupliquée (le titre « Messagerie » est déjà
          // dans l'en-tête AppShell). Les actions passent dans le FAB du volet
          // liste (menu montant Nouveau message / Nouveau groupe).
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: wide
                    ? Row(children: [
                        SizedBox(
                            width: 340,
                            child: _inboxPane(convs, filtered, uid, online)),
                        const VerticalDivider(width: 1, color: kBorder),
                        Expanded(
                          child: selected == null
                              ? const _NoSelection()
                              : _ThreadView(
                                  key: ValueKey(selected.otherId),
                                  conv: selected,
                                  meId: uid,
                                  groupId: me?.groupId ?? '',
                                  reads: reads,
                                  online: online,
                                  onDeselect: () =>
                                      setState(() => _selectedOther = null),
                                ),
                        ),
                      ])
                    : (selected == null
                        ? _inboxPane(convs, filtered, uid, online)
                        : _ThreadView(
                            key: ValueKey(selected.otherId),
                            conv: selected,
                            meId: uid,
                            groupId: me?.groupId ?? '',
                            reads: reads,
                            online: online,
                            onDeselect: () =>
                                setState(() => _selectedOther = null),
                            onBack: () =>
                                setState(() => _selectedOther = null),
                          )),
              ),
          );
        },
      ),
    );
  }

  // ── Volet liste : recherche + filtres + conversations + FAB ──────────────────
  Widget _inboxPane(List<_Conversation> all, List<_Conversation> filtered,
      String me, Set<String> online) {
    return Stack(children: [
      Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 13),
          decoration: adminFilledInput('Rechercher un contact, un sujet…',
                  icon: Icons.search_rounded)
              .copyWith(
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: kTextMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: _checked.isNotEmpty
            // Barre d'actions groupées (sélection multiple active)
            ? Row(children: [
                Text('${_checked.length} sél.',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
                const Spacer(),
                IconButton(
                  tooltip: 'Marquer lues',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _bulkMarkRead(all, me),
                  icon: const Icon(Icons.mark_email_read_outlined,
                      size: 18, color: kGreen),
                ),
                IconButton(
                  tooltip:
                      _filter == 'archived' ? 'Désarchiver' : 'Archiver',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _bulkArchive(all, _filter != 'archived'),
                  icon: Icon(
                      _filter == 'archived'
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                      color: kNavy),
                ),
                IconButton(
                  tooltip: 'Annuler la sélection',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _checked.clear()),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: kTextMuted),
                ),
              ])
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FilterChip(
                    label: 'Tous',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Non lus',
                    count: all
                        .where((c) => c.unread(me) > 0 && !c.isArchived)
                        .length,
                    selected: _filter == 'unread',
                    onTap: () => setState(() => _filter = 'unread'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Groupes',
                    count: all
                        .where((c) => c.isGroup && !c.isArchived)
                        .length,
                    selected: _filter == 'groups',
                    onTap: () => setState(() => _filter = 'groups'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Archivés',
                    count: all.where((c) => c.isArchived).length,
                    selected: _filter == 'archived',
                    onTap: () => setState(() => _filter = 'archived'),
                  ),
                ]),
              ),
      ),
      const Divider(height: 1, color: kBorder),
      Expanded(
        child: filtered.isEmpty
            ? _emptyList(all)
            : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kBorder),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return _ConvTile(
                    conv: c,
                    me: me,
                    online: !c.isGroup && online.contains(c.otherId),
                    selected: c.otherId == _selectedOther,
                    checked: _checked.contains(c.otherId),
                    onTap: () {
                      if (_checked.isNotEmpty) {
                        // Mode sélection : le tap coche/décoche.
                        setState(() => _checked.contains(c.otherId)
                            ? _checked.remove(c.otherId)
                            : _checked.add(c.otherId));
                        return;
                      }
                      setState(() => _selectedOther = c.otherId);
                      _markConversationRead(c, me);
                    },
                    onCheckToggle: () => setState(() =>
                        _checked.contains(c.otherId)
                            ? _checked.remove(c.otherId)
                            : _checked.add(c.otherId)),
                  );
                },
              ),
      ),
    ]),
      // FAB « nouvelle discussion » (menu montant) — style WhatsApp.
      Positioned.fill(
        child: _ComposeFab(
          onNewMessage: _openCompose,
          onNewGroup: _openCreateGroup,
        ),
      ),
    ]);
  }

  Widget _emptyList(List<_Conversation> all) {
    if (all.isEmpty) {
      final school = ref.read(communicationContextProvider).isSchool;
      return AdminEmptyState(
        icon: Icons.forum_outlined,
        title: 'Aucune conversation',
        message: school
            ? 'Démarrez un échange avec un collègue de votre école — '
                'vos messages restent disponibles hors connexion.'
            : 'Démarrez un échange avec un membre de votre réseau.',
        actionLabel: 'Nouveau message',
        onAction: _openCompose,
      );
    }
    return const AdminEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Aucun résultat',
      message: 'Aucune conversation ne correspond à votre recherche '
          'ou au filtre sélectionné.',
    );
  }
}
