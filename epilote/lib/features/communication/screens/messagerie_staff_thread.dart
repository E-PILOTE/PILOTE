part of 'messagerie_staff.dart';

// ─── Palette WhatsApp (zone conversation uniquement) ───────────────────────────
const _waBg        = Color(0xFFECE5DD); // fond beige « papier peint »
const _waOutgoing  = Color(0xFFD9FDD3); // bulle envoyée (vert clair)
const _waIncoming  = Colors.white;      // bulle reçue
const _waText      = Color(0xFF111B21); // texte des bulles (sombre)
const _waTime      = Color(0xFF667781); // horodatage / méta
const _waTickRead  = Color(0xFF53BDEB); // double coche « lu » (bleu)
const _waInputBg   = Color(0xFFF0F2F5); // barre de saisie

/// Fond « papier peint » WhatsApp : beige + motif de points très discret.
class _ChatWallpaper extends StatelessWidget {
  const _ChatWallpaper({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        color: _waBg,
        child: CustomPaint(
          painter: _DoodlePainter(),
          child: child,
        ),
      );
}

class _DoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.022)
      ..style = PaintingStyle.fill;
    const step = 46.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        // Petit décalage en quinconce
        final dx = (y / step).floor().isEven ? 0.0 : step / 2;
        canvas.drawCircle(Offset(x + dx, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Fil de conversation (panneau droit / plein écran mobile) ───────────────────

class _ThreadView extends ConsumerStatefulWidget {
  const _ThreadView({
    super.key,
    required this.conv,
    required this.meId,
    required this.groupId,
    required this.reads,
    required this.online,
    required this.onDeselect,
    this.onBack,
  });

  final _Conversation conv;
  final String meId;
  final String groupId;

  /// Accusés de lecture par membre (conversations de groupe).
  final ConvReadState reads;

  /// Ensemble des id en ligne (pastille verte + « en ligne »).
  final Set<String> online;

  /// Ferme le fil (après archivage / marquage non lu).
  final VoidCallback onDeselect;

  /// Bouton retour (mode étroit < 900 px uniquement).
  final VoidCallback? onBack;

  @override
  ConsumerState<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<_ThreadView> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _uploading = false;
  bool _showEmoji = false;
  final List<MessageAttachment> _pending = [];

  /// Message cité (réponse) ou message en cours d'édition — exclusifs.
  MessageModel? _replyTo;
  MessageModel? _editing;

  /// Recherche dans le fil (loupe header).
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  /// Enregistrement de note vocale en cours (bandeau + chrono).
  bool _recording = false;
  Duration _recElapsed = Duration.zero;
  bool _recCancel = false;

  // ── « En train d'écrire » via Supabase Realtime Broadcast (100 % Supabase) ──
  RealtimeChannel? _typingChannel;
  String? _typingName;        // nom de l'autre qui écrit (null = personne)
  Timer? _typingClear;        // efface l'indicateur entrant après inactivité
  Timer? _typingThrottle;     // throttle l'émission de mes frappes
  bool _typingSent = false;   // ai-je déjà signalé que je tape ?

  /// Clé de canal stable et partagée par les 2 côtés d'une conversation.
  String get _typingKey {
    if (widget.conv.isGroup) return 'conv_${widget.conv.otherId}';
    final pair = [widget.meId, widget.conv.otherId]..sort();
    return 'dm_${pair.join('_')}';
  }

  void _initTyping() {
    final client = ref.read(supabaseClientProvider);
    final ch = client.channel('typing:$_typingKey',
        opts: const RealtimeChannelConfig(self: false));
    ch.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final uid = payload['user_id'] as String?;
        if (uid == null || uid == widget.meId) return;
        final typing = payload['typing'] as bool? ?? false;
        if (!mounted) return;
        setState(() => _typingName = typing ? payload['name'] as String? : null);
        _typingClear?.cancel();
        if (typing) {
          _typingClear = Timer(const Duration(seconds: 5),
              () => mounted ? setState(() => _typingName = null) : null);
        }
      },
    );
    ch.subscribe();
    _typingChannel = ch;
  }

  /// Émet « je tape » (throttlé) puis « j'ai arrêté » après 3 s d'inactivité.
  void _emitTyping() {
    final me = ref.read(authNotifierProvider).valueOrNull;
    void send(bool typing) {
      _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': widget.meId,
          'name': me == null ? '' : '${me.firstName} ${me.lastName}'.trim(),
          'typing': typing,
        },
      );
    }

    if (!_typingSent) {
      _typingSent = true;
      send(true);
    }
    _typingThrottle?.cancel();
    _typingThrottle = Timer(const Duration(seconds: 3), () {
      _typingSent = false;
      send(false);
    });
  }

  void _stopTyping() {
    _typingThrottle?.cancel();
    if (_typingSent) {
      _typingSent = false;
      _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': widget.meId, 'typing': false},
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _typingClear?.cancel();
    _typingThrottle?.cancel();
    _typingChannel?.unsubscribe(); // pas de `ref` après dispose
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _markIncomingRead();
    _initTyping();
  }

  @override
  void didUpdateWidget(covariant _ThreadView old) {
    super.didUpdateWidget(old);
    // Nouveau message reçu pendant que le fil est ouvert → accusé de lecture.
    // (Un groupe vide n'a pas de « dernier message » → comparaison sûre.)
    if (old.conv.lastOrNull?.id != widget.conv.lastOrNull?.id) {
      _markIncomingRead();
    }
  }

  Future<void> _markIncomingRead() async {
    // Groupe : pousse mon accusé de lecture (last_read_at).
    if (widget.conv.isGroup) {
      await markConversationReadScoped(ref, widget.conv.otherId);
      return;
    }
    for (final m in widget.conv.messages) {
      if (!m.isRead && m.recipientId == widget.meId) {
        await markMessageReadScoped(ref, m.id);
      }
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  /// group_id de la conversation : métadonnées du groupe d'abord (fiable même
  /// pour un groupe vide créé par super_admin sans groupe propre), puis dernier
  /// message, puis mon groupe. Évite un group_id vide ("") → erreur UUID.
  String get _convGroup {
    final fromGroup = widget.conv.group?.groupId ?? '';
    if (fromGroup.isNotEmpty) return fromGroup;
    final msgs = widget.conv.messages;
    if (msgs.isNotEmpty && msgs.last.groupId.isNotEmpty) {
      return msgs.last.groupId;
    }
    return widget.groupId;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    // Édition d'un message existant.
    if (_editing != null) {
      if (text.isEmpty) return;
      setState(() => _sending = true);
      try {
        await editMessageScoped(ref, _editing!.id, text);
        _ctrl.clear();
        setState(() {
          _editing = null;
          _showEmoji = false;
        });
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }
    if ((text.isEmpty && _pending.isEmpty) || widget.meId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final convGroup = _convGroup;
      final replyId = _replyTo?.id;
      if (widget.conv.isGroup) {
        await sendGroupMessageScoped(
          ref,
          conversationId: widget.conv.otherId,
          groupId:        convGroup,
          body:           text,
          attachments:    List.of(_pending),
          parentId:       replyId,
        );
      } else {
        final root = widget.conv.first;
        await sendMessageScoped(
          ref,
          senderId:    widget.meId,
          recipientId: widget.conv.otherId,
          groupId:     convGroup,
          subject:     'RE: ${baseSubject(root.subject)}',
          body:        text,
          attachments: List.of(_pending),
          // parentId UNIQUEMENT pour une vraie réponse citée (sinon null :
          // le regroupement 1-à-1 se fait par interlocuteur, pas par parentId).
          parentId:    replyId,
        );
      }
      _ctrl.clear();
      _stopTyping();
      setState(() {
        _pending.clear();
        _replyTo = null;
        _showEmoji = false;
      });
    } catch (e) {
      // Échec courant : session expirée → l'insert viole la RLS messages.
      if (mounted) {
        final s = e.toString().toLowerCase();
        final msg = (s.contains('row-level security') || s.contains('42501'))
            ? 'Session expirée — reconnectez-vous pour envoyer.'
            : "Échec de l'envoi : $e";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Actions sur un message (réagir / répondre / transférer / modifier) ────────

  void _startReply(MessageModel m) => setState(() {
        _editing = null;
        _replyTo = m;
      });

  void _startEdit(MessageModel m) => setState(() {
        _replyTo = null;
        _editing = m;
        _ctrl.text = m.body;
        _ctrl.selection =
            TextSelection.collapsed(offset: _ctrl.text.length);
      });

  void _cancelComposeContext() => setState(() {
        _replyTo = null;
        if (_editing != null) _ctrl.clear();
        _editing = null;
      });

  Future<void> _react(MessageModel m, String emoji) =>
      toggleReactionScoped(ref, msg: m, emoji: emoji, myId: widget.meId);

  Future<void> _forward(MessageModel m) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ForwardMessageDialog(source: m),
    );
  }

  /// Joint des fichiers. [imagesOnly] = bouton photo (galerie d'images) ;
  /// sinon bouton document (tout type). Upload Storage → nécessite internet.
  Future<void> _attach({bool imagesOnly = false}) async {
    setState(() => _uploading = true);
    try {
      // Dossier Storage = groupe de la conversation (RLS : les 2 parties le lisent).
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: _convGroup,
        bucket: 'message-attachments',
        imagesOnly: imagesOnly,
      );
      if (mounted) setState(() => _pending.addAll(added));
    } on AttachmentUploadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Envoie une note vocale enregistrée (appui maintenu façon WhatsApp).
  Future<void> _sendRecordedAudio(MessageAttachment audio) async {
    setState(() => _sending = true);
    try {
      final convGroup = _convGroup;
      if (widget.conv.isGroup) {
        await sendGroupMessageScoped(
          ref,
          conversationId: widget.conv.otherId,
          groupId:        convGroup,
          body:           '',
          attachments:    [audio],
        );
      } else {
        final root = widget.conv.first;
        await sendMessageScoped(
          ref,
          senderId:    widget.meId,
          recipientId: widget.conv.otherId,
          groupId:     convGroup,
          subject:     'RE: ${baseSubject(root.subject)}',
          body:        '',
          attachments: [audio],
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(MessageModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le message ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await deleteMessageScoped(ref, m.id);
  }

  /// Accusé de lecture d'un de MES messages de groupe : combien d'autres membres
  /// l'ont lu (last_read_at ≥ created_at) sur le total des autres membres.
  ({int readBy, int total}) _groupReceipt(MessageModel m) {
    final total = (widget.conv.group?.memberCount ?? 1) - 1;
    final at = DateTime.tryParse(m.insertedAt)?.toUtc();
    final readBy = at == null
        ? 0
        : widget.reads.readByCount(widget.conv.otherId, widget.meId, at);
    return (readBy: readBy < 0 ? 0 : readBy, total: total < 0 ? 0 : total);
  }

  /// Feuille « Lu par » : liste des membres et leur statut de lecture.
  void _showReadInfo(MessageModel m) {
    final g = widget.conv.group;
    if (g == null) return;
    final at = DateTime.tryParse(m.insertedAt)?.toUtc();
    final reads = widget.reads.membersOf(widget.conv.otherId);
    final others = g.members.where((mem) => mem.userId != widget.meId).toList();
    final read = <ConvMember>[];
    final notRead = <ConvMember>[];
    for (final mem in others) {
      final last = reads[mem.userId];
      if (at != null && last != null && !last.isBefore(at)) {
        read.add(mem);
      } else {
        notRead.add(mem);
      }
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.done_all_rounded, size: 18, color: _waTickRead),
                const SizedBox(width: 8),
                Text('Lu par ${read.length}/${others.length}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ]),
              const SizedBox(height: 14),
              if (read.isNotEmpty) ...[
                const _ReadInfoLabel('Lu', _waTickRead),
                for (final mem in read) _ReadInfoRow(member: mem, read: true),
                const SizedBox(height: 8),
              ],
              if (notRead.isNotEmpty) ...[
                const _ReadInfoLabel('Non lu', kTextMuted),
                for (final mem in notRead) _ReadInfoRow(member: mem, read: false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openGroupSettings() {
    final g = widget.conv.group;
    if (g == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => GroupSettingsDialog(
        group: g,
        myId: widget.meId,
        onChanged: () {},
        onDeleted: widget.onDeselect,
      ),
    );
  }

  Future<void> _deleteDirectConversation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la discussion ?'),
        content: Text(
            'Tous les messages échangés avec ${widget.conv.otherName} seront '
            'définitivement supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await deleteDirectConversationScoped(
        ref, widget.conv.messages.map((m) => m.id).toList());
    widget.onDeselect();
  }

  Future<void> _toggleArchive() async {
    final target = !widget.conv.isArchived;
    for (final m in widget.conv.messages) {
      await archiveMessageScoped(ref, m.id, target);
    }
    widget.onDeselect();
  }

  Future<void> _markUnread() async {
    // Re-marque non lus les messages REÇUS (au moins le dernier).
    final received =
        widget.conv.messages.where((m) => m.recipientId == widget.meId);
    if (received.isEmpty) return;
    await markMessageUnreadScoped(ref, received.last.id);
    widget.onDeselect();
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  /// Bulles + séparateurs de jour (« Aujourd'hui », « Hier », date), construits
  /// du plus ancien au plus récent puis inversés (ListView reverse:true).
  List<Widget> _buildThreadItems(List<MessageModel> msgs) {
    final byId = {for (final m in msgs) m.id: m};
    final q = _searchQuery.trim().toLowerCase();
    final visible = q.isEmpty
        ? msgs
        : msgs.where((m) => m.body.toLowerCase().contains(q)).toList();
    final items = <Widget>[];
    DateTime? lastDay;
    for (final m in visible) {
      final dt  = DateTime.tryParse(m.insertedAt)?.toLocal();
      final day = dt == null ? null : DateTime(dt.year, dt.month, dt.day);
      if (day != null && day != lastDay) {
        items.add(_DaySeparator(day: day));
        lastDay = day;
      }
      final mine = m.senderId == widget.meId;
      // Parent cité (réponse) résolu dans le fil. En 1-à-1, les anciens
      // messages portaient parentId = racine du fil (threading historique) :
      // ce n'est PAS une citation → on l'exclut.
      final rootId = msgs.isEmpty ? null : msgs.first.id;
      final parent = (m.parentId != null &&
              m.parentId != m.id &&
              (widget.conv.isGroup || m.parentId != rootId))
          ? byId[m.parentId]
          : null;
      final quoted = parent;
      // Accusés de lecture de groupe (mes messages uniquement).
      final receipt =
          (widget.conv.isGroup && mine) ? _groupReceipt(m) : null;
      items.add(_Bubble(
        msg: m,
        mine: mine,
        myId: widget.meId,
        showSender: widget.conv.isGroup,
        quoted: quoted,
        highlight: q,
        groupReadBy: receipt?.readBy,
        groupReadTotal: receipt?.total,
        onReact: (e) => _react(m, e),
        onReply: () => _startReply(m),
        onForward: () => _forward(m),
        onInfo: receipt != null ? () => _showReadInfo(m) : null,
        onEdit: mine && m.body.trim().isNotEmpty ? () => _startEdit(m) : null,
        onDelete: mine ? () => _confirmDelete(m) : null,
      ));
    }
    return items.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final msgs     = widget.conv.messages;
    final archived = widget.conv.isArchived;
    final hasReceived =
        msgs.any((m) => m.recipientId == widget.meId);
    final otherOnline =
        !widget.conv.isGroup && widget.online.contains(widget.conv.otherId);

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: kNavy),
            ),
          // En-tête tappable pour un groupe → ouvre « Infos du groupe ».
          Expanded(
            child: InkWell(
              onTap: widget.conv.isGroup ? _openGroupSettings : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  if (widget.conv.isGroup)
                    GroupAvatarImage(
                        avatarUrl: widget.conv.group?.avatarUrl, radius: 16)
                  else
                    _PresenceAvatar(
                        name: widget.conv.otherName,
                        role: widget.conv.otherRole,
                        avatarUrl: widget.conv.otherAvatarUrl,
                        online: otherOnline,
                        radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(widget.conv.otherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary)),
                          ),
                          if (!widget.conv.isGroup &&
                              widget.conv.otherRole != null) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: roleColor(widget.conv.otherRole)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(roleLabelFr(widget.conv.otherRole),
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          roleColor(widget.conv.otherRole))),
                            ),
                          ],
                        ]),
                        if (_typingName != null)
                          Text(
                              widget.conv.isGroup
                                  ? '$_typingName est en train d\'écrire…'
                                  : 'en train d\'écrire…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF00A884)))
                        else if (otherOnline)
                          const Text('en ligne',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00A884)))
                        else
                          Text(
                              widget.conv.isGroup
                                  ? '${widget.conv.group?.memberCount ?? 0} membres · appuyer pour les infos'
                                  : (msgs.isEmpty
                                      ? ''
                                      : baseSubject(widget.conv.first.subject)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: kTextMuted)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // Actions à droite.
          _ThreadAction(
            icon: _searching ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
            onTap: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchCtrl.clear();
                _searchQuery = '';
              }
            }),
          ),
          if (widget.conv.isGroup)
            _ThreadAction(
              icon: Icons.info_outline_rounded,
              tooltip: 'Infos du groupe',
              onTap: _openGroupSettings,
            )
          else ...[
            if (archived)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: AdminBadge('Archivée',
                    color: kTextMuted, icon: Icons.archive_outlined),
              ),
            if (hasReceived && !archived)
              _ThreadAction(
                icon: Icons.mark_email_unread_outlined,
                tooltip: 'Marquer non lu',
                onTap: _markUnread,
              ),
            _ThreadAction(
              icon: archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              tooltip: archived
                  ? 'Désarchiver la conversation'
                  : 'Archiver la conversation',
              onTap: _toggleArchive,
            ),
            _ThreadMenu(onDelete: _deleteDirectConversation),
          ],
        ]),
      ),
      if (_searching)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          color: Colors.white,
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher dans la conversation…',
              hintStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
              isDense: true,
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder)),
            ),
          ),
        ),
      Expanded(
        child: _ChatWallpaper(
          // SelectionArea : le texte des bulles devient sélectionnable/copiable
          // (glisser à la souris sur desktop) ; l'appui long garde son menu.
          child: SelectionArea(
            child: ListView(
              reverse: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              children: _buildThreadItems(msgs),
            ),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        color: _waInputBg,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Bandeau « réponse à… » / « modification ».
          if (_replyTo != null || _editing != null)
            _ComposeContextBar(
              editing: _editing != null,
              title: _editing != null
                  ? 'Modifier le message'
                  : 'Réponse à ${_replyTo!.senderId == widget.meId ? 'vous' : _replyTo!.senderName}',
              preview: (_editing ?? _replyTo)!.body,
              onCancel: _cancelComposeContext,
            ),
          // Pièces jointes en attente d'envoi.
          if (_pending.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: CommAttachmentEditList(
                items: _pending,
                onRemove: (i) => setState(() => _pending.removeAt(i)),
              ),
            ),
          Builder(builder: (context) {
            final hasContent = _ctrl.text.trim().isNotEmpty ||
                _pending.isNotEmpty ||
                _editing != null;
            return Row(children: [
              if (!_recording)
                IconButton(
                  onPressed: () => setState(() => _showEmoji = !_showEmoji),
                  tooltip: 'Emoji',
                  icon: Icon(Icons.emoji_emotions_outlined,
                      size: 20, color: _showEmoji ? kAccent : kTextMuted),
                ),
              if (_recording)
                AudioRecordingBanner(
                    elapsed: _recElapsed, cancel: _recCancel)
              else ...[
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (v) {
                      setState(() {});
                      if (v.trim().isNotEmpty) _emitTyping();
                    },
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Répondre à ${widget.conv.otherName}…',
                      hintStyle:
                          const TextStyle(color: kTextMuted, fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // Document (tout type).
                IconButton(
                  onPressed: _uploading ? null : () => _attach(),
                  tooltip: 'Joindre un document',
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file_rounded,
                          size: 20, color: kTextMuted),
                ),
                // Photo / galerie d'images.
                IconButton(
                  onPressed:
                      _uploading ? null : () => _attach(imagesOnly: true),
                  tooltip: 'Envoyer une photo',
                  icon: const Icon(Icons.image_outlined,
                      size: 21, color: kTextMuted),
                ),
              ],
              const SizedBox(width: 8),
              // Envoi (texte / pièces jointes / édition) OU micro (appui maintenu).
              if (hasContent && !_recording)
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: _editing != null ? 'Enregistrer' : 'Envoyer',
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      padding: const EdgeInsets.all(12)),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          _editing != null
                              ? Icons.check_rounded
                              : Icons.send_rounded,
                          size: 18),
                )
              else
                AudioRecorderButton(
                  key: const ValueKey('mic'),
                  client: ref.read(supabaseClientProvider),
                  groupId: _convGroup,
                  onRecordingChanged: (r) => setState(() {
                    _recording = r;
                    if (!r) _recCancel = false;
                    if (r) _showEmoji = false;
                  }),
                  onProgress: (e, c) => setState(() {
                    _recElapsed = e;
                    _recCancel = c;
                  }),
                  onRecorded: (att) => _sendRecordedAudio(att),
                  onError: (m) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(m), backgroundColor: kRed));
                    }
                  },
                ),
            ]);
          }),
          if (_showEmoji && !_recording)
            CommEmojiPicker(onPick: (e) {
              final t = _ctrl.text;
              final sel = _ctrl.selection;
              final pos = sel.isValid ? sel.start : t.length;
              _ctrl.text = t.substring(0, pos) + e + t.substring(pos);
              _ctrl.selection =
                  TextSelection.collapsed(offset: pos + e.length);
            }),
        ]),
      ),
    ]);
  }
}

