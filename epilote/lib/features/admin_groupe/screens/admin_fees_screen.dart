import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_fees_provider.dart';
import 'admin_fee_form_dialog.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS & TARIFS — le seul endroit de la plateforme où un montant se crée.
//
//  ── LE TROU QUE CET ÉCRAN COMBLE ───────────────────────────────────────────
//  Jusqu'au 5 août 2026, chaque école définissait ses propres barèmes depuis
//  son espace. Conséquence : aucun tarif de référence n'existait, donc la
//  surfacturation était indétectable, et « combien coûte l'inscription en 6e »
//  avait mille réponses. Les frais d'examen étaient même modifiables par
//  l'établissement alors que la DEC les fixe nationalement.
//
//  ── GOUVERNANCE ────────────────────────────────────────────────────────────
//  Un barème est un ACTE DU GROUPE : arrêté dans le public, décision du siège
//  dans le privé. L'école reçoit et applique. `school_id` dit « s'applique à »,
//  jamais « créé par » — la RLS (migration 0096) impose l'auteur.
//
//  ── FORME ──────────────────────────────────────────────────────────────────
//  Grammaire partagée des écrans du groupe : KPI → barre de filtres (qui porte
//  le « + ») → en-tête de résultats → liste. Chrome dans `list_chrome.dart`.
// ════════════════════════════════════════════════════════════════════════════
class AdminFeesScreen extends ConsumerWidget {
  const AdminFeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: 'Frais & tarifs', child: _Body());
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String _type = 'tous';
  String _portee = 'toutes';
  String? _yearId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminFee> _filter(List<AdminFee> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((f) {
      if (_type != 'tous' && f.feeType != _type) return false;
      if (_portee == 'reseau' && !f.estReseau) return false;
      if (_portee == 'ecole' && f.estReseau) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          (f.schoolName ?? '').toLowerCase().contains(q) ||
          (f.sourceReference ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open({AdminFee? fee}) async {
    if (_yearId == null) return;
    final ok = await showAdminFeeForm(context,
        academicYearId: _yearId!, fee: fee);
    if (ok) ref.invalidate(adminFeesProvider(_yearId!));
  }

  Future<void> _retirer(AdminFee f) async {
    final ok = await showAdminConfirm(
      context,
      title: 'Retirer « ${f.name} » ?',
      message:
          'Le tarif cessera de s\'appliquer dans les écoles concernées à leur '
          'prochaine synchronisation. Les encaissements déjà enregistrés sont '
          'conservés : un reçu ne doit jamais renvoyer à un barème introuvable.',
      confirmLabel: 'Retirer',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await deactivateAdminFee(ref.read(supabaseClientProvider), f.id);
      if (_yearId != null) ref.invalidate(adminFeesProvider(_yearId!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final annees = ref.watch(adminAcademicYearsProvider);

    return annees.when(
      loading: () => const ListShimmer(),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (years) {
        if (years.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: AdminEmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Aucune année scolaire',
                message:
                    'Un tarif s\'attache à une année. Créez d\'abord une année '
                    'scolaire pour votre réseau.',
              ),
            ),
          );
        }
        final annee = years.firstWhere((y) => y.isCurrent,
            orElse: () => years.first);
        _yearId ??= annee.id;
        final yearId = _yearId!;

        return ref.watch(adminFeesProvider(yearId)).when(
              skipLoadingOnReload: true,
              loading: () => const ListShimmer(),
              error: (e, _) => Center(child: Text(messageErreur(e))),
              data: (rows) => _content(rows, years, yearId),
            );
      },
    );
  }

  Widget _content(List<AdminFee> rows, List<AdminYear> years, String yearId) {
    final filtered = _filter(rows);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KpiGrid(items: _kpis(rows)),
          const SizedBox(height: 20),
          ListFilterBar(
            searchCtrl: _search,
            searchHint: 'Rechercher un tarif, une école, un arrêté…',
            addLabel: 'Tarif',
            addIcon: Icons.request_quote_rounded,
            onSearchChange: (_) => setState(() {}),
            onAdd: () => _open(),
            onReset: () => setState(() {
              _search.clear();
              _type = 'tous';
              _portee = 'toutes';
            }),
            filters: [
              ListFilterDropdown(
                icon: Icons.calendar_month_rounded,
                label: 'Année',
                value: yearId,
                items: {for (final y in years) y.id: y.label},
                onChanged: (v) => setState(() => _yearId = v),
              ),
              ListFilterDropdown(
                icon: Icons.category_rounded,
                label: 'Type',
                value: _type,
                items: const {'tous': 'Tous', ...kAdminFeeTypes},
                onChanged: (v) => setState(() => _type = v),
              ),
              ListFilterDropdown(
                icon: Icons.account_balance_rounded,
                label: 'Portée',
                value: _portee,
                items: const {
                  'toutes': 'Toutes',
                  'reseau': 'Réseau',
                  'ecole': 'Établissement',
                },
                onChanged: (v) => setState(() => _portee = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListResultHeader(
              total: rows.length, filtered: filtered.length, noun: 'tarif'),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              // ⚠️ « Pas de barème, pas d'encaissement » : tant que cette liste
              // est vide, AUCUNE école du réseau ne peut encaisser. L'état vide
              // doit le dire, pas se contenter d'un « aucun résultat ».
              child: AdminEmptyState(
                icon: Icons.request_quote_outlined,
                title: 'Aucun tarif publié',
                message:
                    'Tant qu\'aucun tarif n\'est publié pour cette année, vos '
                    'écoles ne peuvent enregistrer aucun paiement. C\'est ici '
                    'que se saisissent les montants de l\'arrêté.',
              ),
            )
          else
            for (final f in filtered)
              _FeeRow(
                fee: f,
                onEdit: () => _open(fee: f),
                onRemove: () => _retirer(f),
              ),
        ],
      ),
    );
  }

  List<KpiData> _kpis(List<AdminFee> rows) {
    final n = rows.length;
    final reseau = rows.where((f) => f.estReseau).length;
    final ecoles = rows.map((f) => f.schoolId).whereType<String>().toSet().length;
    int maxOf(String t) {
      final v = rows.where((f) => f.feeType == t).map((f) => f.amount);
      return v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
    }

    final inscription = maxOf('inscription');
    final mensualite = maxOf('mensualite');

    return [
      KpiData(
        label: 'Tarifs publiés',
        value: '$n',
        sub: n == 0 ? '⛔ aucun encaissement possible' : '$reseau au réseau',
        icon: Icons.request_quote_rounded,
        color: n == 0 ? kRed : kNavy,
        trend: n == 0 ? 'à saisir' : '✅ publiés',
        trendUp: n > 0,
        progressValue: n > 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Tarifs d\'établissement',
        value: '$ecoles',
        sub: ecoles == 0 ? 'aucune dérogation' : 'école(s) avec tarif propre',
        icon: Icons.account_balance_rounded,
        color: kAccent,
        progressValue: n > 0 ? (n - reseau) / n : 0,
        trend: ecoles == 0 ? 'grille unique' : '$ecoles dérogation(s)',
      ),
      KpiData(
        label: 'Inscription',
        value: inscription == 0 ? '—' : fmtCompact(inscription),
        sub: inscription == 0 ? 'non tarifée' : 'FCFA · plafond réseau',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF0EA5E9),
        progressValue: inscription > 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Mensualité',
        value: mensualite == 0 ? '—' : fmtCompact(mensualite),
        // Dans le public, l'absence de mensualité est la NORME, pas un oubli.
        sub: mensualite == 0 ? 'aucune (public)' : 'FCFA / mois',
        icon: Icons.event_repeat_rounded,
        color: kGreen,
        progressValue: mensualite > 0 ? 1 : 0,
      ),
    ];
  }
}

// ─── Une ligne de tarif ──────────────────────────────────────────────────────
class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.fee,
    required this.onEdit,
    required this.onRemove,
  });
  final AdminFee fee;
  final VoidCallback onEdit, onRemove;

  @override
  Widget build(BuildContext context) {
    final f = fee;
    final tone = f.estReseau ? kNavy : kAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.request_quote_rounded, size: 20, color: tone),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              _chip(adminFeeTypeLabel(f.feeType), kNavy),
              const SizedBox(width: 6),
              _chip(f.estReseau ? 'Réseau' : (f.schoolName ?? 'Établissement'),
                  tone),
            ]),
            const SizedBox(height: 3),
            Text(
                '${f.levelName ?? 'Tous les niveaux'}'
                '${f.dueDay != null ? ' · échéance le ${f.dueDay}' : ''}',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            if (f.sourceReference != null &&
                f.sourceReference!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(f.sourceReference!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: kTextMuted)),
              ),
          ]),
        ),
        Text(fmtXaf(f.amount),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kGreen)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
          onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ])),
            PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.block_rounded, size: 16, color: kRed),
                  const SizedBox(width: 8),
                  Text('Retirer', style: TextStyle(color: kRed)),
                ])),
          ],
        ),
      ]),
    );
  }

  Widget _chip(String label, Color tone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
      );
}
