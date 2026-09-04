part of 'edt_settings_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ONGLET CALENDRIER SCOLAIRE — jours NON OUVRÉS de l'année (vacances + fériés).
//  Socle des futures vues calendaires (mois/trimestre/annuel) de l'EDT : la
//  trame hebdomadaire ne sera projetée QUE sur les jours ouvrés.
//
//  Les fériés LÉGAUX descendent du groupe (`school_id IS NULL`) et sont ici en
//  lecture seule ; l'école ne saisit que ses propres fermetures. Le bouton
//  « Fériés du Congo » qui recalculait la liste sur le poste a été retiré :
//  la règle vit désormais uniquement en base. Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();

  void _openForm(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _HolidayForm(),
      );

  Future<void> _delete(BuildContext context, SchoolHoliday h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer ce jour non ouvré ?'),
        content: Text('« ${h.label} » (${h.rangeLabel})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(context, () => deleteHoliday(h.id),
        success: 'Jour retiré');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolHolidaysProvider);
    final year = ref.watch(activeYearProvider);
    // ⚠️ UNE ANNÉE ARCHIVÉE NE SE MODIFIE PLUS, ET LE DIRE ICI ÉVITE UN LOT
    // PERDU. Le déclencheur `fn_guard_locked_year` refuse toute écriture sur le
    // calendrier d'une année verrouillée — en 42501, code FATAL pour le
    // connecteur PowerSync, qui jette le LOT ENTIER d'écritures en attente.
    // Cet onglet lisait bien les verbes du module, mais pas l'état de l'année :
    // il était le seul écran d'écriture du produit à ne pas consulter
    // `yearReadOnlyProvider`.
    final readOnly = ref.watch(yearReadOnlyProvider);
    final canCreate =
        ref.watch(canProvider((slug: _kSlug, action: 'create'))) && !readOnly;
    final canDelete =
        ref.watch(canProvider((slug: _kSlug, action: 'delete'))) && !readOnly;

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (items) {
        final feries = [for (final h in items) if (h.isFerie) h];
        final vacances = [for (final h in items) if (!h.isFerie) h];
        final nationaux = [for (final h in items) if (h.isNational) h];
        final offDays = items.fold<int>(0, (s, h) => s + h.dayCount);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                year == null
                    ? 'Aucune année active.'
                    : 'Année ${year.label} — jours fériés et vacances scolaires. '
                        'Les cours ne seront pas projetés sur ces jours.',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 14),
            if (year != null) _NationalNote(count: nationaux.length),
            if (canCreate) ...[
              const SizedBox(height: 12),
              AdminPrimaryButton(
                label: 'Ajouter une fermeture',
                icon: Icons.add_rounded,
                color: kNavy,
                onTap: () => _openForm(context),
              ),
            ],
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: AdminEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Calendrier vide',
                  message:
                      'Les fériés légaux sont installés par le groupe. Ajoutez '
                      'ici les vacances propres à votre établissement.',
                ),
              )
            else ...[
              _CalSummary(
                feries: feries.length,
                vacances: vacances.length,
                offDays: offDays,
              ),
              const SizedBox(height: 16),
              if (vacances.isNotEmpty) ...[
                const _CalGroupTitle(
                    icon: Icons.beach_access_outlined,
                    label: 'Vacances scolaires'),
                for (final h in vacances)
                  _HolidayRow(
                      holiday: h,
                      canDelete: canDelete,
                      onDelete: () => _delete(context, h)),
                const SizedBox(height: 12),
              ],
              if (feries.isNotEmpty) ...[
                const _CalGroupTitle(
                    icon: Icons.flag_outlined, label: 'Jours fériés'),
                for (final h in feries)
                  _HolidayRow(
                      holiday: h,
                      canDelete: canDelete,
                      onDelete: () => _delete(context, h)),
              ],
            ],
          ],
        );
      },
    );
  }
}

// ─── D'où viennent les fériés ────────────────────────────────────────────────
//  Sans cette ligne, une école qui ne voit aucun férié n'a aucun moyen de
//  savoir s'il faut les saisir à la main ou attendre le groupe. Le message
//  distingue les deux cas au lieu de laisser deviner.
class _NationalNote extends StatelessWidget {
  const _NationalNote({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final ok = count > 0;
    final c = ok ? kNavy : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.verified_outlined : Icons.info_outline_rounded,
            size: 16, color: c),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            ok
                ? '$count jour${count > 1 ? 's' : ''} férié'
                    '${count > 1 ? 's' : ''} légal${count > 1 ? 'aux' : ''} '
                    'reçu${count > 1 ? 's' : ''} du groupe. '
                    'Ils ne se modifient pas ici.'
                : 'Aucun férié légal reçu pour cette année : le groupe ne les a '
                    'pas encore installés. Signalez-le plutôt que de les saisir '
                    'à la main — ils arriveront en double.',
            style: TextStyle(fontSize: 11.5, height: 1.35, color: kTextMuted),
          ),
        ),
      ]),
    );
  }
}

class _CalSummary extends StatelessWidget {
  const _CalSummary(
      {required this.feries, required this.vacances, required this.offDays});
  final int feries, vacances, offDays;
  @override
  Widget build(BuildContext context) {
    Widget chip(IconData ic, String v, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.withValues(alpha: 0.22)),
            ),
            child: Column(children: [
              Icon(ic, size: 17, color: c),
              const SizedBox(height: 6),
              Text(v,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: c)),
              Text(l,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ]),
          ),
        );
    return Row(children: [
      chip(Icons.flag_outlined, '$feries', 'Fériés', const Color(0xFF8B5CF6)),
      const SizedBox(width: 10),
      chip(Icons.beach_access_outlined, '$vacances', 'Périodes\nde vacances',
          const Color(0xFF0EA5E9)),
      const SizedBox(width: 10),
      chip(Icons.event_busy_outlined, '$offDays', 'Jours non\nouvrés', kRed),
    ]);
  }
}

class _CalGroupTitle extends StatelessWidget {
  const _CalGroupTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(children: [
          Icon(icon, size: 15, color: kTextMuted),
          const SizedBox(width: 7),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: kTextMuted)),
        ]),
      );
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow(
      {required this.holiday, required this.canDelete, required this.onDelete});
  final SchoolHoliday holiday;
  final bool canDelete;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final c = holiday.isFerie ? const Color(0xFF8B5CF6) : const Color(0xFF0EA5E9);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(width: 4, height: 34, decoration: BoxDecoration(
            color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(holiday.label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                Text(
                    holiday.isSingleDay
                        ? holiday.rangeLabel
                        : '${holiday.rangeLabel} · ${holiday.dayCount} jours',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
        ),
        // Une ligne nationale (`school_id IS NULL`) est en LECTURE SEULE ici :
        // la politique `school_holidays_tenant` exige `school_id =
        // auth_school_id()` en écriture. Offrir la croix faisait réussir la
        // suppression en local, échouer la remontée, et revenir la ligne à la
        // synchro suivante — « je l'ai supprimé et il est revenu ».
        if (holiday.isNational)
          Tooltip(
            message: 'Férié légal fixé par le groupe',
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.lock_outline_rounded,
                  size: 15, color: kTextMuted),
            ),
          )
        else if (canDelete)
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
            ),
          ),
      ]),
    );
  }
}

