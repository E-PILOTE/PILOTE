part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FRISE — le déroulé de l'année, en une image.
//
//  Un calendrier national se lit dans le temps, pas dans un tableau. Quatre
//  questions doivent trouver leur réponse d'un coup d'œil : où en est-on, quel
//  trimestre court, le calendrier couvre-t-il toute l'année, et combien de
//  jours de classe reste-t-il ? Les trous entre segments sont donc VISIBLES :
//  un vide en février, c'est un mois que personne n'a rattaché à un trimestre —
//  invisible dans une liste.
//
//  Les jours non ouvrés (vacances, fériés) ont leur propre bande au-dessus des
//  trimestres. Sans eux, la frise donnait une durée brute qui n'a jamais existé
//  pour personne : la seule durée qui compte se mesure en jours de classe.
//
//  L'écran école a sa frise depuis longtemps (calendar_detail.dart) ; l'écran
//  qui gouverne ce calendrier n'en avait pas.
// ════════════════════════════════════════════════════════════════════════════

double _frac(DateTime d, DateTime start, DateTime end) {
  final total = end.difference(start).inSeconds;
  if (total <= 0) return 0;
  return (d.difference(start).inSeconds / total).clamp(0.0, 1.0);
}

Color _holidayColor(AdminHoliday h) =>
    h.isFerie ? const Color(0xFFEF4444) : const Color(0xFF7C3AED);

class _YearTimelineCard extends ConsumerWidget {
  const _YearTimelineCard({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calAsync = ref.watch(adminYearCalendarProvider(year.id));
    final holAsync = ref.watch(adminYearHolidaysProvider(year.id));
    final trims = calAsync.valueOrNull ?? const <AdminTrimester>[];
    final jours = holAsync.valueOrNull ?? const <AdminHoliday>[];

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            "Déroulé de l'année ${year.label}",
            icon: Icons.timeline_rounded,
            tint: kNavy,
            subtitle: '${_fmt.format(year.startDate)} → '
                '${_fmt.format(year.endDate)}',
            trailing: _YearPhaseBadge(year: year, trimesters: trims),
          ),
          const SizedBox(height: 16),
          if (calAsync.isLoading)
            const SizedBox(
              height: 84,
              child: Center(child: CircularProgressIndicator()),
            )
          // ⚠️ L'ERREUR AVANT LE VIDE. Sur échec, `trims` était vide et la carte
          // annonçait « Aucun trimestre défini pour 2025-2026 : sans découpage,
          // ni bulletins ni conseils de classe ne peuvent être générés » — une
          // alerte grave, fabriquée par une coupure réseau, sur un calendrier
          // qui existe.
          else if (calAsync.hasError)
            SizedBox(
              height: 150,
              child: _ChartError(
                quoi: "le calendrier de l'année",
                onRetry: () =>
                    ref.invalidate(adminYearCalendarProvider(year.id)),
              ),
            )
          else if (trims.isEmpty)
            _TimelineEmpty(year: year)
          else ...[
            _TimelineBar(year: year, trimesters: trims, holidays: jours),
            const SizedBox(height: 14),
            _TimelineLegend(
                year: year,
                trimesters: trims,
                holidays: jours,
                joursInconnus: holAsync.hasError),
          ],
        ],
      ),
    );
  }
}

