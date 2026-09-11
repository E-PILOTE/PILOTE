part of '../admin_subscription_screen.dart';

// Formules proposées et demande en attente.

class _PlansGrid extends StatelessWidget {
  const _PlansGrid({
    required this.plans,
    required this.currentPlanId,
    required this.locked,
  });
  final List<PlanOption> plans;
  final String? currentPlanId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return AdminCard(child: Text('Aucune offre disponible pour le moment.',
          style: TextStyle(color: kTextMuted)));
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180 ? 4 : c.maxWidth >= 880 ? 3 : c.maxWidth >= 560 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: plans
            .map((p) => SizedBox(
                  width: w,
                  child: _PlanCard(
                    plan: p,
                    current: p.id == currentPlanId,
                    locked: locked,
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.current, required this.locked});
  final PlanOption plan;
  final bool current;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pColor = planColor(plan.slug);
    return AdminCard(
      accent: current ? kGreen : pColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(plan.name, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            if (current) AdminBadge('Plan actuel', color: kGreen, icon: Icons.check_rounded),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(plan.priceXaf == 0 ? 'Gratuit' : fmtXaf(plan.priceXaf),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: pColor)),
            if (plan.priceXaf != 0)
              // La période vient du plan : « / an » en dur contredisait
              // l'espace plateforme, qui affichait « / mois » pour le MÊME
              // tarif. C'est cette divergence qu'on supprime.
              Text(' / ${plan.periodSuffix}', style: TextStyle(fontSize: 12.5, color: kTextMuted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          _PlanFeature(icon: Icons.school_rounded, text: plan.unlimitedSchools ? 'Écoles illimitées' : '${plan.maxSchools} école${plan.maxSchools > 1 ? 's' : ''}'),
          _PlanFeature(icon: Icons.groups_rounded, text: plan.unlimitedStudents ? 'Élèves illimités' : '${fmtInt(plan.maxStudents)} élèves'),
          _PlanFeature(icon: Icons.badge_rounded, text: plan.unlimitedStaff ? 'Personnel illimité' : '${fmtInt(plan.maxStaff)} personnels'),
          _PlanFeature(icon: Icons.extension_rounded, text: '${plan.moduleCount} modules'),
          const SizedBox(height: 8),
          Text(plan.effectiveDescription, style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
          if (plan.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: kBorder, height: 1),
            const SizedBox(height: 10),
            Text('Familles de modules', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextMuted, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: plan.categories
                  .map((c) => _CategoryChip(label: c.name, count: c.moduleCount, color: pColor))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _planButton(context),
          ),
        ],
      ),
    );
  }

  Widget _planButton(BuildContext context) {
    if (current) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.verified_rounded, size: 16),
        label: const Text('Plan en cours'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreen,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (locked) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded, size: 16),
        label: const Text('Demande en cours'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextMuted,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => RequestPlanChangeDialog(plan: plan),
      ),
      icon: const Icon(Icons.send_rounded, size: 16),
      label: const Text('Demander ce plan'),
      style: FilledButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text('$label · $count',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 15, color: kTextMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: kTextPrimary))),
      ]),
    );
  }
}

// ─── Bannière « demande en cours » ─────────────────────────────────────────────
class _PendingRequestBanner extends StatelessWidget {
  const _PendingRequestBanner({required this.t});
  final SubscriptionTicket t;

  @override
  Widget build(BuildContext context) {
    final inProgress = t.status == 'in_progress';
    final color = inProgress ? kNavy : kAccent;
    final label = inProgress ? 'en cours de traitement' : 'en attente de validation';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(inProgress ? Icons.autorenew_rounded : Icons.hourglass_top_rounded, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Une demande de changement de plan est $label.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text('Vous pourrez en soumettre une nouvelle une fois celle-ci traitée.',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Matrice comparative des plans ──────────────────────────────────────────────
