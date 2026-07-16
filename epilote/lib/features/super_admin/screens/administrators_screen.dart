import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/administrators_provider.dart';
import '../services/admin_pdf_service.dart';

// ─── Design tokens (identiques à school_groups_screen) ───────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kBlue    = Color(0xFF0EA5E9);
const _kRed     = Color(0xFFEF4444);
Color get _kSurface => kSurface;
const _kBg      = Color(0xFFFFFFFF);
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

// ─── Helpers rôles ────────────────────────────────────────────────────────────
Color _roleColor(String role) => switch (role) {
  'super_admin'  => _kNavy,
  'admin_groupe' => _kGold,
  _              => _kMuted,
};

IconData _roleIcon(String role) => switch (role) {
  'super_admin'  => Icons.shield_rounded,
  'admin_groupe' => Icons.business_rounded,
  _              => Icons.person_rounded,
};

// ─── Écran principal ──────────────────────────────────────────────────────────

class AdministratorsScreen extends ConsumerWidget {
  const AdministratorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Administrateurs',
      child: _AdminsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _AdminsBody extends ConsumerStatefulWidget {
  const _AdminsBody();
  @override
  ConsumerState<_AdminsBody> createState() => _AdminsBodyState();
}

class _AdminsBodyState extends ConsumerState<_AdminsBody> {
  final _searchCtrl   = TextEditingController();
  String _filterRole   = 'tous';
  String _filterStatus = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminDetail> _applyFilters(List<AdminDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((a) {
      if (q.isNotEmpty) {
        final match = a.fullName.toLowerCase().contains(q)
            || a.email.toLowerCase().contains(q)
            || (a.groupName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterRole   != 'tous' && a.role != _filterRole) return false;
      if (_filterStatus == 'actif'   && !a.isActive) return false;
      if (_filterStatus == 'inactif' &&  a.isActive) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'      => a.fullName.compareTo(b.fullName),
      'za'      => b.fullName.compareTo(a.fullName),
      'recents' => b.lastLogin != null && a.lastLogin != null
          ? b.lastLogin!.compareTo(a.lastLogin!)
          : (b.lastLogin != null ? 1 : -1),
      _         => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openForm({AdminDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _AdminFormModal(editing: editing),
    ).then((_) => ref.invalidate(administratorsProvider));
  }

  void _openDetail(AdminDetail a) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AdminDetailModal(
        admin: a,
        onEdit:   () { Navigator.pop(context); _openForm(editing: a); },
        onToggle: () { Navigator.pop(context); _toggleActive(a); },
        onReset:  () { Navigator.pop(context); _resetPassword(a); },
        onDelete: () { Navigator.pop(context); _confirmDelete(a); },
        onPrint:  () => _printAdmin(a),
      ),
    );
  }

  void _printAdmin(AdminDetail a) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AdminPrintPreviewModal(admin: a),
    );
  }

