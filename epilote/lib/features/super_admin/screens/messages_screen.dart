import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/school_groups_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kGreen   = Color(0xFF009A44);
const _kRed    = Color(0xFFEF4444);
const _kCard   = Colors.white;
const _kText    = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBg     = Color(0xFFF0F4F8);
const _kBorder = Color(0xFFE2E8F0);

final _fmtFull  = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtDay   = DateFormat('dd MMM', 'fr_FR');
final _fmtTime  = DateFormat('HH:mm', 'fr_FR');

// ─── Local state ──────────────────────────────────────────────────────────────
final _searchProv   = StateProvider.autoDispose<String>((ref) => '');
final _selectedProv = StateProvider.autoDispose<MessageModel?>((ref) => null);

// ─── Screen ───────────────────────────────────────────────────────────────────

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(messagesProvider);

    return AppShell(
      title: 'Messagerie',
      child: async.when(
        skipLoadingOnReload: true, skipLoadingOnRefresh: true,
        loading: () => const _Skeleton(),
        error:   (e, _) => _Err(error: e.toString(), onRetry: () => ref.invalidate(messagesProvider)),
        data:    (data) => _MailLayout(data: data),
      ),
    );
  }
}

// ─── Layout principal 3 panneaux ─────────────────────────────────────────────

class _MailLayout extends ConsumerWidget {
  const _MailLayout({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedProv);

    return Row(
      children: [
        // ── Sidebar gauche ─────────────────────────────────────────────────
        _Sidebar(data: data),
        Container(width: 1, color: _kBorder),
        // ── Liste des messages ─────────────────────────────────────────────
        SizedBox(
          width: 360,
          child: _MessageList(data: data),
        ),
        Container(width: 1, color: _kBorder),
        // ── Panneau de lecture ─────────────────────────────────────────────
        Expanded(
          child: selected == null
              ? _NoSelection()
              : _MessageReader(msg: selected),
        ),
      ],
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(messagesFilterProvider);

    return Container(
      width: 220,
      color: _kCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Bouton Composer ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: FilledButton.icon(
              onPressed: () => _showCompose(context, ref),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Nouveau message'),
              style: FilledButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),

          // ── Dossiers ──────────────────────────────────────────────────────
          _FolderItem(
            icon: Icons.inbox_rounded,
            label: 'Boîte de réception',
            value: 'inbox',
            current: folder,
            badge: data.unreadCount,
            badgeColor: _kNavy,
            onTap: () {
              ref.read(messagesFilterProvider.notifier).state = 'inbox';
              ref.read(_selectedProv.notifier).state = null;
            },
          ),
          _FolderItem(
            icon: Icons.mark_email_unread_rounded,
            label: 'Non lus',
            value: 'unread',
            current: folder,
            badge: data.unreadCount,
            badgeColor: _kRed,
            onTap: () {
              ref.read(messagesFilterProvider.notifier).state = 'unread';
              ref.read(_selectedProv.notifier).state = null;
            },
          ),
          _FolderItem(
            icon: Icons.send_rounded,
            label: 'Envoyés',
            value: 'sent',
            current: folder,
            onTap: () {
              ref.read(messagesFilterProvider.notifier).state = 'sent';
              ref.read(_selectedProv.notifier).state = null;
            },
          ),
          _FolderItem(
            icon: Icons.all_inbox_rounded,
            label: 'Tous les messages',
            value: 'all',
            current: folder,
            badge: data.totalCount,
            badgeColor: _kSub,
            onTap: () {
              ref.read(messagesFilterProvider.notifier).state = 'all';
              ref.read(_selectedProv.notifier).state = null;
            },
          ),
          _FolderItem(
            icon: Icons.archive_rounded,
            label: 'Archives',
            value: 'archived',
            current: folder,
            badge: data.archivedCount,
            badgeColor: _kSub,
            onTap: () {
              ref.read(messagesFilterProvider.notifier).state = 'archived';
              ref.read(_selectedProv.notifier).state = null;
            },
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),

          // ── Statistiques ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vue d\'ensemble',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _SidebarStat(label: 'Total messages', value: '${data.totalCount}', color: _kNavy),
                const SizedBox(height: 6),
                _SidebarStat(label: 'Non lus', value: '${data.unreadCount}', color: _kRed),
                const SizedBox(height: 6),
                _SidebarStat(label: 'Archivés', value: '${data.archivedCount}', color: _kSub),
                const SizedBox(height: 12),
                // Taux de lecture
                const Text('Taux de lecture', style: TextStyle(fontSize: 10, color: _kSub)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.totalCount > 0
                        ? (data.totalCount - data.unreadCount) / data.totalCount
                        : 0,
                    minHeight: 6,
                    backgroundColor: _kBg,
                    valueColor: const AlwaysStoppedAnimation(_kGreen),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.totalCount > 0
                      ? '${(((data.totalCount - data.unreadCount) / data.totalCount) * 100).toStringAsFixed(0)}% lus'
                      : '—',
                  style: const TextStyle(fontSize: 10, color: _kSub),
                ),
              ],
            ),
          ),

