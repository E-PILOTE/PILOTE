part of '../modules_screen.dart';

// Contenu des onglets et briques de détail.

class _ModInfoTab extends StatelessWidget {
  const _ModInfoTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _DSectionTitle('Identité'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.extension_rounded, 'Nom', m.name),
          _DRow(Icons.link_rounded, 'Slug', m.slug, copyable: true, mono: true),
          _DRow(Icons.folder_rounded, 'Catégorie', m.categoryName),
          _DRow(Icons.sort_rounded, 'Ordre d\'affichage', '#${m.displayOrder}', last: true),
        ]),
        const SizedBox(height: 14),
        if ((m.description ?? '').trim().isNotEmpty) ...[
          const _DSectionTitle('Description'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(m.description!.trim(), style: TextStyle(
                color: _kText, fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
        const _DSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.tag_rounded, 'UUID', m.id, copyable: true, mono: true),
          _DRow(Icons.confirmation_number_outlined, 'Référence',
              m.id.substring(0, 8).toUpperCase()),
          _DRow(Icons.folder_special_rounded, 'ID catégorie', m.categoryId,
              copyable: true, mono: true, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MetaChip(
            icon: Icons.folder_rounded, label: m.categoryName, color: _kGold)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: m.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: m.isActive ? 'Actif' : 'Inactif',
            color: m.isActive ? _kGreen : _kRed)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.account_tree_rounded,
            label: '${m.planCount} plan(s)', color: _kPurple)),
        ]),
      ]),
    );
  }
}

class _ModAccessTab extends StatelessWidget {
  const _ModAccessTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kGold.withValues(alpha: 0.05), _kGold.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(m.categoryName, style: TextStyle(
                  color: _kGold, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Catégorie de navigation',
                  style: TextStyle(color: _kMuted, fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ])),
            _StatusBadge(isActive: m.isActive),
          ]),
        ),
        const SizedBox(height: 20),
        const _DSectionTitle('Disponibilité par plan'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.workspace_premium_rounded, 'Plans concernés',
              '${m.planCount} plan(s)'),
          _DRow(Icons.toggle_on_rounded, 'État',
              m.isActive ? 'Disponible' : 'Désactivé', last: true),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: 0.20)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _kBlue),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Ce module détermine la navigation hors-ligne disponible pour les '
              'écoles selon leur plan d\'abonnement.',
              style: TextStyle(color: _kBlue, fontSize: 12, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _ModActivityTab extends StatelessWidget {
  const _ModActivityTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TimelineItem(icon: Icons.add_circle_rounded, color: _kGreen,
            title: 'Module créé', date: m.createdAt),
        _TimelineItem(icon: Icons.update_rounded, color: _kNavy,
            title: 'Dernière mise à jour', date: m.updatedAt),
        if (!m.isActive)
          _TimelineItem(icon: Icons.block_rounded, color: _kRed,
              title: 'Module actuellement désactivé', date: m.updatedAt),
      ],
    );
  }
}

// ─── Helpers modal détail ─────────────────────────────────────────────────────

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _DCard extends StatelessWidget {
  const _DCard(this.rows);
  final List<_DRow> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _DRow extends StatelessWidget {
  const _DRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11.5 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copier',
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copié : $value'),
                    backgroundColor: _kNavy,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
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
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(
          color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _DSectionTitle extends StatelessWidget {
  const _DSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.icon, required this.color,
      required this.title, required this.date});
  final IconData icon;
  final Color color;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(_fmtDateTime(date), style: TextStyle(color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────