  Future<void> _toggleActive(AdminDetail a) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('profiles')
          .update({'is_active': !a.isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', a.id);
      ref.invalidate(administratorsProvider);
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  Future<void> _resetPassword(AdminDetail a) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.resetPasswordForEmail(a.email);
      if (mounted) _showSuccess('Email de réinitialisation envoyé à ${a.email}');
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  Future<void> _confirmDelete(AdminDetail a) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(admin: a),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_admin_user', params: {'p_user_id': a.id});
      ref.invalidate(administratorsProvider);
      if (mounted) _showSuccess('Compte "${a.fullName}" supprimé définitivement.');
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(administratorsProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text('Erreur : $e', style: TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(administratorsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(AdminsData data) {
    final filtered = _applyFilters(data.admins);

    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── KPI grid ───────────────────────────────────────────────
              _KpiGrid(data: data),
              const SizedBox(height: 20),

              // ── Barre de filtres ────────────────────────────────────────
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterRole:     _filterRole,
                filterStatus:   _filterStatus,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onRole:         (v) => setState(() => _filterRole   = v),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterRole = _filterStatus = 'tous';
                  _sort = 'recent';
                }),
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),

              // ── Résultat ────────────────────────────────────────────────
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),

              // ── Vue principale ──────────────────────────────────────────
              if (_isTableView)
                _TableView(
                  admins:   filtered,
                  onView:   _openDetail,
                  onEdit:   (a) => _openForm(editing: a),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                  onReset:  _resetPassword,
                )
              else
                _CardGrid(
                  admins:   filtered,
                  onView:   _openDetail,
                  onEdit:   (a) => _openForm(editing: a),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid — 6 cartes 3×2 ─────────────────────────────────────────────────

class _KD {
  const _KD({
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true,
    this.progressValue,
  });
  final String  label, value;
  final String? sub, trend;
  final bool    trendUp;
  final double? progressValue;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AdminsData data;

  @override
  Widget build(BuildContext context) {
    final n       = data.total;
    final inactifs = n - data.actifs;
    final items = [
      _KD(
        label: 'Total Admins',   value: '$n',
        sub:   '${data.actifs} actifs · $inactifs inactifs',
        icon:  Icons.admin_panel_settings_rounded, color: _kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Super Admins',   value: '${data.superAdmins}',
        sub:   'Accès total plateforme',
        icon:  Icons.shield_rounded,              color: _kGold,
        progressValue: n > 0 ? data.superAdmins / n : 0,
        trend: data.superAdmins > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Admins Groupe',  value: '${data.adminsGroupe}',
        sub:   'Accès groupe scolaire',
        icon:  Icons.business_rounded,            color: _kBlue,
        progressValue: n > 0 ? data.adminsGroupe / n : 0,
        trend: data.adminsGroupe > 0
            ? '${data.adminsGroupe} groupe${data.adminsGroupe > 1 ? "s" : ""}' : '—',
      ),
      _KD(
        label: 'Actifs',         value: '${data.actifs}',
        sub:   n > 0 ? '${(data.actifs * 100 / n).round()}% du total' : '—',
        icon:  Icons.check_circle_rounded,        color: _kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Connectés (7j)', value: '${data.connectes7j}',
        sub:   'Derniers 7 jours',
        icon:  Icons.login_rounded,               color: _kPurple,
        progressValue: n > 0 ? data.connectes7j / n : 0,
        trend: data.connectes7j > 0 ? '${data.connectes7j} actifs' : 'Aucun',
        trendUp: data.connectes7j > 0,
      ),
      _KD(
        label: 'Inactifs',       value: '$inactifs',
        sub:   inactifs > 0 ? 'Comptes désactivés' : '✅ Tous actifs',
        icon:  Icons.block_rounded,               color: _kRed,
        progressValue: n > 0 ? inactifs / n : 0,
        trend: inactifs > 0 ? '⚠ À vérifier' : '✅ OK',
        trendUp: inactifs == 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        )),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(
                          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: d.trendUp ? d.color : _kOrange,
                            fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ]),
                  ]),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Skeleton ─────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 14,
              mainAxisSpacing: 14, childAspectRatio: 2.6,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
          ),
          const SizedBox(height: 20),
          _box(double.infinity, 120, r: 14),
          const SizedBox(height: 16),
          _box(180, 18, r: 8),
          const SizedBox(height: 16),
          _box(double.infinity, 48, r: 6),
          const SizedBox(height: 1),
          ...List.generate(6, (_) => Column(children: [
            const SizedBox(height: 1),
            _box(double.infinity, 56, r: 0),
          ])),
        ]),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterRole,
    required this.filterStatus,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onRole,
    required this.onStatus,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterRole, filterStatus, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onRole, onStatus, onSort;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: contentWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ─ Ligne 1 : Search + Toggle vue + Bouton créer ──────────────────
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, email, groupe…',
                  hintStyle: TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: _kMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true,
                  fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Réinitialiser les filtres',
                child: InkWell(
                  onTap: onReset,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvel admin', style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    )),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // ─ Filtres dropdowns ─────────────────────────────────────────────
          Row(children: [
            _FilterDropdown(
              icon: Icons.shield_rounded,
              label: 'Rôle',
              items: const {
                'tous':          'Tous les rôles',
                'super_admin':   'Super Admin',
                'admin_groupe':  'Admin Groupe',
              },
              value: filterRole,
              onChanged: onRole,
              active: filterRole != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded,
              label: 'Statut',
              items: const {
                'tous':    'Tous les statuts',
                'actif':   'Actifs',
                'inactif': 'Inactifs',
              },
              value: filterStatus,
              onChanged: onStatus,
              active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded,
              label: 'Trier',
              items: const {
                'recent':  'Plus récents',
                'az':      'A → Z',
                'za':      'Z → A',
                'recents': 'Dernière connexion',
              },
              value: sort,
              onChanged: onSort,
              active: sort != 'recent',
            ),
            const Spacer(),
            if (filterRole != 'tous' || filterStatus != 'tous' || sort != 'recent')
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: _kRed),
                      SizedBox(width: 4),
                      Text('Réinitialiser', style: TextStyle(
                          color: _kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
  });
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : _kMuted),
        style: TextStyle(
          color: active ? Colors.white : _kMuted,
          fontSize: 12.5, fontWeight: FontWeight.w600,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class _ToggleViewBtn extends StatelessWidget {
  const _ToggleViewBtn({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Tooltip(
      message: isTable ? 'Vue en cartes' : 'Vue en tableau',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: _kNavy,
          ),
        ),
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? "s" : ""}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.admins,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReset,
  });

  final List<AdminDetail> admins;
  final ValueChanged<AdminDetail> onView, onEdit, onDelete, onToggle, onReset;

  static const _avatarW  = 44.0;
  static const _statusW  = 88.0;
  static const _actionsW = 132.0;

  static Widget _hdr(String label, int flex, {bool center = false}) => Expanded(
    flex: flex,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label, style: TextStyle(
          color: _kMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (admins.isEmpty) return const _EmptyState();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          // En-tête
          Container(
            height: 38,
            color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _avatarW),
              _hdr('Administrateur',      3),
              _hdr('Rôle',               2),
              _hdr('Groupe scolaire',    2),
              _hdr('Email',              3),
              _hdr('Téléphone',          2),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Dernière connexion', 2),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          // Lignes
          ...admins.asMap().entries.map((e) => _TableRow(
            admin:    e.value,
            isOdd:    e.key.isOdd,
            avatarW:  _avatarW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onToggle: () => onToggle(e.value),
            onReset:  () => onReset(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.admin,
    required this.isOdd,
    required this.avatarW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReset,
  });
  final AdminDetail  admin;
  final bool         isOdd;
  final double       avatarW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle, onReset;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? _kNavy.withValues(alpha: 0.04)
              : widget.isOdd
                  ? _kSurface.withValues(alpha: 0.5)
                  : _kBg,
          border: Border(
            bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(children: [
          // Avatar (cliquable → détails)
          SizedBox(width: widget.avatarW, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              child: _AdminAvatar(admin: a, size: 36),
            ),
          )),

          // Nom + sous-titre (cliquable → détails)
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(a.fullName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  if (a.firstName.isEmpty && a.lastName.isEmpty)
                    Text('Profil incomplet',
                        style: TextStyle(fontSize: 10.5,
                            color: _kOrange.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )),

          // Rôle
          Expanded(flex: 2, child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _RoleBadge(role: a.role),
            ),
          )),

          // Groupe
          Expanded(flex: 2, child: a.groupName != null
              ? Row(children: [
                  if (a.groupLogo != null && a.groupLogo!.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: a.groupLogo!,
                        width: 20, height: 20, fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox(),
                      ),
                    )
                  else
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.business_rounded, size: 12, color: _kGold),
                    ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.groupName!,
                      style: TextStyle(fontSize: 12, color: _kText),
                      overflow: TextOverflow.ellipsis)),
                ])
              : Text(a.role == 'super_admin' ? 'Plateforme' : '—',
                  style: TextStyle(
                      fontSize: 12,
                      color: a.role == 'super_admin' ? _kNavy : _kMuted,
                      fontWeight: a.role == 'super_admin'
                          ? FontWeight.w600 : FontWeight.normal))),