// ─── Badge d'état : où en est-on ? ────────────────────────────────────────────
class _YearPhaseBadge extends StatelessWidget {
  const _YearPhaseBadge({required this.year, required this.trimesters});
  final AdminYear year;
  final List<AdminTrimester> trimesters;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    if (year.startDate.isAfter(now)) {
      final j = year.daysToStart;
      return AdminBadge(
        j <= 0 ? 'Rentrée imminente' : 'Rentrée dans $j jour${j > 1 ? 's' : ''}',
        color: j <= 30 ? kAccent : kNavy,
      );
    }
    if (year.endDate.isBefore(now)) {
      // ⚠️ UNE ANNÉE CLOSE QUI RESTE « COURANTE » EN BASE EST UN OUBLI, PAS UN
      // ÉTAT. Tant que la rentrée n'a pas basculé, toute écriture du réseau —
      // inscription, note, bulletin — continue de se rattacher à une année
      // terminée. Le badge disait « Année terminée » d'un gris neutre, pendant
      // que le reste de la page affichait « En cours » : deux vérités sur le
      // même écran, et aucune ne disait quoi faire.
      if (year.isCurrent) {
        return AdminBadge(
          'Terminée — rentrée non basculée',
          color: kAccent,
          icon: Icons.warning_amber_rounded,
        );
      }
      return AdminBadge('Année terminée', color: kTextMuted);
    }

    // En cours : nommer le trimestre du jour plutôt que celui marqué « courant »
    // en base — l'écart entre les deux est précisément ce qu'on veut voir.
    AdminTrimester? actuel;
    for (final t in trimesters) {
      if (!t.startDate.isAfter(now) && !t.endDate.isBefore(now)) {
        actuel = t;
        break;
      }
    }
    final pct = (year.timeProgress * 100).round();
    return AdminBadge(
      actuel == null ? 'En cours · $pct %' : '${actuel.label} · $pct %',
      color: kGreen,
    );
  }
}

