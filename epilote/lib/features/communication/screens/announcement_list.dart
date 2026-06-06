part of 'announcements_screen.dart';

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.anns, required this.onView, required this.onEdit,
    required this.onToggle, required this.onDelete,
  });
  final List<AnnouncementDetail> anns;
  final ValueChanged<AnnouncementDetail> onView, onEdit, onToggle, onDelete;

  static const _statusW  = 96.0;
  static const _actionsW = 104.0;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: const TextStyle(color: _kMuted, fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.4), overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (anns.isEmpty) return const _EmptyState();
    return Container(
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _hdr('Titre', 3),
              _hdr('Groupe scolaire', 2),
              _hdr('Audience', 2),
              _hdr('Expiration', 2),
              const SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              const SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
          ...anns.asMap().entries.map((e) => _TableRow(
            ann: e.value, isOdd: e.key.isOdd,
            statusW: _statusW, actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onToggle: () => onToggle(e.value),
            onDelete: () => onDelete(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.ann, required this.isOdd, required this.statusW, required this.actionsW,
    required this.onView, required this.onEdit, required this.onToggle, required this.onDelete,
  });
  final AnnouncementDetail ann;
  final bool isOdd;
  final double statusW, actionsW;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? _kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
          border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView, behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (a.isPinned) ...[
                    const Icon(Icons.push_pin_rounded, size: 13, color: _kOrange),
                    const SizedBox(width: 4),
                  ],
                  Flexible(child: Text(a.title, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis)),
                ]),
                Text(a.content.length > 60 ? '${a.content.substring(0, 60)}…' : a.content,
                    style: const TextStyle(fontSize: 10.5, color: _kMuted),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          )),
          Expanded(flex: 2, child: Text(a.groupName ?? '—',
              style: const TextStyle(fontSize: 12, color: _kText), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _AudienceBadge(audience: a.targetAudience)),
          Expanded(flex: 2, child: Text(
            a.expiresAt != null ? _fmtDateShort(a.expiresAt!) : '—',
            style: TextStyle(fontSize: 11.5,
                color: a.isExpired ? _kRed : _kMuted, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          )),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
              ),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue, tooltip: 'Voir', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded, color: _kRed, tooltip: 'Supprimer', onTap: widget.onDelete),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
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
        onTap: onTap, borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.20))),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.anns, required this.onView, required this.onEdit,
      required this.onToggle, required this.onDelete});
  final List<AnnouncementDetail> anns;
  final ValueChanged<AnnouncementDetail> onView, onEdit, onToggle, onDelete;
  @override
  Widget build(BuildContext context) {
    if (anns.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.4,
      ),
      itemCount: anns.length,
      itemBuilder: (_, i) => _AnnCard(
        ann:      anns[i],
        onView:   () => onView(anns[i]),
        onEdit:   () => onEdit(anns[i]),
        onToggle: () => onToggle(anns[i]),
        onDelete: () => onDelete(anns[i]),
      ),
    );
  }
}

class _AnnCard extends StatefulWidget {
  const _AnnCard({required this.ann, required this.onView, required this.onEdit,
      required this.onToggle, required this.onDelete});
  final AnnouncementDetail ann;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  @override
  State<_AnnCard> createState() => _AnnCardState();
}

class _AnnCardState extends State<_AnnCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    final color = _audienceColor(a.targetAudience);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.4) : _kBorder),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(_audienceIcon(a.targetAudience), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: const TextStyle(color: _kText, fontSize: 13,
                    fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 2),
              ])),
              if (a.isPinned)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.push_pin_rounded, size: 14, color: _kOrange),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _AudienceBadge(audience: a.targetAudience),
              _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
            ]),
            const SizedBox(height: 8),
            Text(a.content.length > 80 ? '${a.content.substring(0, 80)}…' : a.content,
                style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.4),
                overflow: TextOverflow.ellipsis, maxLines: 2),
            const Spacer(),
            Text(a.groupName ?? '—', style: const TextStyle(
                color: _kNavy, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: widget.onView,
                icon: const Icon(Icons.visibility_rounded, size: 13),
                label: const Text('Voir', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kBlue),
              ),
              TextButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(a.isPublished ? Icons.unpublished_rounded : Icons.publish_rounded, size: 13),
                label: Text(a.isPublished ? 'Dépublier' : 'Publier',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: a.isPublished ? _kOrange : _kGreen),
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                color: _kRed, tooltip: 'Supprimer',
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _AudienceBadge extends StatelessWidget {
  const _AudienceBadge({required this.audience});
  final String audience;
  @override
  Widget build(BuildContext context) {
    final color = _audienceColor(audience);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_audienceIcon(audience), size: 11, color: color),
        const SizedBox(width: 4),
        Text(_audienceLabel(audience),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _PublishBadge extends StatelessWidget {
  const _PublishBadge({required this.isPublished, required this.isExpired});
  final bool isPublished, isExpired;
  @override
  Widget build(BuildContext context) {
    final color = isExpired ? _kRed : (isPublished ? _kGreen : _kMuted);
    final label = isExpired ? 'Expirée' : (isPublished ? 'Publiée' : 'Brouillon');
    final icon  = isExpired ? Icons.event_busy_rounded
        : (isPublished ? Icons.check_circle_rounded : Icons.drafts_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64), alignment: Alignment.center,
    child: const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.campaign_rounded, size: 56, color: _kBorder),
      SizedBox(height: 16),
      Text('Aucune annonce trouvée', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez une nouvelle annonce.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}