          // Email
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: a.email,
              child: Text(a.email,
                  style: TextStyle(fontSize: 12, color: _kNavy),
                  overflow: TextOverflow.ellipsis),
            ),
          )),

          // Téléphone
          Expanded(flex: 2, child: Text(a.phone ?? '—',
              style: TextStyle(fontSize: 12, color: _kMuted),
              overflow: TextOverflow.ellipsis)),

          // Statut (cliquable pour toggle)
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: a.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: a.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: a.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(a.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: a.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),

          // Dernière connexion
          Expanded(flex: 2, child: Text(a.lastLoginLabel,
              style: TextStyle(fontSize: 11.5,
                  color: a.lastLogin == null
                      ? _kMuted.withValues(alpha: 0.6) : _kText),
              overflow: TextOverflow.ellipsis)),

          // Actions
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue,   tooltip: 'Voir la fiche',                  onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded,       color: _kNavy,   tooltip: 'Modifier',                       onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.lock_reset_rounded, color: _kOrange, tooltip: 'Réinitialiser le mot de passe',  onTap: widget.onReset),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded,     color: _kRed,    tooltip: 'Supprimer',                      onTap: widget.onDelete),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.admins,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<AdminDetail> admins;
  final ValueChanged<AdminDetail> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (admins.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.65,
      ),
      itemCount: admins.length,
      itemBuilder: (_, i) => _AdminCard(
        admin:    admins[i],
        onView:   () => onView(admins[i]),
        onEdit:   () => onEdit(admins[i]),
        onDelete: () => onDelete(admins[i]),
        onToggle: () => onToggle(admins[i]),
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  const _AdminCard({
    required this.admin,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final AdminDetail  admin;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? _kNavy.withValues(alpha: 0.4) : _kBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: _kNavy.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─ Header ───────────────────────────────────────────────────────
          Row(children: [
            _AdminAvatar(admin: a, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.fullName, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(a.email, style: TextStyle(
                    color: _kMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            // Statut dot
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: a.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ─ Badges ────────────────────────────────────────────────────────
          Wrap(spacing: 6, children: [
            _RoleBadge(role: a.role),
            if (a.groupName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(a.groupName!, style: TextStyle(
                    color: _kGold, fontSize: 11, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
          ]),
          const SizedBox(height: 10),

          // ─ Infos ─────────────────────────────────────────────────────────
          Row(children: [
            Icon(Icons.access_time_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 4),
            Text(a.lastLoginLabel, style: TextStyle(
                color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ]),

          const Spacer(),

          // ─ Actions ───────────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: widget.onView,
              icon: const Icon(Icons.visibility_rounded, size: 13),
              label: const Text('Voir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kBlue),
            ),
            TextButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Modifier', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kNavy),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: _kRed,
              tooltip: 'Supprimer',
            ),
          ]),
        ]),
      ),
      ),
    );
  }
}

// ─── Badges & avatars ─────────────────────────────────────────────────────────

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.admin, this.size = 36});
  final AdminDetail admin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(admin.role);
    if (admin.avatarUrl != null && admin.avatarUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: admin.avatarUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, _, _) => _Initials(
              initials: admin.initials, color: color, size: size),
        ),
      );
    }
    return _Initials(initials: admin.initials, color: color, size: size);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.color, required this.size});
  final String initials;
  final Color  color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
    ),
    child: Center(child: Text(initials, style: TextStyle(
        color: color, fontSize: size * 0.38, fontWeight: FontWeight.w800))),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_roleIcon(role), size: 11, color: color),
        const SizedBox(width: 4),
        Text(role == 'super_admin' ? 'Super Admin' : 'Admin Groupe',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.admin_panel_settings_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun administrateur trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouvel administrateur.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Widget upload avatar ─────────────────────────────────────────────────────

class _AvatarUploadBox extends StatelessWidget {
  const _AvatarUploadBox({
    required this.initials,
    required this.color,
    required this.avatarUrl,
    required this.previewBytes,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String    initials;
  final Color     color;
  final String?   avatarUrl;
  final Uint8List? previewBytes;
  final bool      uploading;
  final VoidCallback onPick, onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = previewBytes != null || (avatarUrl != null && avatarUrl!.startsWith('http'));

    return Column(children: [
      Stack(children: [
        // Cercle avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(
              color: hasImage ? _kBorder : color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: uploading
              ? Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy)))
              : previewBytes != null
                  ? Image.memory(previewBytes!, fit: BoxFit.cover)
                  : (avatarUrl != null && avatarUrl!.startsWith('http'))
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Center(child: Text(initials,
                            style: TextStyle(color: color, fontSize: 26,
                                fontWeight: FontWeight.w800))),
                        )
                      : Center(child: Text(initials,
                          style: TextStyle(color: color, fontSize: 26,
                              fontWeight: FontWeight.w800))),
        ),
        // Bouton modifier (pastille)
        if (!uploading)
          Positioned(
            right: 0, bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPick,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _kNavy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPick,
            child: Text('Changer', style: TextStyle(
                color: _kNavy, fontSize: 11, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _kNavy)),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: const Text('Supprimer', style: TextStyle(
                  color: _kRed, fontSize: 11, fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _kRed)),
            ),
          ),
        ],
      ]),
    ]);
  }
}

