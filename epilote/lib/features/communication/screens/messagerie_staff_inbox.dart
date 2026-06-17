part of 'messagerie_staff.dart';

// ─── Chip de filtre ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kNavy : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kNavy : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kTextMuted)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.20)
                    : kNavy.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : kNavy)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Tuile de conversation ──────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  const _ConvTile({
    required this.conv,
    required this.me,
    required this.selected,
    required this.onTap,
    this.online = false,
    this.checked = false,
    this.onCheckToggle,
  });
  final _Conversation conv;
  final String me;
  final bool selected;
  final VoidCallback onTap;

  /// Interlocuteur (1-à-1) actuellement en ligne → pastille verte.
  final bool online;

  /// Sélection multiple (actions groupées) : cochée + bascule (clic avatar
  /// ou appui long sur la tuile, comme Gmail).
  final bool checked;
  final VoidCallback? onCheckToggle;

  @override
  Widget build(BuildContext context) {
    final unread   = conv.unread(me);
    final hasMsg   = conv.messages.isNotEmpty;
    final last     = hasMsg ? conv.last : null;
    final mine     = last?.senderId == me;
    // Groupe : préfixe l'aperçu par le prénom de l'expéditeur.
    final senderPrefix = conv.isGroup && last != null && !mine
        ? '${last.senderName.split(' ').first} : '
        : (mine ? 'Vous : ' : '');
    final preview = !hasMsg
        ? (conv.isGroup ? 'Nouveau groupe' : '')
        : '$senderPrefix${last!.body.isEmpty ? "Pièce jointe" : last.body}';

    return InkWell(
      onTap: onTap,
      onLongPress: onCheckToggle,
      child: Container(
        color: checked
            ? kNavy.withValues(alpha: 0.06)
            : (selected ? kSurface : Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          InkWell(
            onTap: onCheckToggle,
            borderRadius: BorderRadius.circular(20),
            child: checked
                ? const CircleAvatar(
                    radius: 18,
                    backgroundColor: kNavy,
                    child: Icon(Icons.check_rounded,
                        size: 20, color: Colors.white))
                : conv.isGroup
                    ? GroupAvatarImage(avatarUrl: conv.group?.avatarUrl)
                    : _PresenceAvatar(
                        name: conv.otherName,
                        role: conv.otherRole,
                        avatarUrl: conv.otherAvatarUrl,
                        online: online),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (conv.isGroup) ...[
                    const Icon(Icons.groups_rounded,
                        size: 14, color: kNavy),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(conv.otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: kTextPrimary,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600)),
                  ),
                  if (last != null)
                    Text(_relativeTime(last.insertedAt),
                        style:
                            const TextStyle(fontSize: 10, color: kTextMuted)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  if (conv.isArchived) ...[
                    const Icon(Icons.archive_outlined,
                        size: 12, color: kTextMuted),
                    const SizedBox(width: 4),
                  ],
                  if (last != null && last.attachments.isNotEmpty) ...[
                    const Icon(Icons.attach_file_rounded,
                        size: 12, color: kTextMuted),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: hasMsg
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: unread > 0 ? kTextPrimary : kTextMuted)),
                  ),
                ]),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}

// ─── FAB « nouvelle discussion » avec menu montant (style WhatsApp) ────────────

class _ComposeFab extends StatefulWidget {
  const _ComposeFab({required this.onNewMessage, required this.onNewGroup});
  final VoidCallback onNewMessage;
  final VoidCallback onNewGroup;

  @override
  State<_ComposeFab> createState() => _ComposeFabState();
}

class _ComposeFabState extends State<_ComposeFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);
  void _close() => setState(() => _open = false);

  void _pick(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Scrim de fermeture (tap hors menu).
      if (_open)
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.withValues(alpha: 0.04)),
          ),
        ),
      Positioned(
        right: 16,
        bottom: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_open) ...[
              _MiniAction(
                label: 'Nouveau groupe',
                icon: Icons.group_add_rounded,
                color: const Color(0xFF1FA855),
                onTap: () => _pick(widget.onNewGroup),
              ),
              const SizedBox(height: 12),
              _MiniAction(
                label: 'Nouveau message',
                icon: Icons.person_add_alt_1_rounded,
                color: kNavy,
                onTap: () => _pick(widget.onNewMessage),
              ),
              const SizedBox(height: 14),
            ],
            // FAB principal
            Material(
              color: const Color(0xFF00A884),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _open ? 0.125 : 0,
                    child: Icon(
                        _open
                            ? Icons.close_rounded
                            : Icons.chat_rounded,
                        color: Colors.white,
                        size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Étiquette
      Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ),
      ),
      const SizedBox(width: 12),
      // Mini-bouton
      Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    ]);
  }
}

// ─── Avatar + pastille de présence (en ligne) ──────────────────────────────────

class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar(
      {required this.name, this.role, this.avatarUrl, this.online = false,
       this.radius = 18});
  final String  name;
  final String? role;
  final String? avatarUrl;
  final bool    online;
  final double  radius;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _Avatar(name: name, role: role, avatarUrl: avatarUrl, radius: radius),
      if (online)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.62,
            height: radius * 0.62,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853), // vert « en ligne »
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ]);
  }
}

// ─── Avatar initiales (couleur = identité du rôle) ──────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.name, this.role, this.avatarUrl, this.radius = 18});
  final String  name;
  final String? role;
  final String? avatarUrl;
  final double  radius;

  @override
  Widget build(BuildContext context) {
    // Photo de profil avec repli initiales (rendu partagé).
    return UserAvatarCircle(
        name: name, role: role, avatarUrl: avatarUrl, radius: radius);
  }
}
