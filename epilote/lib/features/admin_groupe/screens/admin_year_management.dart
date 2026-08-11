part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GESTION DES ANNÉES — section filtrable (Toutes/Actives/Archivées) + cartes.
// ════════════════════════════════════════════════════════════════════════════

/// Filtre actif de la section gestion : `all` | `active` | `archived`.
final _yearFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

class _ManagementSection extends ConsumerWidget {
  const _ManagementSection({required this.years});
  final List<AdminYear> years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_yearFilterProvider);
    final activeCount = years.where((y) => !y.isLocked).length;
    final archivedCount = years.where((y) => y.isLocked).length;

    // Le tri vit dans `filterAndSortYears` (provider) : fonction pure, qui
    // renvoie une liste NEUVE. Il triait auparavant la liste du provider en
    // place, ce qui faussait le graphe d'évolution et la variation « vs N-1 ».
    final shown = filterAndSortYears(years, filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: AdminSectionTitle('Gestion & archivage des années',
                  icon: Icons.settings_suggest_rounded,
                  subtitle:
                      'Créer, basculer la rentrée, archiver — toutes les écoles '
                      'héritent par synchro.'),
            ),
            _SegFilter(
              current: filter,
              segments: [
                (key: 'all', label: 'Toutes', count: years.length),
                (key: 'active', label: 'Actives', count: activeCount),
                (key: 'archived', label: 'Archivées', count: archivedCount),
              ],
              onSelect: (k) =>
                  ref.read(_yearFilterProvider.notifier).state = k,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          AdminCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  filter == 'archived'
                      ? 'Aucune année archivée.'
                      : 'Aucune année dans ce filtre.',
                  style: TextStyle(fontSize: 13, color: kTextMuted),
                ),
              ),
            ),
          )
        else
          ...shown.map((y) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _YearCard(year: y),
              )),
      ],
    );
  }
}

// ─── Segmented control (filtre) ────────────────────────────────────────────────
typedef _Seg = ({String key, String label, int count});

