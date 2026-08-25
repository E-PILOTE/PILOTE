import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../providers/ticket_thread_provider.dart';
import 'comm_attachments.dart';
import 'staff_feed_ui.dart';
import 'user_avatar.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Vue « conversation » d'un ticket support — UN widget partagé par les trois
//  espaces (super_admin inline · admin_groupe dialog · staff école dialog).
//  Bulles type chat : demandeur à gauche/droite selon le lecteur, support
//  identifié par un badge. Temps réel via [ticketThreadProvider].
// ════════════════════════════════════════════════════════════════════════════

class TicketThreadView extends ConsumerStatefulWidget {
  const TicketThreadView({
    super.key,
    required this.ticketId,
    required this.ticketOwnerId,
    required this.groupId,
    required this.originalBody,
    required this.createdAt,
    required this.viewerIsSupport,
    this.originalAttachments = const [],
    this.closed = false,
    this.onSend,
  });

  final String  ticketId;
  final String  ticketOwnerId;
  final String? groupId;

  /// Description initiale du ticket (1ʳᵉ bulle du fil, côté demandeur).
  final String originalBody;
  final String createdAt;

  /// Pièces jointes de la plainte initiale (rendues dans la 1ʳᵉ bulle).
  final List<MessageAttachment> originalAttachments;

  /// true = le lecteur est le support (super_admin) → ses messages partent
  /// avec `is_from_support`, alignés à droite.
  final bool viewerIsSupport;

  /// Ticket résolu/fermé : la zone de saisie affiche un état adapté
  /// (le demandeur peut relancer, ce qui rouvre le ticket côté provider).
  final bool closed;

  /// Callback d'envoi personnalisé (ex. réponse support + maj statut ticket).
  /// Reçoit le texte ET les pièces jointes téléversées.
  final Future<void> Function(String body, List<MessageAttachment> attachments)?
      onSend;

  @override
  ConsumerState<TicketThreadView> createState() => _TicketThreadViewState();
}

class _TicketThreadViewState extends ConsumerState<TicketThreadView> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _uploading = false;
  // Pièces jointes téléversées, en attente d'envoi avec le message.
  final List<MessageAttachment> _pending = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool imagesOnly}) async {
    if (_uploading || _sending) return;
    setState(() => _uploading = true);
    try {
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: widget.groupId ?? 'platform',
        imagesOnly: imagesOnly,
      );
      if (mounted && added.isNotEmpty) {
        setState(() => _pending.addAll(added));
      }
    } on AttachmentUploadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || _sending) return;
    final attachments = List<MessageAttachment>.from(_pending);
    setState(() => _sending = true);
    try {
      if (widget.onSend != null) {
        await widget.onSend!(text, attachments);
      } else {
        await sendTicketMessageScoped(
          ref,
          ticketId: widget.ticketId,
          ticketOwnerId: widget.ticketOwnerId,
          groupId: widget.groupId,
          body: text,
          isFromSupport: widget.viewerIsSupport,
          attachments: attachments,
        );
      }
      _ctrl.clear();
      _pending.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketThreadProvider(widget.ticketId));
    final msgs  = async.valueOrNull ?? const <TicketMessage>[];
    // Identité du demandeur (photo + nom) pour ses bulles. Le support a un
    // avatar générique « Support E-PILOTE ».
    final requester =
        ref.watch(ticketRequesterProvider(widget.ticketOwnerId)).valueOrNull;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Fil ────────────────────────────────────────────────────────────────
      Flexible(
        child: ListView(
          shrinkWrap: true,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            // reverse:true → on construit du plus récent au plus ancien.
            for (final m in msgs.reversed)
              _TicketBubble(
                body: m.body,
                fromSupport: m.isFromSupport,
                mine: widget.viewerIsSupport == m.isFromSupport,
                date: m.createdAt,
                attachments: m.attachments,
                requester: requester,
              ),
            // 1ʳᵉ bulle = la demande initiale (côté demandeur).
            _TicketBubble(
              body: widget.originalBody,
              fromSupport: false,
              mine: !widget.viewerIsSupport,
              date: DateTime.tryParse(widget.createdAt)?.toLocal(),
              isOriginal: true,
              attachments: widget.originalAttachments,
              requester: requester,
            ),
          ],
        ),
      ),

      // ── Saisie ─────────────────────────────────────────────────────────────
      const SizedBox(height: 8),
      if (widget.closed && !widget.viewerIsSupport)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kGreen.withValues(alpha: 0.25)),
          ),
          child: Text(
            'Demande traitée — répondre la rouvrira auprès du support.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
      // Pièces jointes en attente (téléversées, pas encore envoyées).
      if (_pending.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CommAttachmentEditList(
            items: _pending,
            onRemove: (i) => setState(() => _pending.removeAt(i)),
          ),
        ),
      Row(children: [
        // Joindre une image / un document de plainte.
        _AttachBtn(
          icon: Icons.image_rounded,
          tooltip: 'Joindre une image',
          busy: _uploading,
          onTap: () => _pick(imagesOnly: true),
        ),
        _AttachBtn(
          icon: Icons.attach_file_rounded,
          tooltip: 'Joindre un document',
          busy: _uploading,
          onTap: () => _pick(imagesOnly: false),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.viewerIsSupport
                  ? 'Répondre au demandeur…'
                  : 'Écrire au support…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 12.5),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: (_sending || _uploading) ? null : _send,
          tooltip: 'Envoyer',
          style: IconButton.styleFrom(backgroundColor: kNavy),
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
        ),
      ]),
    ]);
  }
}