          const Spacer(),
          // ── Actualiser ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(messagesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Actualiser', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompose(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ComposeDialog(onSent: () => ref.invalidate(messagesProvider)),
    );
  }
}

class _FolderItem extends StatelessWidget {
  const _FolderItem({
    required this.icon, required this.label, required this.value,
    required this.current, required this.onTap, this.badge, this.badgeColor,
  });
  final IconData icon; final String label; final String value;
  final String current; final VoidCallback onTap;
  final int? badge; final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kNavy.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? _kNavy : _kSub),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? _kNavy : _kText,
          ))),
          if (badge != null && badge! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? _kSub).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: badgeColor ?? _kSub,
              )),
            ),
        ]),
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  const _SidebarStat({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ],
  );
}

// ─── Liste des messages ───────────────────────────────────────────────────────

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder   = ref.watch(messagesFilterProvider);
    final search   = ref.watch(_searchProv);
    final selected = ref.watch(_selectedProv);
    final userId   = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';

    var msgs = data.messages;

    switch (folder) {
      case 'inbox':
        msgs = msgs.where((m) => !m.isArchived).toList();
      case 'unread':
        msgs = msgs.where((m) => !m.isRead && !m.isArchived).toList();
      case 'sent':
        msgs = msgs.where((m) => m.senderId == userId).toList();
      case 'archived':
        msgs = msgs.where((m) => m.isArchived).toList();
      default:
        // 'all' — no filter
        break;
    }

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      msgs = msgs.where((m) =>
          m.subject.toLowerCase().contains(q) ||
          m.groupName.toLowerCase().contains(q) ||
          m.body.toLowerCase().contains(q)).toList();
    }

    final unreadInFolder = msgs.where((m) => !m.isRead && !m.isArchived).length;

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────────────
          Container(
            color: _kCard,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (v) => ref.read(_searchProv.notifier).state = v,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher…',
                      hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _kSub),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      filled: true, fillColor: _kBg,
                    ),
                  ),
                ),
                if (unreadInFolder > 0) ...[
                  const SizedBox(height: 6),
                  Text('$unreadInFolder non lu${unreadInFolder > 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kNavy)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // ── Tiles ──────────────────────────────────────────────────────
          Expanded(
            child: msgs.isEmpty
                ? _EmptyList(folder: folder, hasSearch: search.isNotEmpty)
                : ListView.separated(
                    itemCount: msgs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: _kBorder),
                    itemBuilder: (_, i) => _MsgTile(
                      msg: msgs[i],
                      isSelected: selected?.id == msgs[i].id,
                      onTap: () async {
                        ref.read(_selectedProv.notifier).state = msgs[i];
                        if (!msgs[i].isRead) {
                          await markMessageRead(ref.read(supabaseClientProvider), msgs[i].id);
                          ref.invalidate(messagesProvider);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MsgTile extends StatelessWidget {
  const _MsgTile({required this.msg, required this.isSelected, required this.onTap});
  final MessageModel msg; final bool isSelected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dt      = msg.insertedAt.isNotEmpty ? DateTime.tryParse(msg.insertedAt) : null;
    final now     = DateTime.now();
    final dateStr = dt == null
        ? '—'
        : dt.year == now.year && dt.month == now.month && dt.day == now.day
            ? _fmtTime.format(dt.toLocal())
            : _fmtDay.format(dt.toLocal());

    return Material(
      color: isSelected
          ? _kNavy.withValues(alpha: 0.07)
          : msg.isRead ? Colors.transparent : const Color(0xFFF0F7FF),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar lettre
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: msg.isRead
                      ? _kSub.withValues(alpha: 0.1)
                      : _kNavy.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    msg.groupName.isNotEmpty ? msg.groupName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: msg.isRead ? _kSub : _kNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(msg.groupName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: msg.isRead ? FontWeight.w500 : FontWeight.w800,
                                color: _kText,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(dateStr, style: TextStyle(
                          fontSize: 10,
                          color: msg.isRead ? _kSub : _kNavy,
                          fontWeight: msg.isRead ? FontWeight.normal : FontWeight.w700,
                        )),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(msg.subject,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: msg.isRead ? FontWeight.normal : FontWeight.w600,
                          color: msg.isRead ? _kSub : _kText,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(msg.body.replaceAll('\n', ' '),
                        style: const TextStyle(fontSize: 11, color: _kSub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Panneau de lecture ───────────────────────────────────────────────────────

class _MessageReader extends ConsumerStatefulWidget {
  const _MessageReader({required this.msg});
  final MessageModel msg;

  @override
  ConsumerState<_MessageReader> createState() => _MessageReaderState();
}

class _MessageReaderState extends ConsumerState<_MessageReader> {
  bool _showReply = false;

  @override
  Widget build(BuildContext context) {
    final dt = widget.msg.insertedAt.isNotEmpty
        ? DateTime.tryParse(widget.msg.insertedAt)
        : null;
    final dateStr = dt != null ? _fmtFull.format(dt.toLocal()) : '—';

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          // ── Header du message ────────────────────────────────────────────
          Container(
            color: _kCard,
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(widget.msg.subject,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kText)),
                    ),
                    // Actions
                    _ActionBtn(
                      icon: Icons.reply_rounded,
                      label: 'Répondre',
                      color: _kNavy,
                      onTap: () => setState(() => _showReply = !_showReply),
                    ),
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: widget.msg.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                      label: widget.msg.isArchived ? 'Désarchiver' : 'Archiver',
                      color: _kSub,
                      onTap: () async {
                        final client = ref.read(supabaseClientProvider);
                        if (widget.msg.isArchived) {
                          await unarchiveMessage(client, widget.msg.id);
                        } else {
                          await archiveMessage(client, widget.msg.id);
                        }
                        ref.read(_selectedProv.notifier).state = null;
                        ref.invalidate(messagesProvider);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: _kSub,
                      onPressed: () => ref.read(_selectedProv.notifier).state = null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _MetaItem(icon: Icons.corporate_fare_rounded, label: widget.msg.groupName),
                  _MetaItem(icon: Icons.schedule_rounded, label: dateStr),
                  if (!widget.msg.isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Non lu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kNavy)),
                    ),
                  if (widget.msg.isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kSub.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Archivé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
                    ),
                ]),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // ── Corps du message ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: SelectableText(
                      widget.msg.body,
                      style: const TextStyle(fontSize: 14, color: _kText, height: 1.7),
                    ),
                  ),

                  // ── Zone de réponse ───────────────────────────────────────
                  if (_showReply) ...[
                    const SizedBox(height: 20),
                    _ReplyForm(
                      msg: widget.msg,
                      onCancel: () => setState(() => _showReply = false),
                      onSent: () {
                        setState(() => _showReply = false);
                        ref.invalidate(messagesProvider);
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Barre d'action rapide ────────────────────────────────────────
          if (!_showReply)
            Container(
              color: _kCard,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showReply = true),
                  icon: const Icon(Icons.reply_rounded, size: 14),
                  label: const Text('Répondre'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy, side: const BorderSide(color: _kNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final client = ref.read(supabaseClientProvider);
                    if (widget.msg.isArchived) {
                      await unarchiveMessage(client, widget.msg.id);
                    } else {
                      await archiveMessage(client, widget.msg.id);
                    }
                    ref.read(_selectedProv.notifier).state = null;
                    ref.invalidate(messagesProvider);
                  },
                  icon: Icon(
                    widget.msg.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                    size: 14,
                  ),
                  label: Text(widget.msg.isArchived ? 'Désarchiver' : 'Archiver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSub, side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton(
      icon: Icon(icon, size: 18),
      color: color,
      onPressed: onTap,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: _kSub),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: _kSub)),
    ],
  );
}

// ─── Formulaire de réponse ────────────────────────────────────────────────────

class _ReplyForm extends ConsumerStatefulWidget {
  const _ReplyForm({required this.msg, required this.onCancel, required this.onSent});
  final MessageModel msg; final VoidCallback onCancel; final VoidCallback onSent;

  @override
  ConsumerState<_ReplyForm> createState() => _ReplyFormState();
}

class _ReplyFormState extends ConsumerState<_ReplyForm> {
  final _ctrl    = TextEditingController();
  bool  _sending = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNavy.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.reply_rounded, size: 14, color: _kNavy),
              const SizedBox(width: 6),
              Text('Répondre à ${widget.msg.groupName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: _kSub, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: widget.onCancel,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Écrivez votre réponse…',
                hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(foregroundColor: _kSub),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Envoyer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    if (widget.msg.senderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de répondre : expéditeur inconnu'), backgroundColor: _kRed));
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id ?? '';
      await sendMessage(
        client:      client,
        senderId:    userId,
        recipientId: widget.msg.senderId,
        groupId:     widget.msg.groupId,
        subject:     'RE: ${widget.msg.subject}',
        body:        _ctrl.text.trim(),
        parentId:    widget.msg.id,
      );
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réponse envoyée !'), backgroundColor: _kGreen));
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

// ─── Dialogue de composition ──────────────────────────────────────────────────

class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog({required this.onSent});
  final VoidCallback onSent;

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String? _groupId;
  bool    _sending   = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(schoolGroupsProvider);

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
              // Titre
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_rounded, color: _kNavy, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouveau message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                    Text('Envoyer un message à un groupe scolaire', style: TextStyle(fontSize: 11, color: _kSub)),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: _kSub),
              ]),
              const SizedBox(height: 20),

              // Destinataire
              const Text('Destinataire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              groupsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur chargement groupes', style: TextStyle(color: _kRed, fontSize: 12)),
                data: (data) => DropdownButtonFormField<String>(
                  value: _groupId,
                  hint: const Text('Sélectionner un groupe…', style: TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => _groupId = v),
                  items: data.groups.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                    filled: true, fillColor: _kBg,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Objet
              const Text('Objet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              TextField(
                controller: _subjectCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Objet du message…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                  filled: true, fillColor: _kBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Corps
              const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 6,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rédigez votre message…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                  filled: true, fillColor: _kBg,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub, side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy, foregroundColor: Colors.white,
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

  Future<void> _submit() async {
    if (_groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez un destinataire')));
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'objet est requis')));
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le message est vide')));
      return;
    }

    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id ?? '';
      final recipientId = await groupAdminRecipient(client, _groupId!);
      if (recipientId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ce groupe n\'a pas d\'administrateur actif'), backgroundColor: _kRed));
          setState(() => _sending = false);
        }
        return;
      }
      await sendMessage(
        client:      client,
        senderId:    userId,
        recipientId: recipientId,
        groupId:     _groupId!,
        subject:     _subjectCtrl.text.trim(),
        body:        _bodyCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message envoyé avec succès !'), backgroundColor: _kGreen));
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

// ─── États vides / utilitaires ────────────────────────────────────────────────

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.folder, required this.hasSearch});
  final String folder; final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = hasSearch
        ? (Icons.search_off_rounded, 'Aucun résultat', 'Modifiez votre recherche')
        : switch (folder) {
            'unread'   => (Icons.mark_email_read_rounded, 'Tout est lu !', 'Aucun message non lu'),
            'sent'     => (Icons.outbox_rounded, 'Aucun message envoyé', 'Vos messages envoyés apparaîtront ici'),
            'archived' => (Icons.archive_rounded, 'Archives vides', 'Aucun message archivé'),
            _          => (Icons.inbox_rounded, 'Aucun message', 'Votre boîte de réception est vide'),
          };

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kSub)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 12, color: _kSub)),
      ]),
    );
  }
}

class _NoSelection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFFAFBFC),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mail_outline_rounded, size: 40, color: _kNavy),
        ),
        const SizedBox(height: 20),
        const Text('Sélectionnez un message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 8),
        const Text('Cliquez sur un message dans la liste pour le lire',
            style: TextStyle(fontSize: 13, color: _kSub)),
      ]),
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 220, color: _kCard),
    Container(width: 1, color: _kBorder),
    SizedBox(width: 360, child: ListView.builder(
      itemCount: 8,
      itemBuilder: (_, _) => Container(
        height: 72, margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      ),
    )),
    Container(width: 1, color: _kBorder),
    const Expanded(child: SizedBox()),
  ]);
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
    const SizedBox(height: 12),
    Text(error, style: const TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer'),
      style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white)),
  ]));
}
