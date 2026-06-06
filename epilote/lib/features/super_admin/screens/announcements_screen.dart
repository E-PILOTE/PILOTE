import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/announcements_provider.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kGreen   = Color(0xFF009A44);
const _kGold    = Color(0xFFFBBC04);
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kBlue    = Color(0xFF0EA5E9);
const _kRed     = Color(0xFFEF4444);
const _kSurface = Color(0xFFF0F4F8);
const _kBg      = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFE2E8F0);
const _kText    = Color(0xFF0F172A);
const _kMuted   = Color(0xFF64748B);

// ─── Helpers audience ────────────────────────────────────────────────────────
const _audienceLabels = {
  'all':      'Tout le monde',
  'staff':    'Personnel',
  'teachers': 'Enseignants',
  'parents':  'Parents',
  'students': 'Élèves',
};

Color _audienceColor(String a) => switch (a) {
  'all'      => _kNavy,
  'staff'    => _kPurple,
  'teachers' => _kBlue,
  'parents'  => _kGold,
  'students' => _kGreen,
  _          => _kMuted,
};

IconData _audienceIcon(String a) => switch (a) {
  'all'      => Icons.groups_rounded,
  'staff'    => Icons.badge_rounded,
  'teachers' => Icons.school_rounded,
  'parents'  => Icons.family_restroom_rounded,
  'students' => Icons.person_rounded,
  _          => Icons.people_rounded,
};

String _audienceLabel(String a) => _audienceLabels[a] ?? a;

// ─── Écran principal ──────────────────────────────────────────────────────────

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Annonces générales',
      child: _AnnouncementsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _AnnouncementsBody extends ConsumerStatefulWidget {
  const _AnnouncementsBody();
  @override
  ConsumerState<_AnnouncementsBody> createState() => _AnnouncementsBodyState();
}

