import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../../data/models/academic_year_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/academic_year_context.dart';
import '../providers/academic_year_provider.dart';
import '../providers/school_holidays_provider.dart';
import 'edt_settings_screen.dart' show openEdtSettingsDrawer, kEdtSegCalendar;
import '../../../core/utils/message_erreur.dart';
import '../../../core/constants/app_constants.dart';

part 'calendar_detail.dart';
part 'calendar_holidays.dart';
part 'calendar_rollover.dart';

final _fmtDate = DateFormat('dd MMM yyyy', 'fr_FR');

/// Rôles autorisés à VOIR le calendrier (config direction/secrétariat).
///
/// ⚠️ C'était une COPIE littérale de `AppConstants.directionRoles`, dont le
/// commentaire dit pourtant « ne jamais dupliquer la liste ». Les deux ont
/// divergé le jour où l'une a perdu `directeur_etudes` — valeur que l'enum
/// `user_role` ne contient pas. On lit désormais la source.
const _kViewRoles = AppConstants.directionRoles;
/// Rôles autorisés à ÉDITER (chefs d'établissement uniquement).
const _kEditRoles = {'proviseur', 'directeur'};

/// Année INSPECTÉE dans la colonne de gauche.
///
/// À NE PAS CONFONDRE avec [selectedYearIdProvider], la lentille globale qui
/// scope toute l'application. Ici on feuillette l'historique sans rien changer
/// à ce que le reste du logiciel affiche ; le passage de l'un à l'autre est un
/// geste explicite (bouton « Afficher dans l'app »). Sans cette séparation,
/// consulter l'an dernier basculerait la caisse et les notes en lecture seule
/// dans le dos de l'utilisateur.
final _selectedYearProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Calendrier scolaire — config NATIVE réservée à la direction (hors catalogue).
/// Années → Trimestres → Séquences. Offline-first, une seule courante par niveau.
class SchoolCalendarScreen extends ConsumerWidget {
  const SchoolCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authNotifierProvider).valueOrNull?.role ?? '';
    return AppShell(
      title: 'Calendrier scolaire',
      child: _kViewRoles.contains(role)
          ? _Body(canEdit: _kEditRoles.contains(role))
          : const _Denied(),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: kTextMuted),
            const SizedBox(height: 16),
            Text('Réservé à la direction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(height: 8),
            Text('La gestion du calendrier scolaire est réservée au chef d\'établissement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextMuted)),
          ]),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = ref.watch(academicYearsProvider);
    return yearsAsync.when(
      loading: () => const SplitSkeleton(),
      error: (e, _) => Center(child: Text(messageErreur(e), style: TextStyle(color: kRed))),
      data: (years) {
        final selected = ref.watch(_selectedYearProvider);
        // Défaut = l'année que l'application AFFICHE, pas l'année courante de
        // l'établissement. Quelqu'un qui consulte 2024-2025 depuis le header et
        // ouvre ce calendrier vient regarder 2024-2025 ; le poser sur l'année
        // en cours l'obligerait à re-cliquer et lui ferait croire que sa
        // bascule n'a pas pris.
        final lensId = ref.watch(activeYearIdProvider);
        final known = {for (final y in years) y.id};
        final effId = [
          selected,
          lensId,
          for (final y in years)
            if (y.isCurrent) y.id,
          years.isEmpty ? null : years.first.id,
        ].firstWhere((id) => id != null && known.contains(id),
            orElse: () => null);
        final matches = years.where((y) => y.id == effId);
        final selectedYear = matches.isEmpty ? null : matches.first;

        return Row(children: [
          SizedBox(
            width: 340,
            child: _YearsColumn(years: years, selectedId: effId, canEdit: canEdit),
          ),
          Container(width: 1, color: kBorder),
          Expanded(
            child: selectedYear == null
                ? const _EmptyDetail()
                : _YearDetail(year: selectedYear),
          ),
        ]);
      },
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_rounded, size: 56, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucune année scolaire',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kNavy)),
          const SizedBox(height: 4),
          Text('Les années sont définies par le groupe et héritées par votre '
              'école. Aucune n\'est encore disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextMuted)),
        ]),
      );
}