// ─── Bouton d'action d'en-tête de fil ───────────────────────────────────────────

class _ThreadAction extends StatelessWidget {
  const _ThreadAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 19, color: kTextMuted),
      );
}

// ─── Menu ⋮ du fil 1-à-1 (supprimer la discussion) ─────────────────────────────

class _ThreadMenu extends StatelessWidget {
  const _ThreadMenu({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Plus',
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
        onSelected: (v) {
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'delete',
            height: 42,
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
              SizedBox(width: 10),
              Text('Supprimer la discussion',
                  style: TextStyle(fontSize: 13, color: kRed)),
            ]),
          ),
        ],
      );
}

// ─── Feuille « Lu par » : ssection + ligne membre ───────────────────────────────

class _ReadInfoLabel extends StatelessWidget {
  const _ReadInfoLabel(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: color)),
      );
}

class _ReadInfoRow extends StatelessWidget {
  const _ReadInfoRow({required this.member, required this.read});
  final ConvMember member;
  final bool read;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          _Avatar(name: member.name ?? '?', role: member.role,
              avatarUrl: member.avatarUrl, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(member.name ?? 'Membre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Icon(read ? Icons.done_all_rounded : Icons.done_rounded,
              size: 16, color: read ? _waTickRead : kTextMuted),
        ]),
      );
}

// ─── Séparateur de jour (style WhatsApp) ────────────────────────────────────────

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});
  final DateTime day;

  String get _label {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return "Aujourd'hui";
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    return _fmtDate.format(day);
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F2FB), // pilule bleutée WhatsApp
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Text(_label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _waTime)),
        ),
      );
}

// _Bubble / _MetaStamp / _ComposeContextBar → messagerie_staff_bubble.dart

// ─── Aucun fil sélectionné ──────────────────────────────────────────────────────

class _NoSelection extends StatelessWidget {
  const _NoSelection();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF7F5F3),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFE9EDEF)),
            child: const Icon(Icons.forum_rounded,
                size: 56, color: Color(0xFF8696A0)),
          ),
          const SizedBox(height: 22),
          const Text('Votre messagerie',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF41525D))),
          const SizedBox(height: 10),
          const SizedBox(
            width: 380,
            child: Text(
              'Choisissez une conversation à gauche, ou démarrez-en une '
              'nouvelle. Vos messages restent disponibles hors connexion.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.5, color: Color(0xFF667781)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13, color: Color(0xFF00A884)),
              SizedBox(width: 6),
              Text('Vos échanges sont sécurisés',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00A884))),
            ]),
          ),
        ]),
      );
}