class _AnnouncementsBodyState extends ConsumerState<_AnnouncementsBody> {
  final _searchCtrl     = TextEditingController();
  String _filterStatus   = 'tous';
  String _filterAudience = 'tous';
  String _sort           = 'recent';
  bool   _isTableView    = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AnnouncementDetail> _applyFilters(List<AnnouncementDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((a) {
      if (q.isNotEmpty) {
        final match = a.title.toLowerCase().contains(q)
            || a.content.toLowerCase().contains(q)
            || (a.groupName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterStatus == 'publiee'   && !a.isPublished)  return false;
      if (_filterStatus == 'brouillon' &&  a.isPublished)  return false;
      if (_filterStatus == 'epinglee'  && !a.isPinned)     return false;
      if (_filterStatus == 'expiree'   && !a.isExpired)    return false;
      if (_filterAudience != 'tous' && a.targetAudience != _filterAudience) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'     => a.title.compareTo(b.title),
      'za'     => b.title.compareTo(a.title),
      'groupe' => (a.groupName ?? '').compareTo(b.groupName ?? ''),
      _        => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openForm({AnnouncementDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _AnnFormModal(editing: editing),
    ).then((_) => ref.invalidate(announcementsProvider));
  }

  void _openDetail(AnnouncementDetail a) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AnnDetailModal(
        ann:      a,
        onEdit:   () { Navigator.pop(context); _openForm(editing: a); },
        onTogglePublish: () { Navigator.pop(context); _togglePublish(a); },
        onDelete: () { Navigator.pop(context); _confirmDelete(a); },
      ),
    );
  }

  Future<void> _togglePublish(AnnouncementDetail a) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('announcements').update({
        'is_published': !a.isPublished,
        'published_at': !a.isPublished ? DateTime.now().toIso8601String() : null,
        'updated_at':   DateTime.now().toIso8601String(),
      }).eq('id', a.id);
      ref.invalidate(announcementsProvider);
      if (mounted) _showSuccess(a.isPublished ? 'Annonce dépubliée' : 'Annonce publiée ✅');
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  Future<void> _confirmDelete(AnnouncementDetail a) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteAnnDialog(ann: a),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('announcements').delete().eq('id', a.id);
      ref.invalidate(announcementsProvider);
      if (mounted) _showSuccess('Annonce supprimée.');
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
    final async = ref.watch(announcementsProvider);
    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text('Erreur : $e', style: const TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(announcementsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(AnnouncementsData data) {
    final filtered = _applyFilters(data.announcements);

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
              _KpiGrid(data: data),
              const SizedBox(height: 20),
              _FilterBar(
                contentWidth:    w - 48,
                searchCtrl:      _searchCtrl,
                filterStatus:    _filterStatus,
                filterAudience:  _filterAudience,
                sort:            _sort,
                isTableView:     _isTableView,
                onSearchChange:  (_) => setState(() {}),
                onStatus:        (v) => setState(() => _filterStatus   = v),
                onAudience:      (v) => setState(() => _filterAudience = v),
                onSort:          (v) => setState(() => _sort           = v),
                onToggleView:    ()  => setState(() => _isTableView    = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterStatus = _filterAudience = 'tous';
                  _sort = 'recent';
                }),
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                _TableView(anns: filtered, onView: _openDetail,
                    onEdit: (a) => _openForm(editing: a),
                    onToggle: _togglePublish, onDelete: _confirmDelete)
              else
                _CardGrid(anns: filtered, onView: _openDetail,
                    onEdit: (a) => _openForm(editing: a),
                    onToggle: _togglePublish, onDelete: _confirmDelete),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────

class _KD {
  const _KD({required this.label, required this.value, required this.icon,
      required this.color, this.sub, this.trend, this.trendUp = true, this.progressValue});
  final String  label, value;
  final String? sub, trend;
  final bool    trendUp;
  final double? progressValue;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AnnouncementsData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Annonces', value: '$n',
        sub:   '${data.published} publiées · ${data.pending} en attente',
        icon:  Icons.campaign_rounded, color: _kNavy,
        progressValue: n > 0 ? data.published / n : 0,
        trend: n > 0 ? '${(data.published * 100 / n).round()}% publiées' : '—',
      ),
      _KD(
        label: 'Publiées', value: '${data.published}',
        sub:   'Visibles par les destinataires',
        icon:  Icons.check_circle_rounded, color: _kGreen,
        progressValue: n > 0 ? data.published / n : 0,
        trend: data.published > 0 ? '✅ En ligne' : '—',
      ),
      _KD(
        label: 'Épinglées', value: '${data.pinned}',
        sub:   'Priorité haute',
        icon:  Icons.push_pin_rounded, color: _kOrange,
        progressValue: n > 0 ? data.pinned / n : 0,
        trend: data.pinned > 0 ? '📌 Mises en avant' : '—',
      ),
      _KD(
        label: 'En attente', value: '${data.pending}',
        sub:   'Brouillons non publiés',
        icon:  Icons.drafts_rounded, color: _kMuted,
        progressValue: n > 0 ? data.pending / n : 0,
        trend: data.pending > 0 ? '${data.pending} brouillons' : 'Aucun',
        trendUp: data.pending == 0,
      ),
      _KD(
        label: 'Expirées', value: '${data.expired}',
        sub:   'Date d\'expiration dépassée',
        icon:  Icons.event_busy_rounded, color: _kRed,
        progressValue: n > 0 ? data.expired / n : 0,
        trend: data.expired > 0 ? '⚠️ À archiver' : 'OK',
        trendUp: data.expired == 0,
      ),
      _KD(
        label: 'Audiences', value: _audienceLabels.length.toString(),
        sub:   'Cibles disponibles',
        icon:  Icons.groups_rounded, color: _kPurple,
        progressValue: 1,
        trend: '${_audienceLabels.length} types',
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6,
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
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
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
              color: _kBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200), height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(color: d.color, fontSize: 22,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(d.label, style: const TextStyle(color: _kMuted, fontSize: 11.5,
                            fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(color: d.color.withValues(alpha: 0.70),
                              fontSize: 10), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _kSurface,
                            borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
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
                            valueColor: AlwaysStoppedAnimation(d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
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

// ─── Shimmer ──────────────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();
  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)),
  );
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8ECF0), highlightColor: const Color(0xFFF5F7FA),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6,
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

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterAudience,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onAudience,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterAudience, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onAudience, onSort;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: contentWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par titre, contenu, groupe…',
                  hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true, fillColor: _kSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
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
                message: 'Réinitialiser',
                child: InkWell(
                  onTap: onReset, borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: _kSurface,
                        borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                    child: const Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
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
                    boxShadow: [BoxShadow(color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvelle annonce', style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded, label: 'Statut',
              items: const {
                'tous':      'Tous les statuts',
                'publiee':   'Publiées',
                'brouillon': 'Brouillons',
                'epinglee':  'Épinglées',
                'expiree':   'Expirées',
              },
              value: filterStatus, onChanged: onStatus, active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.people_rounded, label: 'Audience',
              items: const {
                'tous':     'Toutes les audiences',
                'all':      'Tout le monde',
                'staff':    'Personnel',
                'teachers': 'Enseignants',
                'parents':  'Parents',
                'students': 'Élèves',
              },
              value: filterAudience, onChanged: onAudience, active: filterAudience != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded, label: 'Trier',
              items: const {
                'recent': 'Plus récentes',
                'az':     'A → Z',
                'za':     'Z → A',
                'groupe': 'Par groupe',
              },
              value: sort, onChanged: onSort, active: sort != 'recent',
            ),
            const Spacer(),
            if (filterStatus != 'tous' || filterAudience != 'tous' || sort != 'recent')
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
  const _FilterDropdown({required this.icon, required this.label, required this.items,
      required this.value, required this.onChanged, required this.active});
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    height: 38, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, size: 18, color: active ? Colors.white : _kMuted),
        style: TextStyle(color: active ? Colors.white : _kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w600),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value),
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
        onTap: onToggle, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
              size: 18, color: _kNavy),
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
    Text('$filtered annonce${filtered > 1 ? "s" : ""}',
        style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: const TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.anns, required this.onView, required this.onEdit,
    required this.onToggle, required this.onDelete,
  });
  final List<AnnouncementDetail> anns;
  final ValueChanged<AnnouncementDetail> onView, onEdit, onToggle, onDelete;

  static const _statusW  = 96.0;
  static const _actionsW = 104.0;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: const TextStyle(color: _kMuted, fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.4), overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (anns.isEmpty) return const _EmptyState();
    return Container(
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _hdr('Titre', 3),
              _hdr('Groupe scolaire', 2),
              _hdr('Audience', 2),
              _hdr('Expiration', 2),
              const SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              const SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
          ...anns.asMap().entries.map((e) => _TableRow(
            ann: e.value, isOdd: e.key.isOdd,
            statusW: _statusW, actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onToggle: () => onToggle(e.value),
            onDelete: () => onDelete(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.ann, required this.isOdd, required this.statusW, required this.actionsW,
    required this.onView, required this.onEdit, required this.onToggle, required this.onDelete,
  });
  final AnnouncementDetail ann;
  final bool isOdd;
  final double statusW, actionsW;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? _kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
          border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView, behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (a.isPinned) ...[
                    const Icon(Icons.push_pin_rounded, size: 13, color: _kOrange),
                    const SizedBox(width: 4),
                  ],
                  Flexible(child: Text(a.title, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis)),
                ]),
                Text(a.content.length > 60 ? '${a.content.substring(0, 60)}…' : a.content,
                    style: const TextStyle(fontSize: 10.5, color: _kMuted),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          )),
          Expanded(flex: 2, child: Text(a.groupName ?? '—',
              style: const TextStyle(fontSize: 12, color: _kText), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _AudienceBadge(audience: a.targetAudience)),
          Expanded(flex: 2, child: Text(
            a.expiresAt != null ? _fmtDateShort(a.expiresAt!) : '—',
            style: TextStyle(fontSize: 11.5,
                color: a.isExpired ? _kRed : _kMuted, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          )),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
              ),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue, tooltip: 'Voir', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded, color: _kRed, tooltip: 'Supprimer', onTap: widget.onDelete),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
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
        onTap: onTap, borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.20))),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.anns, required this.onView, required this.onEdit,
      required this.onToggle, required this.onDelete});
  final List<AnnouncementDetail> anns;
  final ValueChanged<AnnouncementDetail> onView, onEdit, onToggle, onDelete;
  @override
  Widget build(BuildContext context) {
    if (anns.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.4,
      ),
      itemCount: anns.length,
      itemBuilder: (_, i) => _AnnCard(
        ann:      anns[i],
        onView:   () => onView(anns[i]),
        onEdit:   () => onEdit(anns[i]),
        onToggle: () => onToggle(anns[i]),
        onDelete: () => onDelete(anns[i]),
      ),
    );
  }
}

