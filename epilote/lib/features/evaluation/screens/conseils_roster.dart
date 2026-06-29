part of 'conseils_screen.dart';

// ─── Barre d'actions + bandeau statut ────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.session,
    required this.busy,
    required this.canEdit,
    required this.onGenerate,
    required this.onAutofill,
    required this.onStatus,
    required this.onSynthesis,
    required this.onPv,
  });
  final CouncilSession session;
  final bool busy, canEdit;
  final VoidCallback onGenerate, onAutofill, onSynthesis, onPv;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final validated = session.overallStatus == 'validated' ||
        session.overallStatus == 'published';
    final (icon, color, text) = switch (session.overallStatus) {
      'none' => (
          Icons.pending_outlined,
          kTextMuted,
          'Bulletins non générés — générez-les pour ouvrir la délibération'
        ),
      'validated' => (
          Icons.verified_rounded,
          kGreen,
          'Délibération validée par le conseil — bulletins prêts à publier'
        ),
      'published' => (
          Icons.verified_rounded,
          kGreen,
          'Bulletins publiés aux familles'
        ),
      _ => (
          Icons.how_to_vote_rounded,
          kAccent,
          'Délibération en cours — ${session.deliberatedCount}/${session.generatedCount} élèves traités'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          if (busy)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (session.bulletinsReady)
            OutlinedButton.icon(
              onPressed: busy ? null : onPv,
              style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kNavy.withValues(alpha: 0.4))),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Procès-verbal'),
            ),
          if (canEdit) ...[
            if (!session.bulletinsReady)
              FilledButton.icon(
                onPressed: busy ? null : onGenerate,
                style: FilledButton.styleFrom(backgroundColor: kNavy),
                icon: const Icon(Icons.calculate_rounded, size: 16),
                label: const Text('Générer les bulletins'),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: busy ? null : onAutofill,
                style: OutlinedButton.styleFrom(
                    foregroundColor: kNavy,
                    side: BorderSide(color: kNavy.withValues(alpha: 0.4))),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: const Text('Pré-remplir'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onSynthesis,
                style: OutlinedButton.styleFrom(
                    foregroundColor: kNavy,
                    side: BorderSide(color: kNavy.withValues(alpha: 0.4))),
                icon: const Icon(Icons.notes_rounded, size: 16),
                label: const Text('Synthèse'),
              ),
              if (!validated)
                FilledButton.icon(
                  onPressed: busy ? null : () => onStatus('validated'),
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text('Valider la délibération'),
                )
              else if (session.overallStatus == 'validated')
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onStatus('draft'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kAccent,
                      side: BorderSide(color: kAccent.withValues(alpha: 0.4))),
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: const Text('Rouvrir'),
                ),
            ],
          ],
        ]),
      ]),
    );
  }
}

// ─── Carte synthèse de classe ────────────────────────────────────────────────
class _SynthesisCard extends StatelessWidget {
  const _SynthesisCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.forum_rounded, size: 15, color: kNavy),
          SizedBox(width: 7),
          Text('Synthèse du conseil',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                  letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: kTextPrimary)),
      ]),
    );
  }
}

// ─── Invite à générer les bulletins ──────────────────────────────────────────
class _GeneratePrompt extends StatelessWidget {
  const _GeneratePrompt();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: AdminEmptyState(
        icon: Icons.calculate_outlined,
        title: 'Bulletins à générer',
        message:
            'Les moyennes ci-dessus sont déjà calculées. Cliquez sur « Générer '
            'les bulletins » pour pouvoir attribuer les distinctions et '
            'appréciations du conseil, élève par élève.',
      ),
    );
  }
}

// ─── Ligne élève (classée, distinction inline) ───────────────────────────────
class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.entry, required this.onTap});
  final CouncilEntry entry;
  final VoidCallback onTap;

  Color _avgColor(double? a) => a == null
      ? kTextMuted
      : a >= 14
          ? kGreen
          : a >= 10
              ? const Color(0xFF0EA5E9)
              : const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final award = awardFor(entry.award);
    final hasAppr = (entry.appreciation ?? '').trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(entry.rank == 0 ? '—' : '${entry.rank}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Row(children: [
                      Text(entry.mention,
                          style:
                              const TextStyle(fontSize: 11.5, color: kTextMuted)),
                      if (hasAppr) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 12, color: kTextMuted),
                      ],
                    ]),
                  ]),
            ),
            if (award != null)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: award.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(award.icon, size: 13, color: award.color),
                  const SizedBox(width: 5),
                  Text(award.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: award.color)),
                ]),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: const Text('À délibérer',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _avgColor(entry.average).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                  entry.average == null
                      ? '—'
                      : '${entry.average!.toStringAsFixed(2)}/20',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _avgColor(entry.average))),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ]),
        ),
      ),
    );
  }
}
