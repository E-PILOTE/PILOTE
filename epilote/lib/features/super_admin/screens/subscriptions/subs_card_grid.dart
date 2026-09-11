import 'package:flutter/material.dart';

import '../../providers/subscriptions_provider.dart';
import 'subs_badges.dart';
import 'subs_style.dart';

// ─── Vue cartes ──────────────────────────────────────────────────────
//  Même jeu de données que le tableau, autre densité. Le montant y est suivi
//  de sa PÉRIODE (`periodSuffix`) : « / mois » en dur mentait sur un annuel.

class SubCardGrid extends StatelessWidget {
  const SubCardGrid({
    super.key,
    required this.subs,
    required this.onView,
    required this.onEdit,
    required this.onLicence,
  });

  final List<SubscriptionDetail> subs;
  final ValueChanged<SubscriptionDetail> onView, onEdit, onLicence;

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) return const SubEmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemCount: subs.length,
      itemBuilder: (_, i) => _SubCard(
        sub:       subs[i],
        onView:    () => onView(subs[i]),
        onEdit:    () => onEdit(subs[i]),
        onLicence: () => onLicence(subs[i]),
      ),
    );
  }
}

class _SubCard extends StatefulWidget {
  const _SubCard({
    required this.sub,
    required this.onView,
    required this.onEdit,
    required this.onLicence,
  });
  final SubscriptionDetail sub;
  final VoidCallback onView, onEdit, onLicence;

  @override
  State<_SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<_SubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final color = subStatusColor(s.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSubBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? color.withValues(alpha: 0.4) : kSubBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: color.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SubGroupGlyph(sub: s, size: 44),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.groupName, style: TextStyle(
                    color: kSubText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(s.planName ?? 'Sans plan', style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            SubStatusBadge(status: s.status),
            SubTypeBadge(type: s.groupType),
          ]),
          const Spacer(),
          Row(children: [
            _miniStat(Icons.school_rounded, '${s.schoolsCount} écoles', kSubNavy),
            const SizedBox(width: 12),
            _miniStat(Icons.payments_rounded,
                '${subMoney(s.priceXaf)} F/${s.periodSuffix}', kSubPurple),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 12,
                color: s.isOverdue ? kSubRed : (s.isExpiringSoon ? kSubOrange : kSubMuted)),
            const SizedBox(width: 4),
            Expanded(child: Text(s.remainingLabel, style: TextStyle(
                color: s.isOverdue ? kSubRed : (s.isExpiringSoon ? kSubOrange : kSubMuted),
                fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: widget.onView,
              icon: const Icon(Icons.visibility_rounded, size: 13),
              label: const Text('Voir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kSubBlue),
            ),
            TextButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Modifier', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kSubNavy),
            ),
          ]),
        ]),
      ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: kSubMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
    ],
  );
}