class _AnnCard extends StatefulWidget {
  const _AnnCard({required this.ann, required this.onView, required this.onEdit,
      required this.onToggle, required this.onDelete});
  final AnnouncementDetail ann;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  @override
  State<_AnnCard> createState() => _AnnCardState();
}

class _AnnCardState extends State<_AnnCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    final color = _audienceColor(a.targetAudience);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.4) : _kBorder),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(_audienceIcon(a.targetAudience), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: const TextStyle(color: _kText, fontSize: 13,
                    fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 2),
              ])),
              if (a.isPinned)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.push_pin_rounded, size: 14, color: _kOrange),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _AudienceBadge(audience: a.targetAudience),
              _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
            ]),
            const SizedBox(height: 8),
            Text(a.content.length > 80 ? '${a.content.substring(0, 80)}…' : a.content,
                style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.4),
                overflow: TextOverflow.ellipsis, maxLines: 2),
            const Spacer(),
            Text(a.groupName ?? '—', style: const TextStyle(
                color: _kNavy, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: widget.onView,
                icon: const Icon(Icons.visibility_rounded, size: 13),
                label: const Text('Voir', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kBlue),
              ),
              TextButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(a.isPublished ? Icons.unpublished_rounded : Icons.publish_rounded, size: 13),
                label: Text(a.isPublished ? 'Dépublier' : 'Publier',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: a.isPublished ? _kOrange : _kGreen),
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                color: _kRed, tooltip: 'Supprimer',
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _AudienceBadge extends StatelessWidget {
  const _AudienceBadge({required this.audience});
  final String audience;
  @override
  Widget build(BuildContext context) {
    final color = _audienceColor(audience);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_audienceIcon(audience), size: 11, color: color),
        const SizedBox(width: 4),
        Text(_audienceLabel(audience),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _PublishBadge extends StatelessWidget {
  const _PublishBadge({required this.isPublished, required this.isExpired});
  final bool isPublished, isExpired;
  @override
  Widget build(BuildContext context) {
    final color = isExpired ? _kRed : (isPublished ? _kGreen : _kMuted);
    final label = isExpired ? 'Expirée' : (isPublished ? 'Publiée' : 'Brouillon');
    final icon  = isExpired ? Icons.event_busy_rounded
        : (isPublished ? Icons.check_circle_rounded : Icons.drafts_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64), alignment: Alignment.center,
    child: const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.campaign_rounded, size: 56, color: _kBorder),
      SizedBox(height: 16),
      Text('Aucune annonce trouvée', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez une nouvelle annonce.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Helpers dates & widgets communs ──────────────────────────────────────────

const _moisFr = [
  'jan','fév','mars','avr','mai','juin',
  'juil','août','sep','oct','nov','déc',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}

String _fmtDateShort(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2,'0')}/${l.month.toString().padLeft(2,'0')}/${l.year}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5));
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(this.rows);
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias, child: Column(children: rows),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: _kBorder))),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(color: _kText,
          fontSize: mono ? 11 : 13, fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(message: 'Copier', child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copié : $value'), backgroundColor: _kNavy,
                  behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
                ));
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(padding: EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy)),
          )),
        ),
      ],
    ]),
  );
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
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
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.sub,
      required this.value, required this.onChanged});
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(value: value, activeThumbColor: _kGreen, onChanged: onChanged),
    ]),
  );
}

