part of 'admin_year_calendar_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VACANCES ET JOURS FÉRIÉS — le calendrier national des jours NON ouvrés.
//
//  Jusqu'ici la table `school_holidays` exigeait un `school_id` : chaque
//  établissement ressaisissait les fériés légaux. À l'échelle visée, c'est
//  mille saisies du même 25 décembre — et la table était encore vide, ce qui
//  dit assez que personne ne s'y est risqué. Le groupe les fixe désormais une
//  fois, les écoles en héritent, et chacune reste libre d'ajouter ses propres
//  fermetures.
//
//  Le chiffre qui compte n'est pas « combien de fériés » mais « combien de
//  jours de classe reste-t-il » : c'est lui qu'on met en tête.
// ════════════════════════════════════════════════════════════════════════════

class _HolidaysSection extends ConsumerWidget {
  const _HolidaysSection({required this.year, required this.readOnly});
  final AdminYear year;
  final bool readOnly;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() op, String ok) async {
    try {
      await op();
      ref.invalidate(adminYearHolidaysProvider(year.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kGreen, content: Text(ok)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _ajouter(BuildContext context, WidgetRef ref) async {
    final r = await showHolidayDialog(context,
        yearLabel: year.label, yearStart: year.startDate, yearEnd: year.endDate);
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).createHoliday(
            yearId: year.id,
            label: r.label,
            kind: r.kind,
            start: r.start,
            end: r.end),
        'Période ajoutée');
  }

  Future<void> _modifier(
      BuildContext context, WidgetRef ref, AdminHoliday h) async {
    final r = await showHolidayDialog(context,
        yearLabel: year.label,
        yearStart: year.startDate,
        yearEnd: year.endDate,
        existing: (
          label: h.label,
          kind: h.kind,
          start: h.startDate,
          end: h.endDate
        ));
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).updateHoliday(
            id: h.id,
            label: r.label,
            kind: r.kind,
            start: r.start,
            end: r.end),
        'Période modifiée');
  }

  Future<void> _supprimer(
      BuildContext context, WidgetRef ref, AdminHoliday h) async {
    final ok = await showAdminConfirm(
      context,
      danger: true,
      title: 'Supprimer « ${h.label} »',
      confirmLabel: 'Supprimer',
      message: 'Cette période redeviendra ouvrée pour TOUTES les écoles du '
          'groupe, à leur prochaine synchronisation.',
    );
    if (!ok || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).deleteHoliday(h.id),
        'Période supprimée');
  }

  Future<void> _semer(BuildContext context, WidgetRef ref) async {
    final ok = await showAdminConfirm(
      context,
      title: 'Installer les fériés légaux',
      icon: Icons.auto_awesome_rounded,
      confirmLabel: 'Installer',
      confirmIcon: Icons.playlist_add_check_rounded,
      message: 'Les jours fériés de la République du Congo tombant dans '
          "l'année ${year.label} seront ajoutés au calendrier national :\n\n"
          "Jour de l'An, Lundi de Pâques, Fête du Travail, Ascension, Lundi de "
          'Pentecôte, Fête de la Réconciliation (10 juin), Fête Nationale, '
          'Toussaint, Jour de la République (28 novembre) et Noël.\n\n'
          'Les dates pascales sont calculées, pas saisies. Les jours déjà '
          'présents ne sont pas dupliqués.',
    );
    if (!ok || !context.mounted) return;
    try {
      final n = await ref
          .read(adminCalendarServiceProvider)
          .seedNationalHolidays(year.id);
      ref.invalidate(adminYearHolidaysProvider(year.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: n == 0 ? kAccent : kGreen,
        content: Text(n == 0
            ? 'Les fériés légaux étaient déjà tous installés.'
            : '$n jour${n > 1 ? 's' : ''} férié${n > 1 ? 's' : ''} '
                'ajouté${n > 1 ? 's' : ''}.'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(messageErreur(e, contexte: 'Fériés'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearHolidaysProvider(year.id));
    final jours = async.valueOrNull ?? const <AdminHoliday>[];

    final feries = jours.where((h) => h.isFerie).length;
    final vacances = jours.length - feries;
    final ouvres = countWorkingDays(
      year.startDate,
      year.endDate,
      [for (final h in jours) (start: h.startDate, end: h.endDate)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.beach_access_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Vacances et jours fériés',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          if (!readOnly) ...[
            TextButton.icon(
              onPressed: () => _semer(context, ref),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Fériés légaux',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kGreen),
            ),
            TextButton.icon(
              onPressed: () => _ajouter(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kNavy),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGreen.withValues(alpha: .25)),
          ),
          child: Row(children: [
            Icon(Icons.school_rounded, size: 18, color: kGreen),
            const SizedBox(width: 10),
            Text('$ouvres',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'jours de classe — hors week-ends, '
                  '$feries férié${feries > 1 ? 's' : ''} et '
                  '$vacances période${vacances > 1 ? 's' : ''} de vacances',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (jours.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              readOnly
                  ? 'Aucun jour non ouvré défini pour cette année.'
                  : 'Aucun jour non ouvré. Sans eux, les emplois du temps des '
                      'écoles compteront Noël et la Toussaint comme des jours '
                      'de classe — commencez par « Fériés légaux ».',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
            ),
          )
        else
          ...jours.map((h) => _HolidayRow(
                holiday: h,
                readOnly: readOnly,
                onEdit: () => _modifier(context, ref, h),
                onDelete: () => _supprimer(context, ref, h),
              )),
      ],
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({
    required this.holiday,
    required this.readOnly,
    required this.onEdit,
    required this.onDelete,
  });
  final AdminHoliday holiday;
  final bool readOnly;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final couleur = holiday.isFerie ? kNavy : const Color(0xFF7C3AED);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: couleur, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(holiday.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ),
        Text(
          holiday.isSingleDay
              ? _fmt.format(holiday.startDate)
              : '${_fmt.format(holiday.startDate)} → '
                  '${_fmt.format(holiday.endDate)} · ${holiday.dayCount} j',
          style: TextStyle(fontSize: 11, color: kTextMuted),
        ),
        if (!readOnly) ...[
          IconButton(
            tooltip: 'Modifier',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 15, color: kNavy),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
            onPressed: onDelete,
          ),
        ],
      ]),
    );
  }
}