// ─── La barre ─────────────────────────────────────────────────────────────────
class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.year,
    required this.trimesters,
    required this.holidays,
  });
  final AdminYear year;
  final List<AdminTrimester> trimesters;
  final List<AdminHoliday> holidays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inRange =
        !now.isBefore(year.startDate) && !now.isAfter(year.endDate);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double x(DateTime d) => _frac(d, year.startDate, year.endDate) * w;

        return SizedBox(
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bande des jours non ouvrés (au-dessus des trimestres).
              Positioned(
                left: 0,
                right: 0,
                top: 15,
                height: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final h in holidays)
                Positioned(
                  left: x(h.startDate),
                  top: 15,
                  // Un férié d'un seul jour ferait 1 px sur une année : on lui
                  // garantit 3 px, sinon il est invisible — donc absent.
                  width: (x(h.endDate) - x(h.startDate)).clamp(3.0, w),
                  height: 5,
                  child: Tooltip(
                    message: '${h.label}\n'
                        '${h.isSingleDay ? _fmt.format(h.startDate) : '${_fmt.format(h.startDate)} → ${_fmt.format(h.endDate)} (${h.dayCount} j)'}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: _holidayColor(h),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

              // Fond : la portion d'année non couverte par un trimestre.
              Positioned(
                left: 0,
                right: 0,
                top: 26,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: kBorder),
                  ),
                ),
              ),

              // Segments de trimestre.
              for (final (i, t) in trimesters.indexed)
                Positioned(
                  left: x(t.startDate),
                  top: 26,
                  width: (x(t.endDate) - x(t.startDate)).clamp(2.0, w),
                  height: 30,
                  child: Tooltip(
                    message: '${t.label}\n'
                        '${_fmt.format(t.startDate)} → '
                        '${_fmt.format(t.endDate)}'
                        '${t.sequences.isEmpty ? '' : '\n${t.sequences.length} séquence(s)'}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: _palAt(i).withValues(alpha: t.isCurrent ? 1 : .78),
                        borderRadius: BorderRadius.circular(7),
                        border: t.isCurrent
                            ? Border.all(color: kTextPrimary, width: 1.6)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: (x(t.endDate) - x(t.startDate)) < 46
                          ? null
                          : Text(
                              'T${t.number}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),

              // Séquences : petits repères sous la barre.
              for (final (i, t) in trimesters.indexed)
                for (final s in t.sequences)
                  Positioned(
                    left: x(s.startDate),
                    top: 60,
                    width: (x(s.endDate) - x(s.startDate)).clamp(2.0, w),
                    height: 5,
                    child: Tooltip(
                      message: 'Séq. ${s.number} · ${s.label}\n'
                          '${_fmt.format(s.startDate)} → '
                          '${_fmt.format(s.endDate)}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: _palAt(i).withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),

              // Repère « aujourd'hui ».
              if (inRange) ...[
                Positioned(
                  left: x(now) - 1,
                  top: 13,
                  width: 2,
                  height: 50,
                  child: Container(color: kRed),
                ),
                Positioned(
                  left: (x(now) - 34).clamp(0.0, (w - 68).clamp(0.0, w)),
                  top: 0,
                  width: 68,
                  child: Text(
                    "aujourd'hui",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kRed),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Légende + jours de classe + détection des trous ──────────────────────────
class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend({
    required this.year,
    required this.trimesters,
    required this.holidays,
    this.joursInconnus = false,
  });
  final AdminYear year;
  final List<AdminTrimester> trimesters;
  final List<AdminHoliday> holidays;

  /// La liste des jours non ouvrés n'a pas pu être chargée. À distinguer d'une
  /// liste vide : dans un cas on ne sait pas, dans l'autre rien n'est saisi.
  final bool joursInconnus;

  @override
  Widget build(BuildContext context) {
    final ouvres = countWorkingDays(
      year.startDate,
      year.endDate,
      [for (final h in holidays) (start: h.startDate, end: h.endDate)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final (i, t) in trimesters.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                        color: _palAt(i),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 7),
                  Text(t.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(width: 6),
                  Text(
                      '${_fmtShort.format(t.startDate)}–'
                      '${_fmtShort.format(t.endDate)}',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                  if (t.sequences.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('· ${t.sequences.length} séq.',
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          Icon(joursInconnus ? Icons.help_outline_rounded : Icons.school_rounded,
              size: 16, color: joursInconnus ? kAccent : kGreen),
          const SizedBox(width: 7),
          Text(joursInconnus ? '$ouvres jours (approximatif)' : '$ouvres jours de classe',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              // Un décompte fondé sur une liste qu'on n'a PAS pu charger est
              // faux, pas vide : le dire, plutôt que de laisser croire que le
              // calendrier ne porte aucun férié.
              joursInconnus
                  ? '— les jours non ouvrés n\'ont pas pu être chargés : '
                      'seuls les week-ends sont déduits, ce total est trop haut'
                  : holidays.isEmpty
                      ? '— aucun jour non ouvré saisi : week-ends déduits '
                          'seulement, les fériés manquent'
                      : '— week-ends, '
                          '${holidays.where((h) => h.isFerie).length} férié(s) '
                          'et ${holidays.where((h) => !h.isFerie).length} '
                          'période(s) de vacances déduits',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ),
        ]),
        ..._trous().map((m) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 15, color: kAccent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(m,
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ),
              ]),
            )),
      ],
    );
  }

  /// Intervalles de plus d'une semaine entre deux trimestres consécutifs :
  /// vacances légitimes, ou oubli de saisie. La frise le montre, la légende le
  /// nomme — c'est à l'administrateur de trancher.
  List<String> _trous() {
    final out = <String>[];
    for (var i = 0; i + 1 < trimesters.length; i++) {
      final fin = trimesters[i].endDate;
      final debut = trimesters[i + 1].startDate;
      final jours = debut.difference(fin).inDays;
      if (jours > 7) {
        out.add('$jours jours non couverts entre ${trimesters[i].label} '
            'et ${trimesters[i + 1].label} '
            '(${_fmtShort.format(fin)} → ${_fmtShort.format(debut)}).');
      }
    }
    return out;
  }
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(Icons.event_busy_rounded, size: 26, color: kTextMuted),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Aucun trimestre défini pour ${year.label} : sans découpage, ni '
            'bulletins ni conseils de classe ne peuvent être générés.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
          ),
        ),
        const SizedBox(width: 12),
        if (!year.isLocked)
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AdminYearCalendarDialog(year: year),
            ),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Définir le calendrier'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              side: BorderSide(color: kBorder),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }
}
