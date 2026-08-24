import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_fees_provider.dart';
import '../widgets/admin_fee_row.dart';
import 'admin_fee_form_dialog.dart';

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
//  jamais « créé par » — la RLS (migration 0096) impose l'auteur, la migration
//  0099 impose l'unicité, le fondement et la trace.
//
//  ── FORME ──────────────────────────────────────────────────────────────────
//  Grammaire partagée des écrans du groupe : KPI → barre de filtres (qui porte
//  le « + ») → en-tête de résultats → liste. Chrome dans `list_chrome.dart`.
//
//  ⚠️ La liste est un `SliverList.builder`, pas une `Column`. À l'échelle
//  visée — un ministère peut publier un tarif par école — une `Column`
//  construisait le millier de lignes d'un coup, sur des postes qui n'ont pas
//  cette marge.
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
  String _etat = 'actifs';
  String? _yearId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminFee> _filter(List<AdminFee> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((f) {
      if (_etat == 'actifs' && !f.isActive) return false;
      if (_etat == 'retires' && f.isActive) return false;
      if (_type != 'tous' && f.feeType != _type) return false;
      if (_portee == 'reseau' && !f.estReseau) return false;
      if (_portee == 'ecole' && f.estReseau) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          (f.schoolName ?? '').toLowerCase().contains(q) ||
          (f.sourceReference ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _rafraichir() {
    if (_yearId != null) ref.invalidate(adminFeesProvider(_yearId!));
  }

  /// Message d'échec lisible. Un refus d'unicité est une décision MÉTIER —
  /// il se lit tel quel ; le reste passe par la traduction commune, jamais par
  /// l'objet exception brut.
  void _echec(Object e) {
    if (!mounted) return;
    final texte = switch (e) {
      BaremeDoublonException(:final message) => message,
      BaremeInterditException(:final message) => message,
      _ => messageErreur(e),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: kRed,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _open({AdminFee? fee}) async {
    if (_yearId == null) return;
    final ok =
        await showAdminFeeForm(context, academicYearId: _yearId!, fee: fee);
    if (ok) _rafraichir();
  }

  Future<void> _retirer(AdminFee f) async {
    final ok = await showAdminConfirm(
      context,
      title: 'Retirer « ${f.name} » ?',
      message:
          'Le tarif cessera de s\'appliquer dans les écoles concernées à leur '
          'prochaine synchronisation. Les encaissements déjà enregistrés sont '
          'conservés : un reçu ne doit jamais renvoyer à un barème introuvable. '
          'Vous pourrez le rétablir depuis le filtre « Retirés ».',
      confirmLabel: 'Retirer',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await deactivateAdminFee(ref.read(supabaseClientProvider), f.id);
      _rafraichir();
    } catch (e) {
      _echec(e);
    }
  }

  Future<void> _retablir(AdminFee f) async {
    try {
      await restoreAdminFee(ref.read(supabaseClientProvider), f.id);
      _rafraichir();
    } catch (e) {
      _echec(e);
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
        final annee =
            years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
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
    final actifs = rows.where((f) => f.isActive).toList();
    final filtered = _filter(rows);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KpiGrid(items: _kpis(actifs)),
                const SizedBox(height: 20),
                _barre(years, yearId),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ListResultHeader(
                        total: rows.length,
                        filtered: filtered.length,
                        noun: 'tarif'),
                  ),
                  _lienRattachement(context),
                ]),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            sliver: SliverToBoxAdapter(child: _vide(actifs.isEmpty)),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final f = filtered[i];
                return AdminFeeRow(
                  key: ValueKey(f.id),
                  fee: f,
                  onEdit: () => _open(fee: f),
                  onRemove: () => _retirer(f),
                  onRestore: () => _retablir(f),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// Le diagnostic vit ICI plutôt que dans la barre latérale.
  ///
  /// Un tarif de portée réseau visant un niveau n'atteint que les écoles
  /// rattachées à l'entrée visée du référentiel — les autres ne reçoivent rien,
  /// sans erreur ni message. La question ne se pose qu'en publiant un tarif :
  /// c'est donc là que la réponse doit être à un clic, et nulle part ailleurs
  /// dans un menu déjà chargé.
  Widget _lienRattachement(BuildContext context) => TextButton.icon(
        onPressed: () => context.go(Routes.adminRattachement),
        icon: const Icon(Icons.account_tree_rounded, size: 16),
        label: const Text('Rattachement des niveaux',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          foregroundColor: kNavy,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );

  Widget _barre(List<AdminYear> years, String yearId) => ListFilterBar(
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
          _etat = 'actifs';
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
          // Sans ce filtre, un retrait était définitif à l'écran : la ligne
          // disparaissait et rien ne permettait de la rétablir.
          ListFilterDropdown(
            icon: Icons.toggle_on_rounded,
            label: 'État',
            value: _etat,
            items: const {
              'actifs': 'Appliqués',
              'retires': 'Retirés',
              'tous': 'Tous',
            },
            onChanged: (v) => setState(() => _etat = v),
          ),
        ],
      );

  /// ⚠️ « Pas de barème, pas d'encaissement » : tant qu'aucun tarif n'est
  /// publié, AUCUNE école du réseau ne peut encaisser. L'état vide doit le
  /// dire — mais seulement quand c'est vrai : une liste vidée par un filtre
  /// n'est pas une caisse fermée.
  Widget _vide(bool aucunTarifPublie) => aucunTarifPublie
      ? const AdminEmptyState(
          icon: Icons.request_quote_outlined,
          title: 'Aucun tarif publié',
          message:
              'Tant qu\'aucun tarif n\'est publié pour cette année, vos écoles '
              'ne peuvent enregistrer aucun paiement. C\'est ici que se '
              'saisissent les montants de l\'arrêté.',
        )
      : const AdminEmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'Aucun tarif ne correspond',
          message:
              'Des tarifs sont bien publiés pour cette année : ce sont les '
              'filtres qui les écartent. Réinitialisez-les pour tout revoir.',
        );

  List<KpiData> _kpis(List<AdminFee> actifs) {
    final n = actifs.length;
    final reseau = actifs.where((f) => f.estReseau).length;
    final ecoles =
        actifs.map((f) => f.schoolId).whereType<String>().toSet().length;
    int maxOf(String t) {
      final v = actifs.where((f) => f.feeType == t).map((f) => f.amount);
      return v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
    }

    final inscription = maxOf('inscription');
    final mensualite = maxOf('mensualite');

    return [
      KpiData(
        label: 'Tarifs appliqués',
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
