import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'staff_feed_ui.dart' show FeedAvatar;

// ════════════════════════════════════════════════════════════════════════════
//  Compositeur de publication façon Facebook — « Quoi de neuf ? » + rangée de
//  raccourcis (Photo/Vidéo · Événement · Document). Affiché uniquement à ceux
//  qui ont le droit de publier (gouvernance conservée dans l'écran appelant).
// ════════════════════════════════════════════════════════════════════════════

class FeedComposerCard extends StatelessWidget {
  const FeedComposerCard({
    super.key,
    required this.hint,
    required this.onCompose,
    required this.onComposePhoto,
    required this.onComposeEvent,
    required this.onComposeDoc,
    this.avatarColor = kNavy,
    this.avatarIcon = Icons.campaign_rounded,
    this.avatarInitials,
    this.avatarUrl,
  });

  /// Texte d'invitation (scope-aware : plateforme / groupe / école).
  final String hint;
  final VoidCallback onCompose;       // tap zone texte → formulaire annonce
  final VoidCallback onComposePhoto;  // 📷 → formulaire + sélecteur fichiers
  final VoidCallback onComposeEvent;  // 📅 → formulaire événement
  final VoidCallback onComposeDoc;    // 📎 → formulaire + sélecteur fichiers
  final Color avatarColor;
  final IconData avatarIcon;

  /// Initiales de l'utilisateur courant → avatar « c'est VOUS qui publiez ».
  final String? avatarInitials;

  /// Photo de profil de l'utilisateur courant (prioritaire sur les initiales).
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          // ── En-tête « Créer une publication » ───────────────────────────────
          const Row(children: [
            Icon(Icons.edit_note_rounded, size: 18, color: kNavy),
            SizedBox(width: 8),
            Text('Créer une publication',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ]),
          const SizedBox(height: 12),
          // ── Avatar utilisateur + zone de saisie ─────────────────────────────
          Row(children: [
            FeedAvatar(
              color: avatarColor,
              icon: avatarInitials == null ? avatarIcon : null,
              initials: avatarInitials,
              avatarUrl: avatarUrl,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCompose,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 13.5, color: kTextMuted)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: kBorder),
          const SizedBox(height: 4),
          // ── Rangée de raccourcis ────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _ComposerAction(
                icon: Icons.photo_library_rounded,
                label: 'Photo/Vidéo',
                color: kGreen,
                onTap: onComposePhoto,
              ),
            ),
            Expanded(
              child: _ComposerAction(
                icon: Icons.event_rounded,
                label: 'Événement',
                color: kAccent,
                onTap: onComposeEvent,
              ),
            ),
            Expanded(
              child: _ComposerAction(
                icon: Icons.attach_file_rounded,
                label: 'Document',
                color: kNavy,
                onTap: onComposeDoc,
              ),
            ),
          ]),
        ]),
      );
}

// ─── Raccourci unique (icône colorée + libellé, fond au survol) ───────────────

class _ComposerAction extends StatefulWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  State<_ComposerAction> createState() => _ComposerActionState();
}

class _ComposerActionState extends State<_ComposerAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _hover ? kSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 19, color: widget.color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
            ]),
          ),
        ),
      );
}
