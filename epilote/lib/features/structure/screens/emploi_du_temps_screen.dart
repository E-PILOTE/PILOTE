import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/class_context_banner.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/academic_year_model.dart';
import '../../../data/models/class_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../staff/providers/staff_directory_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/academic_year_context.dart';
import '../providers/academic_year_provider.dart';
import '../providers/rooms_provider.dart';
import '../providers/school_holidays_provider.dart';
import '../providers/school_periods_provider.dart';
import '../providers/teacher_availability_provider.dart';
import '../providers/timetable_exceptions_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/emploi_du_temps_pdf_service.dart';
import 'edt_settings_screen.dart';
import 'emploi_du_temps_history.dart';

part 'emploi_du_temps_grid.dart';
part 'emploi_du_temps_form.dart';
part 'emploi_du_temps_widgets.dart';
part 'emploi_du_temps_panels.dart';
part 'emploi_du_temps_body.dart';
part 'emploi_du_temps_overview.dart';
part 'emploi_du_temps_spanbar.dart';
part 'emploi_du_temps_calendar.dart';
part 'emploi_du_temps_projection.dart';
part 'emploi_du_temps_minimonth.dart';
part 'emploi_du_temps_daydetail.dart';
part 'emploi_du_temps_extraform.dart';
part 'emploi_du_temps_schedule_drawer.dart';
part 'emploi_du_temps_actions.dart';

const _kSlug = 'emploi-du-temps';

/// Axe d'affichage de la page (commutateur, plus d'onglets).
enum TtView { ensemble, classe, enseignant, salle }

/// Empan temporel de l'affichage. Jour/Semaine = la TRAME hebdomadaire récurrente
/// (grille). Mois/Trimestre/Semestre/Année = PROJECTION de cette trame sur le
/// calendrier réel (dates), en excluant les jours non ouvrés (`school_holidays`).
enum TtSpan {
  jour,
  semaine,
  mois,
  trimestre,
  semestre,
  annuel;

  /// Vue calendaire projetée (par opposition à la grille de trame hebdo).
  bool get isCalendar =>
      this == mois || this == trimestre || this == semestre || this == annuel;
}

// Palette stable par matière / classe (couleur déterministe depuis l'id).
const _slotPalette = <Color>[
  Color(0xFF0EA5E9), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFF8B5CF6),
  Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFEF4444), Color(0xFF6366F1),
  Color(0xFF84CC16), Color(0xFFF97316),
];
Color _subjectColor(String id) =>
    _slotPalette[id.hashCode.abs() % _slotPalette.length];

// ════════════════════════════════════════════════════════════════════════════
//  MODULE EMPLOI DU TEMPS — UNE SEULE PAGE (design plateforme, sans onglets) :
//   hero KPI → couverture (cycle▸niveau▸classe) → barre de filtres (recherche +
//   commutateur de vue + boutons) → calendrier de l'établissement OU grille de
//   l'entité choisie. Édition par MODAL (créneau) ; détail par TIROIR ;
//   paramètres (salles, trame) en TIROIR latéral. Offline-first. Détection de
//   conflits prof/salle/classe. Export PDF.
// ════════════════════════════════════════════════════════════════════════════
class EmploiDuTempsScreen extends ConsumerWidget {
  const EmploiDuTempsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Emploi du temps',
        child: _EdtPage(),
      );
}

class _EdtPage extends ConsumerStatefulWidget {
  const _EdtPage();
  @override
  ConsumerState<_EdtPage> createState() => _EdtPageState();
}

class _EdtPageState extends ConsumerState<_EdtPage> {
  final _searchCtrl = TextEditingController();
  TtView _view = TtView.ensemble;
  TtSpan _span = TtSpan.semaine;
  // Jour mis au point en empan « Jour » (1=lun … 6=sam). Défaut = aujourd'hui
  // s'il tombe en semaine de cours, sinon lundi.
  int _focusedDay = (DateTime.now().weekday >= 1 && DateTime.now().weekday <= 6)
      ? DateTime.now().weekday
      : 1;
  // Empan « Mois » : 1er jour du mois affiché (borné à l'année active en build).
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _trimesterIndex = -1; // -1 = pas encore résolu (→ trimestre courant)
  int _semester = 1; // 1 ou 2
  ScopeSel _scope = const ScopeSel();
  String? _teacherId;
  String? _room;
  bool _autoPickedClass = false;