// ─── Modal création / édition ─────────────────────────────────────────────────

class _AdminFormModal extends ConsumerStatefulWidget {
  const _AdminFormModal({this.editing});
  final AdminDetail? editing;
  @override
  ConsumerState<_AdminFormModal> createState() => _AdminFormModalState();
}

class _AdminFormModalState extends ConsumerState<_AdminFormModal> {
  final _formKey        = GlobalKey<FormState>();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();

  String  _role         = 'admin_groupe';
  String? _groupId;
  bool    _saving       = false;
  bool    _obscurePwd   = true;

  // Avatar upload
  String?    _uploadedAvatarUrl;
  Uint8List? _avatarPreviewBytes;
  bool       _uploadingAvatar = false;

  bool get _isEditing => widget.editing != null;

  String get _initials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    return '?';
  }

  @override
  void initState() {
    super.initState();
    final a = widget.editing;
    if (a != null) {
      _firstNameCtrl.text  = a.firstName;
      _lastNameCtrl.text   = a.lastName;
      _emailCtrl.text      = a.email;
      _phoneCtrl.text      = a.phone ?? '';
      _role                = a.role;
      _groupId             = a.groupId;
      _uploadedAvatarUrl   = a.avatarUrl;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _avatarPreviewBytes = file.bytes;
      _uploadingAvatar = true;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final ext = file.extension ?? 'jpg';
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'admins/$fileName';

      await client.storage.from('avatars').uploadBinary(
        path,
        file.bytes!,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );

      final url = client.storage.from('avatars').getPublicUrl(path);
      setState(() => _uploadedAvatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur upload : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _avatarPreviewBytes = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      if (_isEditing) {
        await client.from('profiles').update({
          'first_name': _firstNameCtrl.text.trim(),
          'last_name':  _lastNameCtrl.text.trim(),
          'phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'role':       _role,
          'group_id':   _role == 'admin_groupe' ? _groupId : null,
          'avatar_url': _uploadedAvatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.editing!.id);
      } else {
        await client.rpc('create_admin_user', params: {
          'p_email':      _emailCtrl.text.trim(),
          'p_password':   _passwordCtrl.text,
          'p_first_name': _firstNameCtrl.text.trim(),
          'p_last_name':  _lastNameCtrl.text.trim(),
          'p_role':       _role,
          'p_group_id':   _role == 'admin_groupe' ? _groupId : null,
          'p_phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'p_avatar_url': _uploadedAvatarUrl,
        });
      }
      ref.invalidate(administratorsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(administratorsProvider).valueOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [const Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(
                  _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEditing ? 'Modifier l\'administrateur' : 'Nouvel administrateur',
                  style: TextStyle(color: _kText, fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  _isEditing ? 'Mise à jour des informations' : 'Remplissez les champs requis',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ]),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                mouseCursor: SystemMouseCursors.click,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),

          // ── Formulaire ───────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo de profil ─────────────────────────────────────
                    Center(child: _AvatarUploadBox(
                      initials:     _initials,
                      color:        _roleColor(_role),
                      avatarUrl:    _uploadedAvatarUrl,
                      previewBytes: _avatarPreviewBytes,
                      uploading:    _uploadingAvatar,
                      onPick:       _pickAndUploadAvatar,
                      onRemove: () => setState(() {
                        _uploadedAvatarUrl  = null;
                        _avatarPreviewBytes = null;
                      }),
                    )),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _FormField(
                        controller: _firstNameCtrl,
                        label: 'Prénom *',
                        icon: Icons.person_rounded,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _FormField(
                        controller: _lastNameCtrl,
                        label: 'Nom de famille *',
                        icon: Icons.person_outline_rounded,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                      )),
                    ]),
                    const SizedBox(height: 14),
                    _FormField(
                      controller: _emailCtrl,
                      label: 'Adresse email *',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: _isEditing,
                      hint: _isEditing ? 'Email non modifiable' : 'exemple@domaine.cg',
                      validator: _isEditing ? null : (v) {
                        if (v!.trim().isEmpty) return 'Requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (!_isEditing) ...[
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePwd,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe *',
                          hintText: 'Min. 8 caractères',
                          prefixIcon: Icon(Icons.lock_rounded, size: 16, color: _kMuted),
                          suffixIcon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: Icon(_obscurePwd
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                                  size: 16, color: _kMuted),
                              onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _kNavy, width: 1.5),
                          ),
                          filled: true, fillColor: _kSurface,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Requis';
                          if (v.length < 8) return 'Min. 8 caractères';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    const _SectionTitle('Rôle & Affectation'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          isExpanded: true,
                          icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                          style: TextStyle(color: _kText, fontSize: 13),
                          items: [
                            DropdownMenuItem(
                              value: 'super_admin',
                              child: Row(children: [
                                Icon(Icons.shield_rounded, size: 14, color: _kNavy),
                                const SizedBox(width: 8),
                                const Text('Super Admin — accès total plateforme'),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: 'admin_groupe',
                              child: Row(children: [
                                Icon(Icons.business_rounded, size: 14, color: _kGold),
                                const SizedBox(width: 8),
                                const Text('Admin Groupe — accès à un groupe scolaire'),
                              ]),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _role = v!;
                            if (v == 'super_admin') _groupId = null;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_role == 'admin_groupe') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          border: Border.all(
                              color: _groupId == null
                                  ? _kRed.withValues(alpha: 0.5) : _kBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _groupId,
                            isExpanded: true,
                            hint: Text('Sélectionner un groupe *',
                                style: TextStyle(color: _kMuted, fontSize: 13)),
                            icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                            style: TextStyle(color: _kText, fontSize: 13),
                            items: (data?.groups ?? []).map((g) =>
                              DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name, overflow: TextOverflow.ellipsis),
                              ),
                            ).toList(),
                            onChanged: (v) => setState(() => _groupId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _FormField(
                      controller: _phoneCtrl,
                      label: 'Téléphone (optionnel)',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Annuler', style: TextStyle(
                        color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        _saving ? 'Enregistrement…'
                            : (_isEditing ? 'Enregistrer' : 'Créer le compte'),
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Modal détails — Fiche officielle / CV plateforme ─────────────────────────

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}

String _fmtDateTime(DateTime? d) {
  if (d == null) return 'Jamais connecté';
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year} à ${hh}h$mm';
}

class _AdminDetailModal extends StatefulWidget {
  const _AdminDetailModal({
    required this.admin,
    required this.onEdit,
    required this.onToggle,
    required this.onReset,
    required this.onDelete,
    required this.onPrint,
  });
  final AdminDetail admin;
  final VoidCallback onEdit, onToggle, onReset, onDelete, onPrint;

  @override
  State<_AdminDetailModal> createState() => _AdminDetailModalState();
}

class _AdminDetailModalState extends State<_AdminDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header propre ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Avatar circulaire
              _AdminAvatar(admin: a, size: 66),
              const SizedBox(width: 14),
              // Infos
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.fullName, style: TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _RoleBadge(role: a.role),
                    _AdmStatusBadge(isActive: a.isActive),
                    if (a.groupName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kGold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kGold.withValues(alpha: 0.30)),
                        ),
                        child: Text(a.groupName!, style: TextStyle(
                            color: _kGold, fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.email_outlined, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(a.email,
                        style: TextStyle(color: _kMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (a.phone != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.phone_outlined, size: 12, color: _kMuted),
                      const SizedBox(width: 3),
                      Text(a.phone!,
                          style: TextStyle(color: _kMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              // Boutons d'action
              Row(children: [
                _ModalIconBtn(
                    icon: Icons.edit_rounded,
                    color: _kNavy,
                    tooltip: 'Modifier',
                    onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.print_rounded,
                    color: _kMuted,
                    tooltip: 'Imprimer',
                    onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.close_rounded,
                    color: _kMuted,
                    tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),

          // ─ Tabs ──────────────────────────────────────────────────────────────
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Rôle & Accès'),
                Tab(text: 'Activité'),
              ],
            ),
          ),

          // ─ Tab content ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AdmInfoTab(admin: a),
                _AdmAccessTab(admin: a),
                _AdmActivityTab(admin: a),
              ],
            ),
          ),

          // ─ Footer actions ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(
                  a.isActive ? Icons.block_rounded : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(a.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: a.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: a.isActive ? _kOrange : _kGreen),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onReset,
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('Mot de passe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Onglet Informations ────────────────────────────────────────────────────

class _AdmInfoTab extends StatelessWidget {
  const _AdmInfoTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _AdmSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.email_outlined, 'Email', a.email, copyable: true),
          _AdmDetailRow(Icons.phone_outlined, 'Téléphone', a.phone ?? '—'),
          _AdmDetailRow(Icons.badge_outlined, 'Nom complet', a.fullName,
              last: true),
        ]),
        const SizedBox(height: 14),
        const _AdmSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.tag_rounded, 'UUID', a.id, copyable: true,
              mono: true),
          _AdmDetailRow(Icons.confirmation_number_outlined, 'Référence',
              a.id.substring(0, 8).toUpperCase()),
          _AdmDetailRow(Icons.calendar_today_outlined, 'Créé le',
              _fmtDate(a.createdAt)),
          _AdmDetailRow(Icons.update_outlined, 'Mis à jour',
              _fmtDate(a.updatedAt), last: true),
        ]),
        const SizedBox(height: 14),
        // Méta rapide
        Row(children: [
          Expanded(child: _AdmMetaChip(
            icon: _roleIcon(a.role),
            label: a.roleLabel,
            color: _roleColor(a.role),
          )),
          const SizedBox(width: 8),
          Expanded(child: _AdmMetaChip(
            icon: a.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: a.isActive ? 'Actif' : 'Inactif',
            color: a.isActive ? _kGreen : _kRed,
          )),
          const SizedBox(width: 8),
          Expanded(child: _AdmMetaChip(
            icon: Icons.business_rounded,
            label: a.groupName ??
                (a.role == 'super_admin' ? 'Plateforme' : 'Non assigné'),
            color: _kGold,
          )),
        ]),
      ]),
    );
  }
}