class _SegFilter extends StatelessWidget {
  const _SegFilter({
    required this.current,
    required this.segments,
    required this.onSelect,
  });
  final String current;
  final List<_Seg> segments;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((s) {
          final on = s.key == current;
          return GestureDetector(
            onTap: () => onSelect(s.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: on ? kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${s.label} (${s.count})',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : kTextMuted)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _YearCard extends ConsumerWidget {
  const _YearCard({required this.year});
  final AdminYear year;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() op,
    String success,
  ) async {
    try {
      await op();
      ref.invalidate(adminAcademicYearsProvider);
      ref.invalidate(adminYearAnalyticsProvider(year.id));
      ref.invalidate(adminYearCalendarProvider(year.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kGreen, content: Text(success)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  // ── Confirmations ─────────────────────────────────────────────────────────
  //  Ces deux gestes portent sur TOUT le réseau et ne se rattrapent pas d'un
  //  Ctrl+Z. Ils partaient pourtant au premier clic, sans un mot.

  Future<void> _confirmerCourante(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(adminCalendarServiceProvider);
    final ok = await showAdminConfirm(
      context,
      title: 'Basculer la rentrée sur ${year.label}',
      icon: Icons.move_up_rounded,
      confirmLabel: 'Basculer la rentrée',
      confirmIcon: Icons.check_circle_outline_rounded,
      message: '${year.label} deviendra l\'année courante du groupe.\n\n'
          'Toutes les écoles la reprendront à leur prochaine synchronisation : '
          'inscriptions, bulletins, notes et emplois du temps s\'y '
          'rattacheront. Assurez-vous que le calendrier de ${year.label} est '
          'défini avant de basculer.\n\n'
          "L'opération est tracée dans le journal d'audit.",
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => svc.setCurrentYear(year.id),
        'Rentrée basculée sur ${year.label}');
  }

  /// Publier = diffuser à tout le réseau. Le geste qui fait sortir l'année de
  /// l'espace groupe : jusque-là, ses dates se corrigent sans conséquence.
  Future<void> _confirmerPublication(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(adminCalendarServiceProvider);
    final ok = await showAdminConfirm(
      context,
      title: 'Publier ${year.label}',
      icon: Icons.campaign_rounded,
      confirmLabel: 'Publier aux écoles',
      confirmIcon: Icons.send_rounded,
      message:
          "L'année ${year.label} et son calendrier descendront sur les postes "
          'de toutes les écoles du groupe à leur prochaine synchronisation, et '
          "les chefs d'établissement en seront notifiés.\n\n"
          "Tant qu'une année est en brouillon, ses dates se corrigent sans "
          'conséquence. Après publication, une correction atteint tout le '
          'réseau.\n\n'
          "L'opération est tracée dans le journal d'audit.",
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await svc.publishYear(year.id);
      ref.invalidate(adminAcademicYearsProvider);
      messenger.showSnackBar(SnackBar(
        backgroundColor: kGreen,
        content: Text(n == 0
            ? '${year.label} publiée. Aucun chef d\'établissement enregistré '
                'à notifier.'
            : '${year.label} publiée — $n chef${n > 1 ? 's' : ''} '
                "d'établissement notifié${n > 1 ? 's' : ''}."),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(messageErreur(e, contexte: 'Publication'))));
    }
  }

  Future<void> _confirmerArchivage(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(adminCalendarServiceProvider);
    final verrouiller = !year.isLocked;
    final ok = await showAdminConfirm(
      context,
      danger: verrouiller,
      title: verrouiller
          ? 'Archiver ${year.label}'
          : 'Déverrouiller ${year.label}',
      icon: verrouiller ? Icons.archive_outlined : Icons.lock_open_rounded,
      confirmLabel: verrouiller ? 'Archiver' : 'Déverrouiller',
      confirmIcon: verrouiller ? Icons.archive_rounded : Icons.lock_open_rounded,
      message: verrouiller
          ? "L'année ${year.label} sera gelée : son calendrier — trimestres et "
              'séquences — ne pourra plus être modifié, et elle ne pourra plus '
              'devenir année courante.\n\n'
              'Ses données (${year.eleves} élèves, ${year.classes} classes) '
              'restent consultables et exportables. L\'archivage est '
              'réversible.'
          : "L'année ${year.label} redeviendra modifiable. À n'utiliser que "
              'pour corriger une erreur : les bulletins déjà édités sur cette '
              'année ne seront pas régénérés automatiquement.',
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => svc.setLocked(year.id, verrouiller),
        verrouiller ? 'Année archivée' : 'Année déverrouillée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = _status(year);
    final pct = year.schoolsTotal == 0
        ? 0.0
        : year.schoolsAdopted / year.schoolsTotal;

    return AdminCard(
      accent: year.isCurrent ? kGreen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(st.icon, size: 18, color: st.color),
              const SizedBox(width: 8),
              Text(year.label,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(width: 10),
              AdminBadge(st.label, color: st.color),
              // Un brouillon ne ressemble à rien de particulier une fois créé :
              // sans marque explicite, l'agent le croit diffusé et s'étonne que
              // les écoles ne le voient pas.
              if (year.isDraft) ...[
                const SizedBox(width: 6),
                AdminBadge('Brouillon — non diffusée', color: kAccent),
              ],
              const Spacer(),
              Text('${_fmtShort.format(year.startDate)} → '
                  '${_fmtShort.format(year.endDate)}',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(
                  icon: Icons.class_rounded,
                  value: '${year.classes}',
                  label: 'classes'),
              const SizedBox(width: 22),
              _Metric(
                  icon: Icons.people_rounded,
                  value: '${year.eleves}',
                  label: 'élèves'),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_rounded,
                            size: 14, color: kTextMuted),
                        const SizedBox(width: 6),
                        Text(
                          '${year.schoolsAdopted}/${year.schoolsTotal} '
                          'écoles préparées',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kTextMuted),
                        ),
                        const Spacer(),
                        Text('${(pct * 100).round()} %',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: pct >= 1 ? kGreen : kNavy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AdminProgressBar(
                        value: year.schoolsAdopted,
                        max: year.schoolsTotal == 0 ? 1 : year.schoolsTotal,
                        color: pct >= 1 ? kGreen : kNavy),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 8),
          Row(
            children: [
              // Le calendrier d'une année archivée reste CONSULTABLE, mais le
              // dialogue s'ouvre en lecture seule : l'ancienne version laissait
              // ce bouton actif et permettait d'y créer des trimestres — le
              // verrou n'était qu'un décor.
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdminYearCalendarDialog(year: year),
                ),
                icon: Icon(
                    year.isLocked
                        ? Icons.event_available_rounded
                        : Icons.event_note_rounded,
                    size: 17),
                label: Text(year.isLocked ? 'Calendrier (lecture)' : 'Calendrier'),
                style: TextButton.styleFrom(foregroundColor: kNavy),
              ),
              const SizedBox(width: 4),
              if (!year.isLocked)
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _YearDialog(existing: year),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: kNavy),
                ),
              const SizedBox(width: 4),
              // Publier passe AVANT « définir courante » : la base refuse de
              // rendre courante une année que les écoles ne reçoivent pas, et
              // proposer les deux à la fois inviterait à se heurter au refus.
              if (year.isDraft && !year.isLocked)
                FilledButton.icon(
                  onPressed: () => _confirmerPublication(context, ref),
                  icon: const Icon(Icons.campaign_rounded, size: 17),
                  label: const Text('Publier aux écoles'),
                  style: FilledButton.styleFrom(backgroundColor: kAccent),
                )
              else if (!year.isCurrent && !year.isLocked)
                TextButton.icon(
                  onPressed: () => _confirmerCourante(context, ref),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                  label: const Text('Définir courante'),
                  style: TextButton.styleFrom(foregroundColor: kGreen),
                ),
              const Spacer(),
              // L'année en cours ne s'archive pas : le refus vient aussi de la
              // base, mais autant ne pas proposer un geste voué à échouer.
              if (!year.isCurrent)
                TextButton.icon(
                  onPressed: () => _confirmerArchivage(context, ref),
                  icon: Icon(
                      year.isLocked
                          ? Icons.lock_open_rounded
                          : Icons.archive_outlined,
                      size: 17),
                  label: Text(year.isLocked ? 'Déverrouiller' : 'Archiver'),
                  style: TextButton.styleFrom(
                      foregroundColor: year.isLocked ? kAccent : kTextMuted),
                )
              else
                Tooltip(
                  message: "L'année en cours ne peut pas être archivée.\n"
                      "Basculez d'abord la rentrée sur une autre année.",
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 15, color: kTextMuted),
                      const SizedBox(width: 6),
                      Text('Année en cours',
                          style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kNavy),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      );
}
