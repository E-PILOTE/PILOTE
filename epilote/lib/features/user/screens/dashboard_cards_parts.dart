part of 'user_dashboard_screen.dart';

// ─── Accueil parent / élève (pas de modules de gestion) ───────────────────────
class _ParentWelcomeCard extends StatelessWidget {
  const _ParentWelcomeCard({required this.isParent});
  final bool isParent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
                isParent
                    ? Icons.family_restroom_rounded
                    : Icons.school_rounded,
                color: kGreen,
                size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isParent ? 'Espace Parent' : 'Espace Élève',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    isParent
                        ? 'Retrouvez le suivi de votre enfant (notes, présences, '
                            'paiements) et les annonces de l\'école.'
                        : 'Retrouvez vos informations scolaires et les annonces '
                            'de votre établissement.',
                    style: TextStyle(
                        fontSize: 12.5, color: kTextMuted, height: 1.5),
                  ),
                ]),
          ),
          const SizedBox(width: 12),
          AdminActionButton(
            label: 'Annonces',
            icon: Icons.campaign_rounded,
            color: kNavy,
            onPressed: () => context.go(Routes.annonces),
          ),
        ]),
      ),
    );
  }
}

// ─── À traiter : inscriptions en attente ──────────────────────────────────────
class _PendingInscriptionsCard extends ConsumerWidget {
  const _PendingInscriptionsCard({required this.canValidate});
  final bool canValidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingEnrollmentsProvider).valueOrNull ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    final shown = pending.take(4).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.pending_actions_rounded,
                  size: 18, color: Color(0xFFB45309)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('À traiter — ${pending.length} inscription(s) en attente',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            TextButton(
              onPressed: () => context.push(Routes.inscriptions),
              child: Text(canValidate ? 'Valider' : 'Voir',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          for (final e in shown) ...[
            Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: kNavy.withValues(alpha: 0.1),
                  child: Text(
                    (e.studentFirstName?.isNotEmpty == true)
                        ? e.studentFirstName![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: kNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.studentFullName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                AdminBadge(e.inscriptionTypeLabel, color: kNavy),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Annonces récentes ────────────────────────────────────────────────────────
class _RecentAnnouncementsCard extends ConsumerWidget {
  const _RecentAnnouncementsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anns = ref.watch(schoolAnnouncementsProvider).valueOrNull ?? const [];
    if (anns.isEmpty) return const SizedBox.shrink();
    final shown = anns.take(3).toList();
    final fmt = DateFormat('d MMM', 'fr_FR');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.campaign_rounded, size: 18, color: kGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Annonces récentes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            TextButton(
              onPressed: () => context.go(Routes.annonces),
              child: Text('Tout voir',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          for (final a in shown) ...[
            Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                if (a.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin_rounded, size: 14, color: kAccent),
                  ),
                Expanded(
                  child: Text(a.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(
                  a.publishedAt != null ? fmt.format(a.publishedAt!) : '',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