// ─── Modal Formulaire ─────────────────────────────────────────────────────────

class _AnnFormModal extends ConsumerStatefulWidget {
  const _AnnFormModal({this.editing});
  final AnnouncementDetail? editing;
  @override
  ConsumerState<_AnnFormModal> createState() => _AnnFormModalState();
}

class _AnnFormModalState extends ConsumerState<_AnnFormModal> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();

  String  _audience  = 'all';
  String? _groupId;
  bool    _isPinned  = false;
  bool    _isPublished = false;
  DateTime? _expiresAt;
  bool    _saving    = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.editing;
    if (a != null) {
      _titleCtrl.text   = a.title;
      _contentCtrl.text = a.content;
      _audience         = a.targetAudience;
      _groupId          = a.groupId;
      _isPinned         = a.isPinned;
      _isPublished      = a.isPublished;
      _expiresAt        = a.expiresAt;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner un groupe scolaire.'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user   = client.auth.currentUser;
      final payload = {
        'group_id':        _groupId,
        'title':           _titleCtrl.text.trim(),
        'content':         _contentCtrl.text.trim(),
        'target_audience': _audience,
        'is_pinned':       _isPinned,
        'is_published':    _isPublished,
        'published_at':    _isPublished ? DateTime.now().toIso8601String() : null,
        'expires_at':      _expiresAt?.toIso8601String(),
        'updated_at':      DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        await client.from('announcements').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('announcements').insert({
          ...payload,
          'created_by': user?.id ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      ref.invalidate(announcementsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(announcementsProvider).valueOrNull?.groups ?? const [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(_isEditing ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEditing ? 'Modifier l\'annonce' : 'Nouvelle annonce',
                    style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(_isEditing ? 'Mise à jour du contenu' : 'Créer et diffuser une annonce',
                    style: const TextStyle(color: _kMuted, fontSize: 11)),
              ]),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8), mouseCursor: SystemMouseCursors.click,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: _kSurface,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                  child: const Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Groupe cible
                  const _FormSectionTitle('Groupe scolaire *'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _kSurface,
                        border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _groupId,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: const TextStyle(color: _kText, fontSize: 13),
                        hint: const Text('Sélectionner un groupe', style: TextStyle(color: _kMuted)),
                        items: groups.map((g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Row(children: [
                            const Icon(Icons.business_rounded, size: 14, color: _kNavy),
                            const SizedBox(width: 8),
                            Flexible(child: Text(g.name, overflow: TextOverflow.ellipsis)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _groupId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Titre
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      prefixIcon: const Icon(Icons.campaign_rounded, size: 16, color: _kMuted),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  // Contenu
                  TextFormField(
                    controller: _contentCtrl,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration: InputDecoration(
                      labelText: 'Contenu *',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.notes_rounded, size: 16, color: _kMuted),
                      ),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  // Audience
                  const _FormSectionTitle('Audience cible'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _kSurface,
                        border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _audience, isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: const TextStyle(color: _kText, fontSize: 13),
                        items: _audienceLabels.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(_audienceIcon(e.key), size: 14, color: _audienceColor(e.key)),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _audience = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Expiration
                  const _FormSectionTitle('Date d\'expiration (optionnel)'),
                  const SizedBox(height: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _pickExpiry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(color: _kSurface,
                            border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.event_rounded, size: 16, color: _kMuted),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            _expiresAt != null ? _fmtDate(_expiresAt) : 'Aucune expiration',
                            style: TextStyle(fontSize: 13,
                                color: _expiresAt != null ? _kText : _kMuted),
                          )),
                          if (_expiresAt != null)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => setState(() => _expiresAt = null),
                                child: const Icon(Icons.close_rounded, size: 14, color: _kMuted),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Toggles
                  const _FormSectionTitle('Options de diffusion'),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    icon: Icons.push_pin_rounded, label: 'Épinglez l\'annonce',
                    sub: 'Affichée en tête de liste', value: _isPinned,
                    onChanged: (v) => setState(() => _isPinned = v),
                  ),
                  _SwitchRow(
                    icon: Icons.publish_rounded, label: 'Publier immédiatement',
                    sub: 'Visible par les destinataires dès maintenant', value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                  ),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: const BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context), borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Annuler', style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save, borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(_saving ? 'Enregistrement…' : (_isEditing ? 'Enregistrer' : 'Créer l\'annonce'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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

// ─── Modal Détail ─────────────────────────────────────────────────────────────

class _AnnDetailModal extends ConsumerStatefulWidget {
  const _AnnDetailModal({required this.ann, required this.onEdit,
      required this.onTogglePublish, required this.onDelete});
  final AnnouncementDetail ann;
  final VoidCallback onEdit, onTogglePublish, onDelete;
  @override
  ConsumerState<_AnnDetailModal> createState() => _AnnDetailModalState();
}

class _AnnDetailModalState extends ConsumerState<_AnnDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _audienceColor(a.targetAudience).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _audienceColor(a.targetAudience).withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_audienceIcon(a.targetAudience),
                    color: _audienceColor(a.targetAudience), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (a.isPinned) ...[
                    const Icon(Icons.push_pin_rounded, size: 14, color: _kOrange),
                    const SizedBox(width: 4),
                  ],
                  Flexible(child: Text(a.title, style: const TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _PublishBadge(isPublished: a.isPublished, isExpired: a.isExpired),
                  _AudienceBadge(audience: a.targetAudience),
                ]),
                if (a.groupName != null) ...[
                  const SizedBox(height: 4),
                  Text(a.groupName!, style: const TextStyle(
                      color: _kNavy, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _ModalIconBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // Tabs
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs, labelColor: _kNavy,
              unselectedLabelColor: _kMuted, indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: 'Contenu'), Tab(text: 'Audience & Diffusion'), Tab(text: 'Système')],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _AnnContentTab(ann: a),
            _AnnAudienceTab(ann: a),
            _AnnSystemTab(ann: a),
          ])),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onTogglePublish,
                icon: Icon(a.isPublished ? Icons.unpublished_rounded : Icons.publish_rounded, size: 16),
                label: Text(a.isPublished ? 'Dépublier' : 'Publier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: a.isPublished ? _kOrange : _kGreen,
                  side: BorderSide(color: a.isPublished ? _kOrange : _kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(foregroundColor: _kRed, side: const BorderSide(color: _kRed)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AnnContentTab extends StatelessWidget {
  const _AnnContentTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Titre'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
        child: Text(ann.title, style: const TextStyle(color: _kText, fontSize: 15,
            fontWeight: FontWeight.w700, height: 1.4)),
      ),
      const SizedBox(height: 14),
      const _SectionTitle('Contenu'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
        child: SelectableText(ann.content, style: const TextStyle(color: _kText, fontSize: 13, height: 1.6)),
      ),
    ]),
  );
}

class _AnnAudienceTab extends StatelessWidget {
  const _AnnAudienceTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Diffusion'),
      const SizedBox(height: 8),
      _DetailCard([
        _DetailRow(Icons.people_rounded, 'Audience', ann.targetAudienceLabel),
        _DetailRow(Icons.business_rounded, 'Groupe scolaire', ann.groupName ?? '—'),
        _DetailRow(Icons.publish_rounded, 'Statut publication',
            ann.isPublished ? 'Publiée' : 'Brouillon', last: ann.publishedAt == null),
        if (ann.publishedAt != null)
          _DetailRow(Icons.calendar_today_outlined, 'Publiée le', _fmtDate(ann.publishedAt), last: true),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetaChip(icon: Icons.push_pin_rounded,
            label: ann.isPinned ? 'Épinglée' : 'Non épinglée',
            color: ann.isPinned ? _kOrange : _kMuted)),
        const SizedBox(width: 8),
        Expanded(child: _MetaChip(icon: Icons.event_busy_rounded,
            label: ann.expiresAt != null ? 'Exp. ${_fmtDate(ann.expiresAt)}' : 'Sans expiration',
            color: ann.isExpired ? _kRed : (ann.expiresAt != null ? _kOrange : _kMuted))),
      ]),
    ]),
  );
}

class _AnnSystemTab extends StatelessWidget {
  const _AnnSystemTab({required this.ann});
  final AnnouncementDetail ann;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Identité système'),
      const SizedBox(height: 8),
      _DetailCard([
        _DetailRow(Icons.tag_rounded, 'UUID', ann.id, copyable: true, mono: true),
        _DetailRow(Icons.business_rounded, 'Group ID', ann.groupId, mono: true),
        _DetailRow(Icons.calendar_today_outlined, 'Créée le', _fmtDate(ann.createdAt)),
        _DetailRow(Icons.update_outlined, 'Mise à jour', _fmtDate(ann.updatedAt), last: true),
      ]),
    ]),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 11.5,
          fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Dialog Suppression ───────────────────────────────────────────────────────