// ─── Onglet Rôle & Accès ────────────────────────────────────────────────────

class _AdmAccessTab extends StatelessWidget {
  const _AdmAccessTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    final color = _roleColor(a.role);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Carte rôle principale
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_roleIcon(a.role), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(a.roleLabel, style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                a.role == 'super_admin'
                    ? 'Accès total à la plateforme'
                    : 'Accès limité à son groupe scolaire',
                style: TextStyle(color: _kMuted, fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ])),
            _AdmStatusBadge(isActive: a.isActive),
          ]),
        ),
        const SizedBox(height: 20),

        const _AdmSectionTitle('Périmètre d\'accès'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.shield_rounded, 'Niveau',
              a.role == 'super_admin' ? 'Plateforme globale' : 'Groupe scolaire'),
          _AdmDetailRow(Icons.data_usage_rounded, 'Données',
              a.role == 'super_admin'
                  ? 'Toutes les écoles & groupes'
                  : 'Écoles du groupe assigné'),
          _AdmDetailRow(Icons.business_rounded, 'Groupe',
              a.groupName ??
                  (a.role == 'super_admin' ? 'Plateforme E-PILOTE' : 'Non assigné'),
              last: true),
        ]),
        const SizedBox(height: 20),

        const _AdmSectionTitle('Statut du compte'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(
            a.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            'État', a.isActive ? 'Compte actif' : 'Compte désactivé'),
          _AdmDetailRow(Icons.login_rounded, 'Dernière connexion',
              _fmtDateTime(a.lastLogin), last: true),
        ]),
      ]),
    );
  }
}

