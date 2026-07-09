part of '../admin_regional_view.dart';

// ─── Panneau détail projet ───────────────────────────────────────────────────
class _ProjectDetailPanel extends ConsumerWidget {
  const _ProjectDetailPanel({
    required this.project,
    required this.onEdit,
    required this.onDelete,
  });
  final AdminProjectPin project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _projectStatusColor(project.status);
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor.withValues(alpha: 0.85), statusColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_projectStatusIcon(project.status),
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(project.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w800),
                      maxLines: 2),
                  Text(_projectStatusLabel(project.status),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ]),
              ),
              Row(children: [
                _IconBtn(icon: Icons.edit_rounded, onTap: onEdit),
                _IconBtn(icon: Icons.delete_rounded, onTap: onDelete),
                _IconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => ref.read(_selectionProv.notifier).state =
                        const SelectionNone()),
              ]),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _MiniChip(
                  label: _priorityLabel(project.priority),
                  color: _priorityColor(project.priority)),
              if (project.schoolType != null)
                _MiniChip(
                    label: _typeLabel(project.schoolType!),
                    color: _typeColorForPin(project.schoolType!)),
              if (project.beneficiariesEst != null)
                _MiniChip(
                    label: '${project.beneficiariesEst} bénéf.',
                    color: Colors.white.withValues(alpha: 0.3)),
            ]),
          ]),
        ),
        // Pipeline de statut
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _StatusPipeline(currentStatus: project.status),
        ),
        // Détails
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const Text('DESCRIPTION',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Text(project.description!,
                      style: const TextStyle(
                          fontSize: 11.5, color: kTextPrimary, height: 1.4)),
                  const SizedBox(height: 14),
                ],
                // Localisation
                Row(children: [
                  _DetailKpi(
                      value:
                          '${project.latitude.toStringAsFixed(4)}, ${project.longitude.toStringAsFixed(4)}',
                      label: 'Coords',
                      color: _kBlue),
                ]),
                if (project.department != null || project.city != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.place_rounded, size: 13, color: kTextMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          [project.city, project.department]
                              .whereType<String>()
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: kTextPrimary)),
                    ),
                  ]),
                ],
                if (project.budgetXaf != null) ...[
                  const SizedBox(height: 14),
                  const Text('BUDGET',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_rounded,
                          size: 14, color: kAccent),
                      const SizedBox(width: 8),
                      Text('${fmt.format(project.budgetXaf)} FCFA',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                    ]),
                  ),
                ],
                if (project.comments != null &&
                    project.comments!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('COMMENTAIRES',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(project.comments!,
                        style: const TextStyle(
                            fontSize: 11, color: kTextPrimary, height: 1.4)),
                  ),
                ],
                if (project.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text('Créé le ${_fmtDate(project.createdAt)}',
                      style: const TextStyle(
                          fontSize: 9, color: kTextMuted)),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white70, size: 15),
        ),
      );
}

// ─── Pipeline de statut projet ───────────────────────────────────────────────
class _StatusPipeline extends StatelessWidget {
  const _StatusPipeline({required this.currentStatus});
  final String currentStatus;

  static const _steps = [
    ('etude', 'Étude'),
    ('validation', 'Validation'),
    ('budgetisation', 'Budget.'),
    ('construction', 'Constr.'),
    ('acheve', 'Achevé'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexWhere((s) => s.$1 == currentStatus);
    return Row(
      children: _steps.asMap().entries.map((e) {
        final i    = e.key;
        final step = e.value;
        final isDone    = i < currentIdx;
        final isCurrent = i == currentIdx;
        final dotColor  = isCurrent
            ? _projectStatusColor(currentStatus)
            : isDone
                ? kGreen
                : kBorder;
        return Expanded(
          child: Column(children: [
            Row(children: [
              if (i > 0)
                Expanded(
                    child: Container(
                        height: 2,
                        color: isDone || isCurrent ? kGreen : kBorder)),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? dotColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: isDone || isCurrent
                    ? Icon(
                        isDone
                            ? Icons.check_rounded
                            : _projectStatusIcon(currentStatus),
                        size: 8,
                        color: Colors.white)
                    : null,
              ),
              if (i < _steps.length - 1)
                Expanded(
                    child: Container(
                        height: 2,
                        color: i < currentIdx ? kGreen : kBorder)),
            ]),
            const SizedBox(height: 4),
            Text(step.$2,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? dotColor : kTextMuted),
                textAlign: TextAlign.center),
          ]),
        );
      }).toList(),
    );
  }
}

