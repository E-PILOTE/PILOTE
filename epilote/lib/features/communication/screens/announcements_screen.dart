import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/communication_scope.dart';

part 'announcement_kpis.dart';
part 'announcement_filters.dart';
part 'announcement_list.dart';
part 'announcement_form.dart';
part 'announcement_detail.dart';

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

// ─── Helpers dates ───────────────────────────────────────────────────────────
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

// ─── Écran principal (partagé scope-aware) ──────────────────────────────────────

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Annonces',
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