// ─── Onglet Activité ────────────────────────────────────────────────────────

class _AdmActivityTab extends StatelessWidget {
  const _AdmActivityTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _AdmTimelineItem(
          icon: Icons.person_add_rounded,
          color: _kGreen,
          title: 'Compte créé',
          date: a.createdAt,
        ),
        if (a.lastLogin != null)
          _AdmTimelineItem(
            icon: Icons.login_rounded,
            color: _kNavy,
            title: 'Dernière connexion',
            date: a.lastLogin!,
          ),
        _AdmTimelineItem(
          icon: Icons.update_rounded,
          color: _kMuted,
          title: 'Dernière mise à jour du profil',
          date: a.updatedAt,
        ),
        if (!a.isActive)
          _AdmTimelineItem(
            icon: Icons.block_rounded,
            color: _kRed,
            title: 'Compte actuellement désactivé',
            date: a.updatedAt,
          ),
      ],
    );
  }
}

// ─── Helpers modal détail (style groupe scolaire) ────────────────────────────

class _AdmStatusBadge extends StatelessWidget {
  const _AdmStatusBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _AdmDetailCard extends StatelessWidget {
  const _AdmDetailCard(this.rows);
  final List<_AdmDetailRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _AdmDetailRow extends StatelessWidget {
  const _AdmDetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11.5 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copier',
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copié : $value'),
                    backgroundColor: _kNavy,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

class _AdmMetaChip extends StatelessWidget {
  const _AdmMetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(
          color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _AdmSectionTitle extends StatelessWidget {
  const _AdmSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _AdmTimelineItem extends StatelessWidget {
  const _AdmTimelineItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.date,
  });
  final IconData icon;
  final Color color;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(_fmtDate(date), style: TextStyle(
            color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────

class _AdminPrintPreviewModal extends StatefulWidget {
  const _AdminPrintPreviewModal({required this.admin});
  final AdminDetail admin;

  @override
  State<_AdminPrintPreviewModal> createState() => _AdminPrintPreviewModalState();
}

class _AdminPrintPreviewModalState extends State<_AdminPrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  AdminDetail get a => widget.admin;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await AdminPdfService.printAdmin(a);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur impression : $e'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    try {
      final path = await AdminPdfService.downloadAdmin(a);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            path != null ? 'PDF sauvegardé : $path' : 'PDF généré',
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur téléchargement : $e'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _copyToClipboard() {
    final now = _fmtDateTime(DateTime.now());
    final lines = [
      '════════════════════════════════════════',
      '  E-PILOTE CONGO — FICHE OFFICIELLE',
      '  Administrateur • Générée le $now',
      '════════════════════════════════════════',
      '',
      '  ${a.fullName.toUpperCase()}',
      '  Rôle : ${a.roleLabel}  |  Statut : ${a.isActive ? "Actif" : "Inactif"}',
      '',
      '── COORDONNÉES ──────────────────────────',
      '  Email       : ${a.email}',
      '  Téléphone   : ${a.phone ?? '—'}',
      '',
      '── RÔLE & ACCÈS ─────────────────────────',
      '  Rôle        : ${a.roleLabel}',
      '  Périmètre   : ${a.role == 'super_admin' ? "Plateforme globale" : "Groupe scolaire"}',
      '  Groupe      : ${a.groupName ?? (a.role == 'super_admin' ? "Plateforme E-PILOTE" : "Non assigné")}',
      '',
      '── ACTIVITÉ ─────────────────────────────',
      '  Dern. connexion : ${_fmtDateTime(a.lastLogin)}',
      '  Création        : ${_fmtDate(a.createdAt)}',
      '  Mis à jour      : ${_fmtDate(a.updatedAt)}',
      '',
      '════════════════════════════════════════',
      '  Document généré via E-PILOTE CONGO',
      '  Réf. : ${a.id.substring(0, 8).toUpperCase()}',
      '════════════════════════════════════════',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Fiche copiée dans le presse-papiers'),
      ]),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now  = _fmtDateTime(DateTime.now());
    final ref_ = a.id.substring(0, 8).toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 820),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          // ── Barre modale ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche officielle de l\'administrateur',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  $now',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5)),
              ]),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ]),
          ),

          // ── Aperçu PDF réel ────────────────────────────────────────────────
          Expanded(
            child: PdfPreview(
              build: (format) => AdminPdfService.buildPdf(a),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Fiche_${a.fullName.replaceAll(' ', '_')}.pdf',
            ),
          ),

          // ── Footer actions ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Fermer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Fermer', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              // Copier texte
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Copier', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Imprimer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _printing ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_printing)
                        SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kNavy))
                      else
                        Icon(Icons.print_rounded,
                            size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: TextStyle(
                              color: _kNavy, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Télécharger PDF
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _downloading ? null : _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_downloading)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded,
                            size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_downloading ? 'Génération…' : 'Télécharger PDF',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Dialog de suppression ────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.admin});
  final AdminDetail admin;
  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Suppression définitive',
                      style: TextStyle(color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Cette action est irréversible',
                      style: TextStyle(color: _kMuted, fontSize: 11.5)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  _AdminAvatar(admin: a, size: 42),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.fullName, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _kText)),
                    Text(a.email, style: TextStyle(fontSize: 12, color: _kMuted)),
                    const SizedBox(height: 4),
                    _RoleBadge(role: a.role),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kRed.withValues(alpha: 0.20)),
                ),
                child: const Text(
                  'Le compte sera supprimé définitivement. '
                  'L\'administrateur perdra immédiatement tout accès '
                  'à la plateforme E-PILOTE.',
                  style: TextStyle(color: _kRed, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : Colors.transparent,
                        border: Border.all(
                            color: _confirmed ? _kRed : _kMuted, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmed
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Je confirme vouloir supprimer définitivement ce compte administrateur',
                      style: TextStyle(fontSize: 12.5, color: _kText),
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Annuler', style: TextStyle(
                          color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                  child: InkWell(
                    onTap: _confirmed ? () => Navigator.pop(context, true) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : _kMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_forever_rounded,
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                            size: 15),
                        const SizedBox(width: 6),
                        Text('Supprimer définitivement',
                            style: TextStyle(
                                color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5));
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final String?               hint;
  final TextInputType?        keyboardType;
  final bool                  readOnly;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    readOnly:     readOnly,
    keyboardType: keyboardType,
    onChanged:    onChanged,
    style: TextStyle(fontSize: 13, color: readOnly ? _kMuted : _kText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: _kMuted),
      filled: true,
      fillColor: readOnly ? _kSurface.withValues(alpha: 0.5) : _kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: readOnly
            ? BorderSide(color: _kBorder)
            : BorderSide(color: _kNavy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    ),
    validator: validator,
  );
}
