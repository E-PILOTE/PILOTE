import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../widgets/comm_attachments.dart';
import '../widgets/staff_feed_ui.dart';
import '../../../core/utils/message_erreur.dart';

/// Formulaire de publication SCOPE-AWARE — UN seul dialogue pour tous les espaces.
/// • Direction école → écriture locale (offline-first), pièces jointes = internet.
/// • admin_groupe → écriture online sur SON groupe (sélecteur verrouillé).
/// • super_admin → écriture online, choix du groupe destinataire.
class StaffAnnouncementFormDialog extends ConsumerStatefulWidget {
  const StaffAnnouncementFormDialog({
    super.key,
    this.existing,
    this.openAttachPicker = false,
  });

  /// Annonce à modifier (null = création).
  final AnnouncementDetail? existing;

  /// Ouvre directement le sélecteur de fichiers à l'affichage (raccourcis
  /// Photo/Vidéo & Document du compositeur). Sans effet en édition.
  final bool openAttachPicker;

  @override
  ConsumerState<StaffAnnouncementFormDialog> createState() =>
      _StaffAnnouncementFormDialogState();
}

class _StaffAnnouncementFormDialogState
    extends ConsumerState<StaffAnnouncementFormDialog> {
  late final _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _content =
      TextEditingController(text: widget.existing?.content ?? '');
  late String _audience = widget.existing?.targetAudience ?? 'all';
  late bool _pinned = widget.existing?.isPinned ?? false;
  late DateTime? _expiresAt = widget.existing?.expiresAt;
  late final List<MessageAttachment> _attachments =
      List.of(widget.existing?.attachments ?? const []);
  late String? _groupId = widget.existing?.groupId;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.openAttachPicker && !_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _attach();
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    setState(() => _uploading = true);
    try {
      final me = ref.read(authNotifierProvider).valueOrNull;
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: me?.groupId ?? '',
      );
      if (mounted) setState(() => _attachments.addAll(added));
    } on AttachmentUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Le titre est obligatoire.');
      return;
    }
    if (_content.text.trim().isEmpty) {
      setState(() => _error = 'Le contenu est obligatoire.');
      return;
    }
    final ctx = ref.read(communicationContextProvider);
    final me  = ref.read(authNotifierProvider).valueOrNull;
    if (ctx.isSchool && (me?.groupId == null || me?.schoolId == null)) {
      setState(() => _error = 'Session invalide (école introuvable).');
      return;
    }
    if (ctx.isPlatform && (_groupId == null || _groupId!.isEmpty)) {
      setState(() => _error = 'Choisissez un groupe destinataire.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await updateAnnouncementScoped(
          ref,
          id: widget.existing!.id,
          title: _title.text,
          content: _content.text,
          targetAudience: _audience,
          isPinned: _pinned,
          expiresAt: _expiresAt,
          attachments: _attachments,
        );
      } else {
        await createAnnouncementScoped(
          ref,
          title: _title.text,
          content: _content.text,
          targetAudience: _audience,
          isPinned: _pinned,
          expiresAt: _expiresAt,
          attachments: _attachments,
          groupIdOverride: _groupId,
        );
      }
      if (mounted) {
        final offline = ctx.isSchool;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen,
            content: Text(_isEdit
                ? 'Annonce mise à jour.'
                : offline
                    ? 'Annonce publiée pour votre école — visible même hors '
                        'ligne, transmise à la synchronisation.'
                    : _groupId == kAllGroupsSentinel
                        ? 'Annonce publiée à toutes les écoles.'
                        : 'Annonce publiée.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx     = ref.watch(communicationContextProvider);
    final groups  = ref.watch(announcementGroupsProvider);
    final me      = ref.watch(authNotifierProvider).valueOrNull;
    // super_admin choisit le groupe ; admin_groupe est verrouillé sur le sien.
    final showGroupPicker = ctx.isPlatform && !_isEdit;
    final subtitle = ctx.isSchool
        ? 'Visible par votre école — le texte part même hors ligne'
        : ctx.isGroup
            ? 'Diffusée à tout votre groupe scolaire'
            : 'Diffusée au groupe scolaire choisi';

    // Destinataire affiché dans l'aperçu (scope-aware).
    final destLabel = ctx.isSchool
        ? 'Votre établissement'
        : ctx.isGroup
            ? 'Tout votre groupe scolaire'
            : _groupId == kAllGroupsSentinel
                ? 'Toutes les écoles · tout le monde'
                : _groupId == null
                    ? 'Aucun destinataire choisi'
                    : _groupName(groups, _groupId!);

    return AdminFormDialog(
      icon: Icons.campaign_rounded,
      title: _isEdit ? 'Modifier l\'annonce' : 'Publier une annonce',
      subtitle: subtitle,
      width: 560,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Publier',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.campaign_rounded,
      onSubmit: _submit,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGroupPicker) ...[
            const AdminFormSectionLabel('Groupe destinataire'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _groupId,
              isExpanded: true,
              onChanged: (v) => setState(() => _groupId = v),
              items: [
                // Diffusion plateforme : tout le monde, toutes les écoles.
                DropdownMenuItem(
                  value: kAllGroupsSentinel,
                  child: Row(children: [
                    Icon(Icons.public_rounded, size: 15, color: kGreen),
                    const SizedBox(width: 8),
                    const Text('Toutes les écoles (tout le monde)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
                ...groups.map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5)),
                    )),
              ],
              decoration: adminInputDecoration('Destinataire',
                  icon: Icons.apartment_rounded),
            ),
            const SizedBox(height: 14),
          ],
          const AdminFormSectionLabel('Annonce'),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: adminInputDecoration('Titre de l\'annonce',
                icon: Icons.title_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 12,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: adminInputDecoration('Contenu de l\'annonce…'),
          ),
          const SizedBox(height: 14),
          const AdminFormSectionLabel('Diffusion'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
                items: kAudienceLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 12.5))))
                    .toList(),
                decoration: adminInputDecoration('Audience',
                    icon: Icons.groups_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: adminInputDecoration('Expire le (optionnel)',
                      icon: Icons.timer_off_rounded),
                  child: Text(
                    _expiresAt == null
                        ? 'Jamais'
                        : fmtDateFr(_expiresAt),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // Material propre → l'ink/splash du switch reste visible malgré la
          // carte décorée du modal (évite l'assertion « ListTile background… »).
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Épingler en tête du fil',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              activeTrackColor: kAccent,
            ),
          ),
          const SizedBox(height: 6),
          const AdminFormSectionLabel('Photos, vidéos & documents'),
          const SizedBox(height: 8),
          // Bouton large multi-sélection : on peut l'utiliser PLUSIEURS fois
          // (chaque ajout s'empile). Rien n'est publié ici.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _attach,
              icon: _uploading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(_uploading
                  ? 'Téléversement…'
                  : _attachments.isEmpty
                      ? 'Ajouter des photos, vidéos ou documents'
                      : 'Ajouter d\'autres fichiers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded,
                size: 13, color: kTextMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _attachments.isEmpty
                      ? 'Ajoutez du texte et plusieurs fichiers — rien n\'est '
                          'publié tant que vous n\'appuyez pas sur « Publier ».'
                      : '${_attachments.length} fichier${_attachments.length > 1 ? 's' : ''} prêt${_attachments.length > 1 ? 's' : ''} — vous pouvez encore écrire ou en ajouter.',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ),
          ]),
          CommAttachmentEditList(
            items: _attachments,
            onRemove: (i) => setState(() => _attachments.removeAt(i)),
          ),
          const SizedBox(height: 18),
          const AdminFormSectionLabel('Aperçu avant publication'),
          const SizedBox(height: 8),
          _AnnouncementPreview(
            authorName     : (me?.fullName.trim().isNotEmpty ?? false)
                ? me!.fullName
                : 'Vous',
            role           : me?.role,
            title          : _title.text,
            content        : _content.text,
            audience       : _audience,
            pinned         : _pinned,
            attachmentCount: _attachments.length,
            destination    : destLabel,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

// ─── Aperçu live de la publication (« visualiser avant de publier ») ─────────

String _groupName(List<GroupOption> groups, String id) {
  for (final g in groups) {
    if (g.id == id) return g.name;
  }
  return 'Groupe sélectionné';
}

String _previewInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final p = parts.isNotEmpty ? parts[0] : '?';
  return p.isEmpty ? '?' : p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

class _AnnouncementPreview extends StatelessWidget {
  const _AnnouncementPreview({
    required this.authorName,
    required this.role,
    required this.title,
    required this.content,
    required this.audience,
    required this.pinned,
    required this.attachmentCount,
    required this.destination,
  });
  final String  authorName;
  final String? role;
  final String  title, content, audience, destination;
  final bool    pinned;
  final int     attachmentCount;

  @override
  Widget build(BuildContext context) {
    final color      = roleColor(role);
    final aColor     = audienceColor(audience);
    final init       = _previewInitials(authorName);
    final hasTitle   = title.trim().isNotEmpty;
    final hasContent = content.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.14),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Icon(Icons.push_pin_rounded,
                    size: 12, color: Color.lerp(kAccent, Colors.black, 0.35)),
                const SizedBox(width: 6),
                Text('Épinglée',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color.lerp(kAccent, Colors.black, 0.4))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.black, 0.28)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(init,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: kTextPrimary)),
                          ),
                          const SizedBox(width: 7),
                          _MiniBadge(text: roleLabelFr(role), color: color),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.send_rounded,
                              size: 11, color: kTextMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: kTextMuted)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(hasTitle ? title.trim() : 'Titre de l\'annonce',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: hasTitle ? kTextPrimary : kTextMuted)),
                const SizedBox(height: 6),
                Text(
                    hasContent
                        ? content.trim()
                        : 'Le contenu de votre annonce apparaîtra ici…',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: hasContent ? kTextPrimary : kTextMuted)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _MiniBadge(
                      text: kAudienceLabels[audience] ?? audience,
                      color: aColor,
                      icon: Icons.groups_rounded),
                  if (attachmentCount > 0)
                    _MiniBadge(
                        text:
                            '$attachmentCount pièce${attachmentCount > 1 ? 's' : ''} jointe${attachmentCount > 1 ? 's' : ''}',
                        color: kNavy,
                        icon: Icons.attach_file_rounded),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color, this.icon});
  final String    text;
  final Color     color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

/// Confirmation + suppression SCOPE-AWARE d'une annonce (local OU online).
Future<void> confirmDeleteAnnouncement(
    WidgetRef ref, BuildContext context, AnnouncementDetail ann) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Supprimer cette annonce ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text('« ${ann.title} » sera supprimée définitivement. '
          'Cette action est irréversible.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: kRed),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await runFeedAction(
      context,
      running: 'Suppression de la publication…',
      success: 'Publication supprimée.',
      action: () => deleteAnnouncementScoped(ref, ann.id),
    );
  }
}
