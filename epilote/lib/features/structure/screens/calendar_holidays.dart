part of 'school_calendar_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  JOURS NON OUVRÉS D'UNE ANNÉE — vacances scolaires et jours fériés.
//
//  Une page qui s'appelle « Calendrier scolaire » et ne montre pas les vacances
//  ne mérite pas son nom. La donnée existait (`school_holidays`, rattachée à
//  l'année), mais n'était visible que dans les réglages de l'emploi du temps —
//  c'est-à-dire là où on la SAISIT, jamais là où on la CONSULTE.
//
//  Le chiffre qui compte n'est pas le nombre de vacances : c'est le nombre de
//  JOURS DE CLASSE restants. C'est lui qui dit à un chef d'établissement s'il
//  bouclera son programme. Il est donc calculé (cf. `countSchoolDays`) et
//  affiché en premier.
//
//  Lecture seule ici, par construction : la saisie reste dans les réglages EDT,
//  un seul endroit pour écrire. On y renvoie plutôt que de la dupliquer.
// ════════════════════════════════════════════════════════════════════════════

class _HolidaysCard extends ConsumerWidget {
  const _HolidaysCard({required this.year, required this.trims});
  final AcademicYearModel year;
  final List<TrimesterModel> trims;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolHolidaysOfYearProvider(year.id));
    final role = ref.watch(authNotifierProvider).valueOrNull?.role ?? '';
    final canEdit = _kEditRoles.contains(role);

    // Le formulaire de saisie (réglages EDT) écrit TOUJOURS dans l'année
    // AFFICHÉE par l'application. Proposer « Gérer » en inspectant une autre
    // année enverrait donc les vacances saisies sur la mauvaise année, sans
    // que rien ne le signale. On n'ouvre le tiroir que si les deux coïncident ;
    // sinon on propose d'abord de basculer l'affichage.
    final isLens = ref.watch(activeYearIdProvider) == year.id;

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.beach_access_rounded, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Text('Jours non ouvrés',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const Spacer(),
          if (canEdit && !year.isLocked)
            isLens
                ? _MiniBtn(
                    label: 'Gérer',
                    icon: Icons.tune_rounded,
                    onTap: () => openEdtSettingsDrawer(context,
                        initialSegment: kEdtSegCalendar),
                  )
                : _MiniBtn(
                    label: 'Afficher pour modifier',
                    icon: Icons.visibility_outlined,
                    color: kGreen,
                    onTap: () => ref
                        .read(selectedYearIdProvider.notifier)
                        .select(year.id),
                  ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Vacances et jours fériés retenus pour cette année. Ils sont '
          'retirés du calcul des jours de classe et de la projection de '
          "l'emploi du temps.",
          style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        async.when(
          loading: () => const _HolidaysLoading(),
          error: (e, _) =>
              Text(messageErreur(e), style: TextStyle(fontSize: 12, color: kRed)),
          data: (holidays) => _HolidaysBody(
            year: year,
            trims: trims,
            holidays: holidays,
            canEdit: _kEditRoles.contains(role),
          ),
        ),
      ]),
    );
  }
}

class _HolidaysLoading extends StatelessWidget {
  const _HolidaysLoading();
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
        const SizedBox(width: 10),
        Text('Lecture du calendrier…',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      ]);
}

class _HolidaysBody extends StatelessWidget {
  const _HolidaysBody({
    required this.year,
    required this.trims,
    required this.holidays,
    required this.canEdit,
  });
  final AcademicYearModel year;
  final List<TrimesterModel> trims;
  final List<SchoolHoliday> holidays;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    if (holidays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              canEdit
                  ? 'Aucun jour non ouvré déclaré. Tant que les vacances et '
                      "fériés ne sont pas saisis, l'emploi du temps projette "
                      'des cours pendant les congés.'
                  : 'Aucun jour non ouvré déclaré pour cette année.',
              style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF92400E),
                  height: 1.4,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    }

    final feries = holidays.where((h) => h.isFerie).toList();
    final vacances = holidays.where((h) => !h.isFerie).toList();
    final joursChomes =
        holidays.fold<int>(0, (sum, h) => sum + h.dayCount);
    final joursClasse = countSchoolDays(year.startDate, year.endDate, holidays);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Les trois chiffres qui résument l'année.
      Wrap(spacing: 8, runSpacing: 8, children: [
        _StatPill(
            icon: Icons.event_available_rounded,
            value: '$joursClasse',
            label: 'jours de classe',
            color: kGreen),
        _StatPill(
            icon: Icons.beach_access_rounded,
            value: '${vacances.length}',
            label: vacances.length > 1 ? 'périodes de vacances' : 'période de vacances',
            color: kNavy),
        _StatPill(
            icon: Icons.flag_rounded,
            value: '${feries.length}',
            label: feries.length > 1 ? 'jours fériés' : 'jour férié',
            color: kAccent),
        _StatPill(
            icon: Icons.do_not_disturb_on_rounded,
            value: '$joursChomes',
            label: 'jours chômés au total',
            color: kTextMuted),
      ]),
      if (trims.isNotEmpty) ...[
        const SizedBox(height: 14),
        _SchoolDaysPerTrimester(trims: trims, holidays: holidays),
      ],
      const SizedBox(height: 14),
      Divider(height: 1, color: kBorder),
      const SizedBox(height: 10),
      ...holidays.map((h) => _HolidayLine(holiday: h)),
    ]);
  }
}

/// Jours de classe trimestre par trimestre — la vraie unité de pilotage
/// pédagogique : un programme se boucle par trimestre, pas par année.
class _SchoolDaysPerTrimester extends StatelessWidget {
  const _SchoolDaysPerTrimester({required this.trims, required this.holidays});
  final List<TrimesterModel> trims;
  final List<SchoolHoliday> holidays;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < trims.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: _kTrimColors[i % _kTrimColors.length],
                  borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(trims[i].label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          trims[i].isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: trims[i].isCurrent ? kNavy : kTextMuted)),
            ),
            Text(
              '${countSchoolDays(trims[i].startDate, trims[i].endDate, holidays)} jours de classe',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextMuted),
            ),
          ]),
        ),
    ]);
  }
}

class _HolidayLine extends StatelessWidget {
  const _HolidayLine({required this.holiday});
  final SchoolHoliday holiday;

  @override
  Widget build(BuildContext context) {
    final color = holiday.isFerie ? kAccent : kNavy;
    final past = holiday.endDate.isBefore(DateTime.now());
    final ongoing = holiday.covers(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(
            holiday.isFerie
                ? Icons.flag_rounded
                : Icons.beach_access_rounded,
            size: 14,
            color: past ? kTextMuted : color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            holiday.label.isEmpty ? holidayKindLabel(holiday.kind) : holiday.label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: ongoing ? FontWeight.w800 : FontWeight.w600,
                color: past ? kTextMuted : kNavy),
          ),
        ),
        if (ongoing) ...[
          _Tag(text: 'En cours', color: kGreen),
          const SizedBox(width: 8),
        ],
        Text(holiday.rangeLabel,
            style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        if (!holiday.isSingleDay) ...[
          const SizedBox(width: 8),
          Text('${holiday.dayCount} j',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextMuted)),
        ],
      ]),
    );
  }
}

/// Puce chiffrée réutilisée par les compteurs de l'année.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: kTextMuted)),
        ]),
      );
}
