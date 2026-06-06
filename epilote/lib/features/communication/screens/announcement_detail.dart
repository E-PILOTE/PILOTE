part of 'announcements_screen.dart';

// ─── Helpers détail ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(this.rows);
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias, child: Column(children: rows),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: _kBorder))),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(color: _kText,
          fontSize: mono ? 11 : 13, fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(message: 'Copier', child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copié : $value'), backgroundColor: _kNavy,
                  behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
                ));
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(padding: EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy)),
          )),
        ),
      ],
    ]),
  );
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 11.5,
          fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Modal Détail ─────────────────────────────────────────────────────────────

class _AnnDetailModal extends ConsumerStatefulWidget {
  const _AnnDetailModal({required this.ann, required this.onEdit,
      required this.onTogglePublish, required this.onDelete});
  final AnnouncementDetail ann;
  final VoidCallback onEdit, onTogglePublish, onDelete;
  @override
  ConsumerState<_AnnDetailModal> createState() => _AnnDetailModalState();
}

class _AnnDetailModalState extends ConsumerState<_AnnDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _audienceColor(a.targetAudience).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _audienceColor(a.targetAudience).withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_audienceIcon(a.targetAudience),
                    color: _audienceColor(a.targetAudience), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (a.isPinned) ...[
                    const Icon(Icons.push_pin_rounded, size: 14, color: _kOrange),
                    const SizedBox(width: 4),
                  ],
                  Flexible(child: Text(a.title, style: const TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
                  _AudienceBadge(audience: a.targetAudience),
                ]),
                if (a.groupName != null) ...[
                  const SizedBox(height: 4),
                  Text(a.groupName!, style: const TextStyle(
                      color: _kNavy, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _ModalIconBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // Tabs
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs, labelColor: _kNavy,
              unselectedLabelColor: _kMuted, indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: 'Contenu'), Tab(text: 'Audience & Diffusion'), Tab(text: 'Système')],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _AnnContentTab(ann: a),
            _AnnAudienceTab(ann: a),
            _AnnSystemTab(ann: a),
          ])),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onTogglePublish,
                icon: Icon(a.isPublished ? Icons.unpublished_rounded : Icons.publish_rounded, size: 16),
                label: Text(a.isPublished ? 'Dépublier' : 'Publier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: a.isPublished ? _kOrange : _kGreen,
                  side: BorderSide(color: a.isPublished ? _kOrange : _kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(foregroundColor: _kRed, side: const BorderSide(color: _kRed)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AnnContentTab extends StatelessWidget {
  const _AnnContentTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Titre'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
        child: Text(ann.title, style: const TextStyle(color: _kText, fontSize: 15,
            fontWeight: FontWeight.w700, height: 1.4)),
      ),
      const SizedBox(height: 14),
      const _SectionTitle('Contenu'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
        child: SelectableText(ann.content, style: const TextStyle(color: _kText, fontSize: 13, height: 1.6)),
      ),
    ]),
  );
}

class _AnnAudienceTab extends StatelessWidget {
  const _AnnAudienceTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Diffusion'),
      const SizedBox(height: 8),
      _DetailCard([
        _DetailRow(Icons.people_rounded, 'Audience', ann.targetAudienceLabel),
        _DetailRow(Icons.business_rounded, 'Groupe scolaire', ann.groupName ?? '—'),
        _DetailRow(Icons.publish_rounded, 'Statut publication',
            ann.isPublished ? 'Publiée' : 'Brouillon', last: ann.publishedAt == null),
        if (ann.publishedAt != null)
          _DetailRow(Icons.calendar_today_outlined, 'Publiée le', _fmtDate(ann.publishedAt), last: true),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetaChip(icon: Icons.push_pin_rounded,
            label: ann.isPinned ? 'Épinglée' : 'Non épinglée',
            color: ann.isPinned ? _kOrange : _kMuted)),
        const SizedBox(width: 8),
        Expanded(child: _MetaChip(icon: Icons.event_busy_rounded,
            label: ann.expiresAt != null ? 'Exp. ${_fmtDate(ann.expiresAt)}' : 'Sans expiration',
            color: ann.isExpired ? _kRed : (ann.expiresAt != null ? _kOrange : _kMuted))),
      ]),
    ]),
  );
}

class _AnnSystemTab extends StatelessWidget {
  const _AnnSystemTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Identité système'),
      const SizedBox(height: 8),
      _DetailCard([
        _DetailRow(Icons.tag_rounded, 'UUID', ann.id, copyable: true, mono: true),
        _DetailRow(Icons.business_rounded, 'Group ID', ann.groupId, mono: true),
        _DetailRow(Icons.calendar_today_outlined, 'Créée le', _fmtDate(ann.createdAt)),
        _DetailRow(Icons.update_outlined, 'Mise à jour', _fmtDate(ann.updatedAt), last: true),
      ]),
    ]),
  );
}

// ─── Dialog Suppression ───────────────────────────────────────────────────────

class _DeleteAnnDialog extends StatefulWidget {
  const _DeleteAnnDialog({required this.ann});
  final AnnouncementDetail ann;
  @override
  State<_DeleteAnnDialog> createState() => _DeleteAnnDialogState();
}

class _DeleteAnnDialogState extends State<_DeleteAnnDialog> {
  bool _confirmed = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(color: _kRed,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Supprimer l\'annonce',
                      style: TextStyle(color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Cette action est irréversible',
                      style: TextStyle(color: _kMuted, fontSize: 11.5)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder)),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _audienceColor(a.targetAudience).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_audienceIcon(a.targetAudience),
                        color: _audienceColor(a.targetAudience), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 13, color: _kText), overflow: TextOverflow.ellipsis),
                    Text(a.groupName ?? '—', style: const TextStyle(fontSize: 11.5, color: _kMuted)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : Colors.transparent,
                        border: Border.all(color: _confirmed ? _kRed : _kMuted, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmed ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Je confirme vouloir supprimer cette annonce',
                        style: TextStyle(fontSize: 12.5, color: _kText))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false), borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Annuler', style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: _confirmed ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                  child: InkWell(
                    onTap: _confirmed ? () => Navigator.pop(context, true) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : _kMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_forever_rounded,
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5), size: 15),
                        const SizedBox(width: 6),
                        Text('Supprimer définitivement', style: TextStyle(
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                            fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
