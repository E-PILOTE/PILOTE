part of '../plans_screen.dart';

// Contenu des onglets et briques de détail.

class _PlanInfoTab extends StatelessWidget {
  const _PlanInfoTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PlanSectionTitle('Tarification'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.payments_outlined, 'Tarif', p.priceLabel),
          _PlanDetailRow(Icons.event_repeat_rounded, 'Périodicité',
              p.periodLabel),
          _PlanDetailRow(Icons.category_outlined, 'Type', _slugLabel(p.slug)),
          _PlanDetailRow(Icons.trending_up_rounded, 'Revenu mensuel généré',
              '${moneyXaf(p.monthlyRevenue)} FCFA', last: true),
        ]),
        const SizedBox(height: 14),
        const _PlanSectionTitle('Quotas & Limites'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.school_rounded, 'Écoles max', p.maxSchoolsLabel),
          _PlanDetailRow(Icons.groups_rounded, 'Élèves max', p.maxStudentsLabel),
          _PlanDetailRow(Icons.badge_rounded, 'Personnel max', p.maxStaffLabel,
              last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _PlanMetaChip(
            icon: _slugIcon(p.slug), label: _slugLabel(p.slug), color: _slugColor(p.slug))),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: p.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: p.isActive ? 'Actif' : 'Inactif',
            color: p.isActive ? _kGreen : _kRed)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: p.isPublicPlan ? Icons.public_rounded : Icons.lock_rounded,
            label: p.isPublicPlan ? 'Public' : 'Privé',
            color: p.isPublicPlan ? _kBlue : _kMuted)),
        ]),
        if (p.description != null && p.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const _PlanSectionTitle('Description'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Text(p.description!, style: TextStyle(
                color: _kText, fontSize: 12.5, height: 1.5)),
          ),
        ],
      ]),
    );
  }
}

// ─── Onglet Modules & Adoption ──────────────────────────────────────────────

class _PlanModulesTab extends ConsumerWidget {
  const _PlanModulesTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plan;
    final allModules = ref.watch(plansProvider).valueOrNull?.modules ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _PlanMetaChip(
            icon: Icons.widgets_rounded, label: '${p.linkedModules} modules', color: _kPurple)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: Icons.groups_rounded, label: '${p.subscribersTotal} abonnés', color: _kGold)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: Icons.check_circle_rounded, label: '${p.subscribersActive} actifs', color: _kGreen)),
        ]),
        const SizedBox(height: 16),
        const _PlanSectionTitle('Modules inclus dans ce plan'),
        const SizedBox(height: 8),
        FutureBuilder<Set<String>>(
          future: fetchPlanModuleIds(ref, p.id),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))),
              );
            }
            final ids = snap.data!;
            final mods = allModules.where((m) => ids.contains(m.id)).toList();
            if (mods.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text('Aucun module rattaché à ce plan.',
                    style: TextStyle(color: _kMuted, fontSize: 12.5)),
              );
            }
            return Wrap(spacing: 8, runSpacing: 8, children: mods.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.widgets_rounded, size: 13, color: _kPurple),
                const SizedBox(width: 6),
                Text(m.name, style: TextStyle(
                    color: _kText, fontSize: 11.5, fontWeight: FontWeight.w600)),
                if (m.categoryName.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('· ${m.categoryName}', style: TextStyle(
                      color: _kMuted, fontSize: 10)),
                ],
              ]),
            )).toList());
          },
        ),
      ]),
    );
  }
}

// ─── Onglet Système ───────────────────────────────────────────────────────────

class _PlanSystemTab extends StatelessWidget {
  const _PlanSystemTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PlanSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.tag_rounded, 'UUID', p.id, copyable: true, mono: true),
          _PlanDetailRow(Icons.confirmation_number_outlined, 'Slug', p.slug),
          _PlanDetailRow(Icons.calendar_today_outlined, 'Créé le', _fmtDate(p.createdAt)),
          _PlanDetailRow(Icons.update_outlined, 'Mis à jour', _fmtDate(p.updatedAt), last: true),
        ]),
      ]),
    );
  }
}

// ─── Helpers modal détail ─────────────────────────────────────────────────────

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
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

class _PlanDetailCard extends StatelessWidget {
  const _PlanDetailCard(this.rows);
  final List<_PlanDetailRow> rows;

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

class _PlanDetailRow extends StatelessWidget {
  const _PlanDetailRow(this.icon, this.label, this.value,
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

class _PlanMetaChip extends StatelessWidget {
  const _PlanMetaChip({required this.icon, required this.label, required this.color});
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

class _PlanSectionTitle extends StatelessWidget {
  const _PlanSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────