class _DeleteAnnDialog extends StatefulWidget {
  const _DeleteAnnDialog({required this.ann});
  final AnnouncementDetail ann;
  @override
  State<_DeleteAnnDialog> createState() => _DeleteAnnDialogState();
}

class _DeleteAnnDialogState extends State<_DeleteAnnDialog> {
  bool _confirmed = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.ann;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(color: _kRed,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Supprimer l\'annonce',
                      style: TextStyle(color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Cette action est irréversible',
                      style: TextStyle(color: _kMuted, fontSize: 11.5)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder)),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _audienceColor(a.targetAudience).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_audienceIcon(a.targetAudience),
                        color: _audienceColor(a.targetAudience), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 13, color: _kText), overflow: TextOverflow.ellipsis),
                    Text(a.groupName ?? '—', style: const TextStyle(fontSize: 11.5, color: _kMuted)),
                  ])),
                ]),
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
                        border: Border.all(color: _confirmed ? _kRed : _kMuted, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmed ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Je confirme vouloir supprimer cette annonce',
                        style: TextStyle(fontSize: 12.5, color: _kText))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false), borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Annuler', style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: _confirmed ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
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
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5), size: 15),
                        const SizedBox(width: 6),
                        Text('Supprimer définitivement', style: TextStyle(
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