  /// Jours affichés selon l'empan courant (grille de trame uniquement).
  List<int> get _visibleDays =>
      _span == TtSpan.jour ? [_focusedDay] : const [1, 2, 3, 4, 5, 6];

  /// Passe-plat de `setState` pour les extensions de cet état (parts) — évite le
  /// lint `invalid_use_of_protected_member` hors de la classe.
  void mutate(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Navigation interne ─────────────────────────────────────────────────────
  void _setView(TtView v) => setState(() {
        _view = v;
        if (v != TtView.classe) _autoPickedClass = true; // pas d'auto-pick ailleurs
      });

  void _onScope(ScopeSel s) => setState(() {
        _scope = s;
        // Cliquer une CLASSE depuis la couverture → basculer sur sa grille.
        if (s.classId != null && _view == TtView.ensemble) _view = TtView.classe;
      });

  void _jumpToClass(TimetableSlot s) {
    if (s.classId.isEmpty) return;
    setState(() {
      _view = TtView.classe;
      _autoPickedClass = true;
      _scope = ScopeSel(
          cycle: s.cycleCode,
          classId: s.classId,
          label: 'Classe : ${s.className ?? ''}');
    });
  }

  // ── Recherche ──────────────────────────────────────────────────────────────
  bool _match(TimetableSlot s) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (s.subjectName ?? '').toLowerCase().contains(q) ||
        (s.teacherName ?? '').toLowerCase().contains(q) ||
        (s.className ?? '').toLowerCase().contains(q) ||
        (s.room ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final slotsAsync = ref.watch(timetableSlotsProvider);
    final periods = ref.watch(schoolPeriodsProvider).valueOrNull ?? const [];
    final rooms = ref.watch(roomsProvider).valueOrNull ?? const [];
    final version = ref.watch(activeTimetableVersionProvider).valueOrNull;
    final requiredByClass =
        ref.watch(classRequiredHoursProvider).valueOrNull ?? const {};
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);
    // Calendrier scolaire (projection des vues mois/trimestre/semestre/année).
    final year = ref.watch(activeYearProvider);
    final yearId = ref.watch(activeYearIdProvider);
    final trims = (yearId != null
            ? ref.watch(trimestersProvider(yearId)).valueOrNull
            : null) ??
        const [];
    final holidays = ref.watch(schoolHolidaysProvider).valueOrNull ?? const [];
    final exceptions =
        ref.watch(timetableExceptionsProvider).valueOrNull ?? const [];

    return classesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (classes) {
        final sorted = [...classes]..sort((a, b) {
            final c = (a.levelOrder ?? 999).compareTo(b.levelOrder ?? 999);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
        final classById = {for (final c in sorted) c.id: c};
        final all = slotsAsync.valueOrNull ?? const <TimetableSlot>[];
        final conflictIds = conflictingSlotIds(detectConflicts(all));
        final coveredIds = all.map((s) => s.classId).toSet();

        // Conformité au programme : heures placées (durée des créneaux) vs
        // heures requises (somme class_subjects.weekly_hours). Conforme = placé ≥ requis.
        final placedHoursByClass = <String, double>{};
        for (final s in all) {
          placedHoursByClass[s.classId] =
              (placedHoursByClass[s.classId] ?? 0) + s.durationMinutes / 60;
        }
        final conformeIds = <String>{
          for (final c in sorted)
            if ((requiredByClass[c.id] ?? 0) > 0 &&
                (placedHoursByClass[c.id] ?? 0) >=
                    (requiredByClass[c.id] ?? 0) - 0.01)
              c.id
        };

        // Auto-sélection de la 1re classe en vue « Classe ».
        if (_view == TtView.classe &&
            _scope.classId == null &&
            !_autoPickedClass &&
            sorted.isNotEmpty) {
          _autoPickedClass = true;
          final fst = sorted.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _scope = ScopeSel(
                  cycle: fst.cycleCode,
                  level: fst.levelCode,
                  classId: fst.id,
                  label: 'Classe : ${fst.name}'));
            }
          });
        }