// ─── Colonne des années ───────────────────────────────────────────────────────
class _YearsColumn extends ConsumerWidget {
  const _YearsColumn({required this.years, required this.selectedId, required this.canEdit});
  final List<AcademicYearModel> years;
  final String? selectedId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Années scolaires',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
              const SizedBox(height: 2),
              Text(
                years.isEmpty
                    ? 'Aucune année reçue'
                    : '${years.length} année${years.length > 1 ? 's' : ''} '
                        'héritée${years.length > 1 ? 's' : ''} du groupe',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ]),
          ),
          Tooltip(
            message: 'Les années, trimestres et séquences sont définis par le '
                'groupe puis hérités par votre école.\n'
                'Votre école y ajoute ses classes et ses jours non ouvrés.',
            child: Icon(Icons.cloud_done_outlined, size: 17, color: kTextMuted),
          ),
        ]),
      ),
      Divider(height: 1, color: kBorder),
      Expanded(
        child: years.isEmpty
            ? Center(child: Text('—', style: TextStyle(color: kTextMuted)))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: years.length,
                itemBuilder: (_, i) => _YearTile(
                  year: years[i],
                  years: years,
                  selected: years[i].id == selectedId,
                  canEdit: canEdit,
                ),
              ),
      ),
    ]);
  }
}

class _YearTile extends ConsumerWidget {
  const _YearTile({
    required this.year,
    required this.years,
    required this.selected,
    required this.canEdit,
  });
  final AcademicYearModel year;
  final List<AcademicYearModel> years;
  final bool selected, canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(yearContentCountProvider(year.id)).valueOrNull;
    // Cette année est-elle celle que l'application entière affiche ?
    // L'information manquait totalement : on pouvait inspecter 2024-2025 en
    // croyant que le reste du logiciel avait suivi, ou l'inverse.
    final isLens = ref.watch(activeYearIdProvider) == year.id;
    final empty = counts != null && counts.classes == 0;

    return InkWell(
      onTap: () => ref.read(_selectedYearProvider.notifier).state = year.id,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.06) : kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kNavy : kBorder, width: selected ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(year.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNavy)),
            ),
            if (year.isCurrent) _Tag(text: 'Courante', color: kGreen),
            if (year.isLocked) ...[const SizedBox(width: 4), _Tag(text: 'Archivée', color: kAccent)],
          ]),
          const SizedBox(height: 4),
          Text('${_fmtDate.format(year.startDate)} → ${_fmtDate.format(year.endDate)}',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
          if (isLens) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.remove_red_eye_rounded, size: 12, color: kNavy),
              const SizedBox(width: 5),
              Text("Affichée dans l'application",
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
            ]),
          ],
          const SizedBox(height: 6),
          // Contenu de l'année
          Row(children: [
            _CountChip(icon: Icons.class_rounded, value: counts?.classes, label: 'classes'),
            const SizedBox(width: 8),
            _CountChip(icon: Icons.people_rounded, value: counts?.eleves, label: 'élèves'),
          ]),
          // Une année sans classe n'est pas « adoptée » : rien de l'école n'y
          // existe encore. On le dit, plutôt que d'afficher deux zéros muets.
          if (empty) ...[
            const SizedBox(height: 6),
            Text(
              canEdit && !year.isLocked
                  ? 'Année non préparée — recopiez vos classes pour l\'ouvrir.'
                  : 'Année non préparée par votre école.',
              style: TextStyle(
                  fontSize: 10.5,
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  height: 1.3),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (isLens)
              // Déjà la lentille : le bouton n'a plus rien à faire, il devient
              // un état. Un « Consulter » qui ne consulte rien est un piège.
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, size: 13, color: kGreen),
                const SizedBox(width: 4),
                Text('Année affichée',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGreen)),
              ])
            else
              _MiniBtn(
                label: "Afficher dans l'app",
                icon: Icons.visibility_outlined,
                color: kGreen,
                onTap: () {
                  ref.read(selectedYearIdProvider.notifier).select(year.id);
                  context.go(Routes.userDashboard);
                },
              ),
            const Spacer(),
            if (canEdit && !year.isLocked)
              _MiniBtn(
                label: empty ? 'Préparer' : 'Préparer mes classes',
                icon: Icons.move_up_rounded,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _PrepClassesDialog(targetYear: year, years: years),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Petite puce « N classes / N élèves » (contenu d'une année).
class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.value, required this.label});
  final IconData icon;
  final int? value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: kTextMuted),
          const SizedBox(width: 4),
          Text('${value ?? '…'} $label',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextMuted)),
        ]),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}

class _MiniBtn extends StatelessWidget {
  _MiniBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    Color? color,
  }) : color = color ?? kNavy;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}
