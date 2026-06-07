part of 'messages_screen.dart';

// ─── Liste des messages ───────────────────────────────────────────────────────
class _MessageList extends ConsumerWidget {
  const _MessageList({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder   = ref.watch(messagesFilterProvider);
    final search   = ref.watch(_searchProv);
    final selected = ref.watch(_selectedProv);
    final ctx      = ref.watch(communicationContextProvider);
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
        break;
    }

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      msgs = msgs
          .where((m) =>
              m.subject.toLowerCase().contains(q) ||
              m.groupName.toLowerCase().contains(q) ||
              m.senderName.toLowerCase().contains(q) ||
              m.recipientName.toLowerCase().contains(q) ||
              m.body.toLowerCase().contains(q))
          .toList();
    }

    final unreadInFolder = msgs.where((m) => !m.isRead && !m.isArchived).length;

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      filled: true,
                      fillColor: _kBg,
                    ),
                  ),
                ),
                if (unreadInFolder > 0) ...[
                  const SizedBox(height: 6),
                  Text('$unreadInFolder non lu${unreadInFolder > 1 ? "s" : ""}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, color: _kNavy)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: msgs.isEmpty
                ? _EmptyList(folder: folder, hasSearch: search.isNotEmpty)
                : ListView.separated(
                    itemCount: msgs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56, color: _kBorder),
                    itemBuilder: (_, i) => _MsgTile(
                      msg: msgs[i],
                      primary: ctx.isGroup
                          ? msgs[i].counterpart(userId)
                          : msgs[i].groupName,
                      isSelected: selected?.id == msgs[i].id,
                      onTap: () async {
                        ref.read(_selectedProv.notifier).state = msgs[i];
                        if (!msgs[i].isRead) {
                          await markMessageRead(
                              ref.read(supabaseClientProvider), msgs[i].id);
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
  const _MsgTile({
    required this.msg,
    required this.primary,
    required this.isSelected,
    required this.onTap,
  });
  final MessageModel msg;
  final String primary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dt  = msg.insertedAt.isNotEmpty ? DateTime.tryParse(msg.insertedAt) : null;
    final now = DateTime.now();
    final dateStr = dt == null
        ? '—'
        : dt.year == now.year && dt.month == now.month && dt.day == now.day
            ? _fmtTime.format(dt.toLocal())
            : _fmtDay.format(dt.toLocal());

    return Material(
      color: isSelected
          ? _kNavy.withValues(alpha: 0.07)
          : msg.isRead
              ? Colors.transparent
              : const Color(0xFFF0F7FF),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: msg.isRead
                      ? _kSub.withValues(alpha: 0.1)
                      : _kNavy.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    primary.isNotEmpty ? primary[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
                          child: Text(primary,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    msg.isRead ? FontWeight.w500 : FontWeight.w800,
                                color: _kText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(dateStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: msg.isRead ? _kSub : _kNavy,
                              fontWeight:
                                  msg.isRead ? FontWeight.normal : FontWeight.w700,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(msg.body.replaceAll('\n', ' '),
                        style: const TextStyle(fontSize: 11, color: _kSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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