        final (shown, title) = _resolve(all, classById);
        // Empan calendaire : index de trimestre effectif (courant par défaut) +
        // période [from, to] à projeter.
        final trimIdx = _trimesterIndex >= 0
            ? _trimesterIndex
            : (() {
                final i = trims.indexWhere((t) => t.isCurrent);
                return i < 0 ? 0 : i;
              })();
        final range = edtSpanRange(
          span: _span,
          year: year,
          trims: trims,
          focusedMonth: _focusedMonth,
          trimesterIndex: trimIdx,
          semester: _semester,
        );
        // Capacités d'édition par action (séparées : create / update / delete).
        final classeView = _view == TtView.classe;
        final canAdd =
            canCreate && !readOnly && classeView && _scope.classId != null;
        final canEditSlot = canUpdate && !readOnly && classeView;
        final canDelSlot = canDelete && !readOnly && classeView;
        final showAdd = canAdd;

        // Métriques globales (hero).
        final conflicts = all.where((s) => conflictIds.contains(s.id)).length;
        final teachers =
            all.where((s) => s.staffId.isNotEmpty).map((s) => s.staffId).toSet().length;
        final roomsUsed = rooms.isNotEmpty
            ? rooms.length
            : all
                .where((s) => (s.room ?? '').trim().isNotEmpty)
                .map((s) => s.room!.trim())
                .toSet()
                .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _EdtKpiSection(
              version: version,
              conflicts: conflicts,
              covered: coveredIds.length,
              totalClasses: sorted.length,
              slots: all.length,
              teachers: teachers,
              rooms: roomsUsed,
            ),
            if (version != null || all.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PublicationBar(
                version: version,
                conflicts: conflicts,
                canManage: canUpdate && !readOnly,
                onPublish: () => version != null
                    ? _publish(version.id, conflicts)
                    : null,
                onUnpublish: () =>
                    version != null ? _unpublish(version.id) : null,
              ),
            ],
            const SizedBox(height: 26),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Aucune classe',
                  message:
                      'Créez des classes (page Classes) pour bâtir leurs emplois du temps.',
                ),
              )
            else ...[
              _selector(sorted, all, conformeIds),
              const SizedBox(height: 22),
              _EdtFilterBar(
                searchCtrl: _searchCtrl,
                view: _view,
                readOnly: readOnly,
                showAdd: showAdd,
                onSearch: (_) => setState(() {}),
                onView: _setView,
                onHistory: () => openEdtHistoryDrawer(context),
                onSettings: () => openEdtSettingsDrawer(context),
                onExport: () => _view == TtView.ensemble
                    ? _exportBooklet(sorted, all)
                    : _exportPdf(shown),
                onAdd: () => _openSlotForm(),
              ),
              const SizedBox(height: 12),
              _SpanBar(
                span: _span,
                focusedDay: _focusedDay,
                monthLabel: range.label,
                onPrevMonth: () => _stepMonth(-1, year),
                onNextMonth: () => _stepMonth(1, year),
                trimesterLabels: [
                  for (var i = 0; i < (trims.isEmpty ? 3 : trims.length); i++)
                    trims.isEmpty ? 'T${i + 1}' : trims[i].label,
                ],
                trimesterIndex: trimIdx,
                semester: _semester,
                onSpan: (s) => setState(() => _span = s),
                onDay: (d) => setState(() {
                  _focusedDay = d;
                  _span = TtSpan.jour;
                }),
                onTrimester: (i) => setState(() => _trimesterIndex = i),
                onSemester: (s) => setState(() => _semester = s),
              ),
              if (_scope.active &&
                  (_view == TtView.ensemble || _view == TtView.classe)) ...[
                const SizedBox(height: 12),
                _ScopeChip(
                  label: _scope.label,
                  onClear: () => setState(() {
                    _scope = const ScopeSel();
                    if (_view == TtView.classe) _autoPickedClass = false;
                  }),
                ),
              ],
              const SizedBox(height: 16),
              _content(all, shown, title, conflictIds, periods, classById,
                  requiredByClass, holidays, exceptions, range, canAdd,
                  canEditSlot, canDelSlot),
            ],
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }

}
