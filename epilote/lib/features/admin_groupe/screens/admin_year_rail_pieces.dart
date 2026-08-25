part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES PIÈCES DU RAIL — pastille d'année, chevrons, voiles de bord, menu.
//
//  Séparées de `admin_year_rail.dart`, qui ne garde que la lentille et la
//  mécanique de défilement : la coupe suit la couture entre « ce qui décide »
//  et « ce qui se dessine », pas un simple compte de lignes.
// ════════════════════════════════════════════════════════════════════════════

// ─── Une pastille d'année ─────────────────────────────────────────────────────
//
//  Le fond vit sur le `Material` et non sur le `Container` : posé sur le
//  conteneur, il masquait l'encre de l'`InkWell` — la pastille ne réagissait
//  visiblement ni au survol ni au clic. `animationDuration` fait le reste, y
//  compris pour l'élévation, qui donne à la pastille choisie un vrai relief.
class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selectionnee,
    required this.onTap,
  });
  final AdminYear year;
  final bool selectionnee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = _status(year);
    final on = selectionnee;
    final sousTitre = year.isDraft
        ? 'Brouillon'
        : '${fmtInt(year.eleves)} élèves · ${year.classes} cl.';

    return Tooltip(
      message: '${year.label} — ${st.label}\n'
          '${_fmt.format(year.startDate)} → ${_fmt.format(year.endDate)}',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        animationDuration: const Duration(milliseconds: 180),
        color: on ? kNavy : kCardBg,
        elevation: on ? 4 : 0,
        shadowColor: kNavy.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          hoverColor: on
              ? Colors.white.withValues(alpha: 0.10)
              : kNavy.withValues(alpha: 0.06),
          focusColor: kNavy.withValues(alpha: 0.14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(13, 8, 14, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: on ? Colors.transparent : kBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: on ? Colors.white : st.color,
                    shape: BoxShape.circle,
                    boxShadow: on
                        ? null
                        : [
                            BoxShadow(
                              color: st.color.withValues(alpha: 0.45),
                              blurRadius: 5,
                            ),
                          ],
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      year.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: on ? Colors.white : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sousTitre,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle:
                            year.isDraft ? FontStyle.italic : FontStyle.normal,
                        color: on
                            ? Colors.white.withValues(alpha: 0.82)
                            : year.isDraft
                                ? kAccent
                                : kTextMuted,
                      ),
                    ),
                  ],
                ),
                if (on) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chevron de pagination ────────────────────────────────────────────────────
class _FlecheRail extends StatelessWidget {
  const _FlecheRail({
    required this.icon,
    required this.tooltip,
    required this.actif,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: actif ? onTap : null,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 30,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kBorder),
            ),
            child: Icon(
              icon,
              size: 21,
              color: actif ? kNavy : kTextMuted.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Voile de bord : « la liste continue par ici » ────────────────────────────
class _VoileBord extends StatelessWidget {
  const _VoileBord({required this.gauche, required this.visible});
  final bool gauche;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: gauche ? 0 : null,
      right: gauche ? null : 0,
      top: 0,
      bottom: 10,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: gauche ? Alignment.centerLeft : Alignment.centerRight,
                end: gauche ? Alignment.centerRight : Alignment.centerLeft,
                colors: [kCardBg, kCardBg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Accès exhaustif : toutes les années d'un coup ────────────────────────────
class _MenuAnnees extends StatelessWidget {
  const _MenuAnnees({
    required this.years,
    required this.selectedId,
    required this.onChoisir,
  });
  final List<AdminYear> years;
  final String selectedId;
  final ValueChanged<String> onChoisir;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Toutes les années (${years.length})',
      position: PopupMenuPosition.under,
      onSelected: onChoisir,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      itemBuilder: (_) => [
        for (final y in years)
          PopupMenuItem<String>(
            value: y.id,
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _status(y).color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    y.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          y.id == selectedId ? FontWeight.w800 : FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ),
                Text(
                  y.isDraft ? 'Brouillon' : _status(y).label,
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
                const SizedBox(width: 8),
                Icon(
                  y.id == selectedId
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: y.id == selectedId
                      ? kGreen
                      : kTextMuted.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 38,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.expand_more_rounded, size: 22, color: kNavy),
      ),
    );
  }
}
