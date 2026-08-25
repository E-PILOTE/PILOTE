import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_referential_provider.dart';
import '../widgets/exam_referential_views.dart';
import 'exam_rules_panel.dart';
import 'national_exam_form_dialog.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉFÉRENTIEL DES EXAMENS — administration super_admin.
//
//  ── LE TROU QUE CET ÉCRAN COMBLE ───────────────────────────────────────────
//  Deux, en réalité :
//   1. Les 12 examens venaient d'une MIGRATION. On pouvait en AJOUTER un (via
//      le « + » caché dans le formulaire de session) mais jamais en CORRIGER
//      un : une faute de frappe dans l'intitulé du BET vivait en base pour
//      toujours, et un diplôme supprimé par une réforme restait diffusé.
//   2. Surtout : créer un examen ne le branche à RIEN. C'est la règle
//      d'éligibilité qui décide quelle classe le prépare, et aucun écran ne
//      permettait d'en écrire une. Un nouveau diplôme METP serait donc apparu
//      dans la liste sans qu'une seule classe du pays s'y rattache.
//
//  ── L'ALERTE QUE PORTE CET ÉCRAN ───────────────────────────────────────────
//  « Examens inertes » : un diplôme actif sans aucune règle. Il existe, il
//  peut avoir une session ouverte, et pourtant personne ne peut s'y inscrire.
//  C'est la panne la plus silencieuse du module — elle mérite un KPI, pas une
//  ligne de log.
// ════════════════════════════════════════════════════════════════════════════
class ExamReferentialScreen extends ConsumerWidget {
  const ExamReferentialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: 'Référentiel des examens', child: _Body());
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String _tutelle = 'toutes';
  String _kind = 'tous';
  String _state = 'tous';
  bool _isTable = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NationalExamRow> _filter(List<NationalExamRow> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((r) {
      if (_tutelle != 'toutes' && r.tutelle != _tutelle) return false;
      if (_kind != 'tous' && r.kind != _kind) return false;
      switch (_state) {
        case 'actifs':
          if (!r.isActive) return false;
        case 'inactifs':
          if (r.isActive) return false;
        case 'inertes':
          if (!r.isInert) return false;
        case 'sans_session':
          if (!r.hasNoSession) return false;
      }
      if (q.isEmpty) return true;
      return r.code.toLowerCase().contains(q) ||
          r.name.toLowerCase().contains(q) ||
          r.shortName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(examReferentialProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 40),
          const SizedBox(height: 12),
          Text(messageErreur(e),
              textAlign: TextAlign.center, style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.invalidate(examReferentialProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (d) {
        final filtered = _filter(d.exams);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KpiGrid(items: _kpis(d)),
              const SizedBox(height: 20),
              if (d.inertExams.isNotEmpty) ...[
                _InertBanner(exams: d.inertExams, onOpen: _openRules),
                const SizedBox(height: 20),
              ],
              ListFilterBar(
                searchCtrl: _search,
                searchHint: 'Rechercher un examen, un code, un intitulé…',
                isTableView: _isTable,
                addLabel: 'Nouvel examen',
                addIcon: Icons.workspace_premium_rounded,
                onSearchChange: (_) => setState(() {}),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onAdd: _create,
                onReset: () => setState(() {
                  _search.clear();
                  _tutelle = 'toutes';
                  _kind = 'tous';
                  _state = 'tous';
                }),
                filters: [
                  ListFilterDropdown(
                    icon: Icons.account_balance_rounded,
                    label: 'Tutelle',
                    value: _tutelle,
                    items: const {
                      'toutes': 'Toutes',
                      'metp': 'METP',
                      'mepsa': 'MEPSA',
                    },
                    onChanged: (v) => setState(() => _tutelle = v),
                  ),
                  ListFilterDropdown(
                    icon: Icons.category_rounded,
                    label: 'Nature',
                    value: _kind,
                    items: const {
                      'tous': 'Toutes',
                      'diplome': 'Diplômes',
                      'concours': 'Concours',
                    },
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  ListFilterDropdown(
                    icon: Icons.rule_rounded,
                    label: 'État',
                    value: _state,
                    items: const {
                      'tous': 'Tous',
                      'actifs': 'Actifs',
                      'inactifs': 'Désactivés',
                      'inertes': 'Sans règle (inertes)',
                      'sans_session': 'Sans session',
                    },
                    onChanged: (v) => setState(() => _state = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListResultHeader(
                  total: d.exams.length,
                  filtered: filtered.length,
                  noun: 'examen'),
              const SizedBox(height: 12),
              if (_isTable)
                ExamReferentialTable(
                  rows: filtered,
                  onEdit: _edit,
                  onRules: _openRules,
                  onToggle: _toggle,
                  onDelete: _delete,
                )
              else
                ExamReferentialCards(
                  rows: filtered,
                  onEdit: _edit,
                  onRules: _openRules,
                  onToggle: _toggle,
                  onDelete: _delete,
                ),
            ],
          ),
        );
      },
    );
  }

  List<KpiData> _kpis(ExamReferentialData d) {
    final n = d.exams.length;
    final active = d.exams.where((e) => e.isActive).length;
    final diplomes = d.exams.where((e) => e.isDiplome).length;
    final rules = d.rules.values.fold<int>(0, (s, l) => s + l.length);
    final nationalRules = d.rules.values
        .fold<int>(0, (s, l) => s + l.where((r) => r.isNational).length);
    final inert = d.inertExams.length;
    final noSession = d.exams.where((e) => e.hasNoSession).length;
    final metp = d.exams.where((e) => e.tutelle == 'metp').length;

    return [
      KpiData(
        label: 'Examens au référentiel',
        value: '$n',
        sub: '$active actif(s) · ${n - active} désactivé(s)',
        icon: Icons.workspace_premium_rounded,
        color: kNavy,
        progressValue: n > 0 ? active / n : 0,
        trend: n > 0 ? '${(active * 100 / n).round()}% diffusés' : '—',
      ),
      // L'alerte de l'écran. Un diplôme sans règle ne qualifie aucune classe :
      // il est présent partout et utilisable nulle part.
      KpiData(
        label: 'Examens inertes',
        value: '$inert',
        sub: inert > 0
            ? 'aucune classe ne s\'y rattachera'
            : '✅ tous les diplômes sont branchés',
        icon: Icons.link_off_rounded,
        color: inert > 0 ? kRed : kGreen,
        progressValue: diplomes > 0 ? (diplomes - inert) / diplomes : 1,
        trend: inert > 0 ? '⚠ À régler' : '✅ OK',
        trendUp: inert == 0,
      ),
      KpiData(
        label: 'Règles d\'éligibilité',
        value: '$rules',
        sub: '$nationalRules nationale(s) · '
            '${rules - nationalRules} propre(s) à un groupe',
        icon: Icons.rule_rounded,
        color: kListPurple,
        progressValue: rules > 0 ? nationalRules / rules : 0,
        trend: rules > 0 ? 'paramétrage vivant' : 'aucune règle',
        trendUp: rules > 0,
      ),
      KpiData(
        label: 'Sans session ouverte',
        value: '$noSession',
        sub: noSession > 0
            ? 'aucun candidat possible cette année'
            : '✅ tous ont un calendrier',
        icon: Icons.event_busy_rounded,
        color: noSession > 0 ? kListOrange : kGreen,
        progressValue: active > 0 ? (active - noSession) / active : 1,
        trend: noSession > 0 ? 'à ouvrir' : '✅ OK',
        trendUp: noSession == 0,
      ),
      KpiData(
        label: 'Diplômes / Concours',
        value: '$diplomes',
        sub: 'diplômes · ${n - diplomes} concours',
        icon: Icons.category_rounded,
        color: kAccent,
        progressValue: n > 0 ? diplomes / n : 0,
        // Seul un DIPLÔME qualifie une classe entière ; un concours est un
        // choix de l'élève. La distinction n'est pas cosmétique.
        trend: 'seuls les diplômes se dérivent',
      ),
      KpiData(
        label: 'Répartition',
        value: '$metp',
        sub: 'METP · ${n - metp} MEPSA',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF0EA5E9),
        progressValue: n > 0 ? metp / n : 0,
        trend: n > 0 ? '${(metp * 100 / n).round()}% technique' : '—',
      ),
    ];
  }

  // ── Gestes ────────────────────────────────────────────────────────────────

  Future<void> _create() async {
    final created = await showNationalExamForm(context);
    if (created == null || !mounted) return;
    ref.invalidate(examReferentialProvider);
    // Un examen fraîchement créé est INERTE par construction. L'enchaînement
    // direct sur ses règles évite le piège : « je l'ai créé, il ne se passe
    // rien ». C'est la marche suivante, on la propose au lieu de l'attendre.
    final d = await ref.read(examReferentialProvider.future);
    final row = d.exams.where((e) => e.id == created).firstOrNull;
    if (row != null && row.needsRules && mounted) {
      await _openRules(row);
    }
  }

  Future<void> _edit(NationalExamRow row) async {
    final changed = await showNationalExamForm(context, existing: row);
    if (changed != null) ref.invalidate(examReferentialProvider);
  }

  Future<void> _openRules(NationalExamRow row) async {
    await showExamRulesPanel(context, exam: row);
    if (mounted) ref.invalidate(examReferentialProvider);
  }

  Future<void> _toggle(NationalExamRow row) async {
    final turningOff = row.isActive;
    if (turningOff) {
      final ok = await showAdminConfirm(
        context,
        title: 'Désactiver ${row.shortName} ?',
        message:
            'L\'examen cessera d\'être diffusé aux écoles à la prochaine '
            'synchronisation. Ses sessions et ses résultats déjà proclamés '
            'sont conservés — rien n\'est détruit.',
        confirmLabel: 'Désactiver',
        danger: true,
      );
      if (!ok) return;
    }
    try {
      await setNationalExamActive(ref.read(supabaseClientProvider), row.id,
          active: !row.isActive);
      ref.invalidate(examReferentialProvider);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _delete(NationalExamRow row) async {
    final ok = await showAdminConfirm(
      context,
      title: 'Supprimer ${row.shortName} ?',
      message: row.ruleCount == 0
          ? 'Suppression définitive du référentiel national.'
          : '${row.ruleCount} règle(s) d\'éligibilité seront supprimées avec '
              'lui. Les classes concernées repasseront « à qualifier ».',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await deleteNationalExam(client, row.id);
      // Une règle disparue ne se recalcule pas toute seule : le trigger ne
      // s'arme qu'à l'écriture d'une classe.
      final n = await recomputeClassExams(client);
      ref.invalidate(examReferentialProvider);
      _toast(n == 0
          ? 'Examen supprimé. Aucune classe n\'était concernée.'
          : 'Examen supprimé · $n classe(s) requalifiée(s).');
    } catch (e) {
      _toast('$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Bandeau d'alerte : les diplômes que rien ne branche. Placé AVANT les
/// filtres — c'est la seule information de l'écran qui appelle une action
/// immédiate, elle ne doit pas se mériter.
class _InertBanner extends StatelessWidget {
  const _InertBanner({required this.exams, required this.onOpen});

  final List<NationalExamRow> exams;
  final ValueChanged<NationalExamRow> onOpen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.28)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.link_off_rounded, size: 19, color: kRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exams.length == 1
                      ? 'Un diplôme actif n\'a aucune règle d\'éligibilité'
                      : '${exams.length} diplômes actifs n\'ont aucune règle '
                          'd\'éligibilité',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sans règle, aucune classe ne s\'y rattache : les écoles '
                  'verront « à qualifier » et ne pourront inscrire personne.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in exams)
                      OutlinedButton.icon(
                        onPressed: () => onOpen(e),
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: Text('Règles de ${e.shortName}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRed,
                          side: BorderSide(color: kRed.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      );
}