// ─── Bouton « joindre » (image / document) ────────────────────────────────────
class _AttachBtn extends StatelessWidget {
  const _AttachBtn({
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onTap,
  });
  final IconData     icon;
  final String       tooltip;
  final bool         busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: busy ? null : onTap,
        color: kNavy,
        iconSize: 20,
        icon: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: kNavy))
            : Icon(icon),
      );
}

// ─── Bulle du fil ─────────────────────────────────────────────────────────────

class _TicketBubble extends StatelessWidget {
  const _TicketBubble({
    required this.body,
    required this.fromSupport,
    required this.mine,
    required this.date,
    this.isOriginal = false,
    this.attachments = const [],
    this.requester,
  });

  final String    body;
  final bool      fromSupport;
  final bool      mine;
  final DateTime? date;
  final bool      isOriginal;
  final List<MessageAttachment> attachments;
  /// Identité du demandeur (photo + nom) — pour les bulles non-support.
  final TicketParticipant? requester;

  Widget _avatar() {
    if (fromSupport) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.support_agent_rounded, size: 17, color: kNavy),
      );
    }
    return UserAvatarCircle(
      name: requester?.name ?? 'Demandeur',
      role: requester?.role,
      avatarUrl: requester?.avatarUrl,
      radius: 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? kNavy : kCardBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(mine ? 12 : 3),
          bottomRight: Radius.circular(mine ? 3 : 12),
        ),
        border: mine ? null : Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fromSupport
                ? 'Support E-PILOTE'
                : (requester?.name ??
                    (isOriginal ? 'Demande initiale' : 'Demandeur')),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: mine ? Colors.white70 : kNavy),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectableText(body,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: mine ? Colors.white : kTextPrimary)),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: CommAttachmentView(items: attachments, thumbSize: 120),
            ),
          ],
          const SizedBox(height: 4),
          Text(date == null ? '' : fmtRelativeFr(date),
              style: TextStyle(
                  fontSize: 9.5,
                  color: mine ? Colors.white60 : kTextMuted)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(child: bubble),
          if (mine) ...[const SizedBox(width: 8), _avatar()],
        ],
      ),
    );
  }
}

// ─── Dialog conversation (admin_groupe & staff école) ────────────────────────

class TicketThreadDialog extends ConsumerWidget {
  const TicketThreadDialog({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.statusLabel,
    required this.statusColor,
    required this.ticketOwnerId,
    required this.groupId,
    required this.originalBody,
    required this.createdAt,
    this.originalAttachments = const [],
    this.closed = false,
    this.metaBadges = const [],
    this.onSend,
  });

  final String  ticketId;
  final String  subject;
  final String  statusLabel;
  final Color   statusColor;
  final String  ticketOwnerId;
  final String? groupId;
  final String  originalBody;
  final String  createdAt;
  final List<MessageAttachment> originalAttachments;
  final bool    closed;

  /// Badges contextuels (catégorie, priorité, dates) sous l'en-tête.
  final List<Widget> metaBadges;
  final Future<void> Function(String body, List<MessageAttachment> attachments)?
      onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.support_agent_rounded,
                  color: kNavy, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                    Text('Conversation avec le support',
                        style:
                            TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
            ),
            AdminBadge(statusLabel, color: statusColor),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: kTextMuted),
            ),
          ]),
          if (metaBadges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 6, children: metaBadges),
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 8),
          Flexible(
            child: TicketThreadView(
              ticketId: ticketId,
              ticketOwnerId: ticketOwnerId,
              groupId: groupId,
              originalBody: originalBody,
              createdAt: createdAt,
              originalAttachments: originalAttachments,
              viewerIsSupport: false,
              closed: closed,
              onSend: onSend,
            ),
          ),
        ]),
      ),
    );
  }
}
