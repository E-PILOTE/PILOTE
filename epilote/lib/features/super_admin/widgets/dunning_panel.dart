import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../providers/dunning_provider.dart';

const _kSoonColor = Color(0xFFD97706); // ambre
const _kGraceColor = Color(0xFFB45309); // ambre foncé
Color get _kOverdueColor => kRed; // rouge

/// Panneau « Recouvrement » (super_admin) : groupes proches de l'échéance, en
/// grâce, ou échus/impayés. Greffé dans l'écran factures. Masqué si rien à relancer.
class DunningPanel extends ConsumerWidget {
  const DunningPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(dunningProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    Iterable<DunningRow> of(DunningBucket b) => rows.where((r) => r.bucket == b);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.campaign_rounded, size: 18, color: _kOverdueColor),
            const SizedBox(width: 8),
            Text('Recouvrement — ${rows.length} groupe${rows.length > 1 ? 's' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          _bucketSection(context, 'Échoit bientôt', _kSoonColor, of(DunningBucket.expiringSoon)),
          _bucketSection(context, 'En grâce', _kGraceColor, of(DunningBucket.inGrace)),
          _bucketSection(context, 'Échus / impayés', _kOverdueColor, of(DunningBucket.overdue)),
        ],
      ),
    );
  }

  Widget _bucketSection(BuildContext context, String title, Color color, Iterable<DunningRow> items) {
    final list = items.toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: .5)),
        ),
        ...list.map((r) => _row(context, r, color)),
      ],
    );
  }

  Widget _row(BuildContext context, DunningRow r, Color color) {
    final d = r.daysLeft;
    final when = d == null
        ? ''
        : d >= 0
            ? 'J-$d'
            : 'échu +${-d}j';
    final due = r.amountDueXaf > 0 ? ' · ${r.amountDueXaf} FCFA dus' : '';
    return InkWell(
      onTap: () => context.go(Routes.superGroupes),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(r.groupName, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('${r.planName} · $when$due',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}
