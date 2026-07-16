part of 'conseils_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TIROIR DE DÉLIBÉRATION — un élève. Récapitulatif (moyenne, rang, mention),
//  choix de la DISTINCTION (chips, dont « Aucune »), et APPRÉCIATION du conseil.
//  Enregistrement offline immédiat sur le bulletin. Lecture seule si l'année est
//  verrouillée ou la permission absente.
// ════════════════════════════════════════════════════════════════════════════
class _DeliberationSheet extends ConsumerStatefulWidget {
  const _DeliberationSheet({
    required this.entry,
    required this.trimesterId,
    required this.canEdit,
    required this.onSaved,
  });
  final CouncilEntry entry;
  final String trimesterId;
  final bool canEdit;
  final VoidCallback onSaved;
  @override
  ConsumerState<_DeliberationSheet> createState() => _DeliberationSheetState();
}

class _DeliberationSheetState extends ConsumerState<_DeliberationSheet> {
  late String? _award = widget.entry.award;
  late final TextEditingController _appr =
      TextEditingController(text: widget.entry.appreciation ?? '');
  bool _busy = false;

  // Éditable seulement si la permission le permet ET le bulletin existe (sinon
  // l'UPDATE n'affecterait aucune ligne).
  bool get _editable => widget.canEdit && widget.entry.bulletinExists;

  @override
  void dispose() {
    _appr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runModuleWrite(
      context,
      () => saveCouncilDecision(
        enrollmentId: widget.entry.enrollmentId,
        trimesterId: widget.trimesterId,
        award: _award,
        appreciation: _appr.text,
      ),
      success: 'Délibération enregistrée',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  Color _avgColor(double? a) => a == null
      ? kTextMuted
      : a >= 14
          ? kGreen
          : a >= 10
              ? const Color(0xFF0EA5E9)
              : const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final suggestion = suggestedAward(e.average);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.studentName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(
                          '${e.rank == 0 ? '—' : '${e.rank}ᵉ/${e.totalStudents}'} · ${e.mention}'
                          '${e.matricule != null ? ' · ${e.matricule}' : ''}',
                          style:
                              TextStyle(fontSize: 12, color: kTextMuted)),
                    ]),
              ),
              if (!widget.canEdit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: kTextMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 13, color: kTextMuted),
                    const SizedBox(width: 5),
                    Text('Lecture seule',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kTextMuted)),
                  ]),
                ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (widget.canEdit && !widget.entry.bulletinExists) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kAccent.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: kAccent),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                            'Bulletin non encore généré pour cet élève. '
                            'Générez les bulletins de la classe pour pouvoir '
                            'le délibérer.',
                            style:
                                TextStyle(fontSize: 12, color: kTextPrimary)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                // Récapitulatif.
                Row(children: [
                  _summaryBox(
                      'Moyenne',
                      e.average == null
                          ? '—'
                          : e.average!.toStringAsFixed(2),
                      _avgColor(e.average)),
                  const SizedBox(width: 10),
                  _summaryBox(
                      'Rang',
                      e.rank == 0 ? '—' : '${e.rank}/${e.totalStudents}',
                      kNavy),
                  const SizedBox(width: 10),
                  _summaryBox('Mention', e.mention, const Color(0xFFF59E0B)),
                ]),
                const SizedBox(height: 22),
                const _Label('Distinction du conseil'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _AwardChip(
                    label: 'Aucune',
                    color: kNoAwardColor,
                    icon: Icons.remove_rounded,
                    selected: _award == null || _award!.isEmpty,
                    onTap: _editable
                        ? () => setState(() => _award = null)
                        : null,
                  ),
                  for (final a in councilAwards)
                    _AwardChip(
                      label: a.label,
                      color: a.color,
                      icon: a.icon,
                      selected: _award == a.code,
                      suggested: suggestion == a.code,
                      onTap: _editable
                          ? () => setState(() => _award = a.code)
                          : null,
                    ),
                ]),
                const SizedBox(height: 22),
                const _Label('Appréciation du conseil'),
                const SizedBox(height: 10),
                TextField(
                  controller: _appr,
                  maxLines: 4,
                  enabled: _editable,
                  decoration: InputDecoration(
                    hintText:
                        'Trimestre satisfaisant, doit soutenir l\'effort en…',
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_editable)
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Enregistrer la délibération'),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryBox(String l, String v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Text(v,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(l,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: kTextMuted)),
          ]),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kTextMuted,
          letterSpacing: 0.6));
}

class _AwardChip extends StatelessWidget {
  const _AwardChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.suggested = false,
  });
  final String label;
  final Color color;
  final IconData icon;
  final bool selected, suggested;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : kBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: selected ? color : kTextMuted),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : kTextPrimary)),
          if (suggested && !selected) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('proposé',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ]),
      ),
    );
  }
}
