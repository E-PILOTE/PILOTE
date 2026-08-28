import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/announcement_interactions_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/events_provider.dart';
import '../widgets/feed_composer_card.dart';
import '../widgets/feed_left_rail.dart';
import '../widgets/feed_right_rail.dart';
import '../widgets/feed_scaffold.dart';
import '../widgets/staff_feed_ui.dart';
import 'announcements_feed_cards.dart';
import 'announcements_feed_form.dart';
import 'events_feed.dart';
import 'events_feed_form.dart';
import '../../../core/utils/message_erreur.dart';
import '../providers/comm_droits.dart';

class StaffAnnouncementsScreen extends StatefulWidget {
  const StaffAnnouncementsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<StaffAnnouncementsScreen> createState() =>
      _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen> {
  late bool _showAgenda = widget.initialTab == 1;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Communication',
      child: _showAgenda
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AgendaTopBar(onBack: () => setState(() => _showAgenda = false)),
                Expanded(
                  child: EventsAgendaBody(
                    onBackToFeed: () => setState(() => _showAgenda = false),
                  ),
                ),
              ],
            )
          : _Feed(onOpenAgenda: () => setState(() => _showAgenda = true)),
    );
  }
}

class _AgendaTopBar extends StatelessWidget {
  const _AgendaTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Fil d\'actualité'),
            style: TextButton.styleFrom(foregroundColor: kNavy),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: kBorder),
          const SizedBox(width: 12),
          Icon(Icons.event_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text('Agenda',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _Feed extends ConsumerStatefulWidget {
  const _Feed({required this.onOpenAgenda});
  final VoidCallback onOpenAgenda;

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  final _searchCtrl = TextEditingController();
  String _search    = '';
  String _audience  = 'tous';
  String _period    = 'tout';
  bool   _pinnedOnly = false;
  bool   _savedOnly  = false;
  bool   _mineOnly   = false;
  bool   _mediaOnly  = false;  // KPI « Avec médias »
  String? _authorId;     // filtre « publications de <auteur> » (clic contributeur)
  String? _authorName;
  final  _checked   = <String>{};

  void _toggleCheck(String id) => setState(
      () => _checked.contains(id) ? _checked.remove(id) : _checked.add(id));

  Future<void> _bulkPin(List<AnnouncementDetail> anns, bool pin) async {
    for (final a in anns.where((a) => _checked.contains(a.id))) {
      await setAnnouncementPinnedScoped(ref, a.id, pin);
    }
    setState(() => _checked.clear());
  }

  Future<void> _bulkDelete(List<AnnouncementDetail> anns) async {
    final n  = _checked.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer $n annonce${n > 1 ? 's' : ''} ?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
            'Ces annonces seront supprimées pour toute l\'école. '
            'Action irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final a in anns.where((a) => _checked.contains(a.id))) {
      await deleteAnnouncementScoped(ref, a.id);
    }
    setState(() => _checked.clear());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _audience != 'tous' ||
      _period != 'tout' ||
      _pinnedOnly ||
      _savedOnly ||
      _mediaOnly;

  void _reset() => setState(() {
        _searchCtrl.clear();
        _search    = '';
        _audience  = 'tous';
        _period    = 'tout';
        _pinnedOnly = false;
        _savedOnly  = false;
        _mineOnly   = false;
        _mediaOnly  = false;
        _authorId   = null;
        _authorName = null;
      });

  List<AnnouncementDetail> _applyFilters(
      List<AnnouncementDetail> anns, Set<String> savedIds) {
    final q         = _search.trim().toLowerCase();
    final myId      = ref.read(authNotifierProvider).valueOrNull?.id;
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month);

    final filtered = anns.where((a) {
      // Filtre « publications d'un auteur » (clic sur un contributeur).
      if (_authorId != null && a.createdBy != _authorId) return false;
      // « Mes publications » : mes posts (archivés inclus). Ailleurs : on
      // masque les annonces archivées du fil.
      if (_mineOnly) {
        if (a.createdBy != myId) return false;
      } else if (a.isArchived) {
        return false;
      }
      if (_savedOnly  && !savedIds.contains(a.id)) return false;
      if (_pinnedOnly && !a.isPinned) return false;
      if (_mediaOnly  && a.attachments.isEmpty) return false;
      if (_audience != 'tous' && a.targetAudience != _audience) return false;
      if (_period != 'tout') {
        final d    = (a.publishedAt ?? a.createdAt).toLocal();
        final from = _period == 'semaine' ? weekStart : monthStart;
        if (d.isBefore(from)) return false;
      }
      if (q.isNotEmpty &&
          !a.title.toLowerCase().contains(q) &&
          !a.content.toLowerCase().contains(q)) { return false; }
      return true;
    }).toList();

    return [
      ...filtered.where((a) => a.isPinned),
      ...filtered.where((a) => !a.isPinned),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scopedAnnouncementsProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const FeedSkeleton(cards: 4, maxWidth: double.infinity),
      error: (e, _) =>
          Center(child: Text(messageErreur(e), style: TextStyle(color: kTextMuted))),
      data: (anns) => _buildBody(context, anns),
    );
  }

  Widget _buildBody(BuildContext context, List<AnnouncementDetail> anns) {
    final savedIds = ref.watch(savedAnnouncementIdsProvider).valueOrNull
        ?? const <String>{};
    final filtered = _applyFilters(anns, savedIds);

    final profile    = ref.watch(authNotifierProvider).valueOrNull;
    final ctx        = ref.watch(communicationContextProvider);
    final isAdmin    = ctx.isPlatform || ctx.isGroup;
    // ⚠️ LE DROIT DE PUBLIER SE LISAIT SUR LE RÔLE, PAS SUR LE PROFIL.
    // `directionRoles` = {proviseur, directeur, secretaire}, en dur : une école
    // ne pouvait ni confier la publication à quelqu'un d'autre, ni la retirer à
    // un adjoint. C'était le seul domaine du produit à décider ainsi — partout
    // ailleurs, le profil d'accès décide. La migration 0138 a créé les modules
    // `annonces` / `evenements` et reproduit EXACTEMENT ce partage par défaut :
    // rien ne change pour personne, mais l'école peut désormais le régler.
    final canManage = ref.watch(peutPublierAnnonceProvider);
    final peutModifier = ref.watch(peutModifierAnnonceProvider);
    final mySchoolId = profile?.schoolId;
    bool manageable(AnnouncementDetail a) => isAdmin
        ? true
        : (peutModifier && a.schoolId != null && a.schoolId == mySchoolId);

    final audiences = {
      'tous': 'Toutes les audiences',
      for (final a in anns)
        a.targetAudience: kAudienceLabels[a.targetAudience] ?? a.targetAudience,
    };

    final pinnedCount = anns.where((a) => !a.isArchived && a.isPinned).length;
    final myId        = profile?.id;
    final mineCount   = anns.where((a) => a.createdBy == myId).length;
    final upcoming    = ref
            .watch(scopedEventsProvider)
            .valueOrNull
            ?.where((e) => !e.isPast)
            .length ??
        0;
    final FeedShortcut? activeShortcut = _mineOnly
        ? FeedShortcut.mine
        : _savedOnly
            ? FeedShortcut.saved
            : _pinnedOnly
                ? FeedShortcut.pinned
                : null;

    // ── Centre : barre de filtres sticky + feed scrollable ─────────────────
    final center = LayoutBuilder(builder: (_, c) {
      final w       = c.maxWidth;
      // Fil de publications : 1 seule colonne (plus lisible) ; on ne divise
      // en 2 colonnes QUE sur très grand écran (≈ 27" et plus).
      final columns = w >= 1300 ? 2 : 1;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barre de filtres STICKY (uniquement s'il y a des annonces) ──
          if (anns.isNotEmpty) _StickyFilterBar(
            searchCtrl : _searchCtrl,
            audiences  : audiences,
            audience   : _audience,
            period     : _period,
            pinnedOnly : _pinnedOnly,
            savedOnly  : _savedOnly,
            hasFilters : _hasFilters,
            onSearch   : (v) => setState(() => _search = v),
            onAudience : (v) => setState(() => _audience = v),
            onPeriod   : (v) => setState(() => _period = v),
            onPinned   : () => setState(() {
              _pinnedOnly = !_pinnedOnly;
              _savedOnly  = false;
            }),
            onSaved    : () => setState(() {
              _savedOnly  = !_savedOnly;
              _pinnedOnly = false;
            }),
            onReset    : _reset,
          ),

          // ── Barre de sélection multiple ─────────────────────────────────
          if (_checked.isNotEmpty)
            _BulkActionBar(
              count   : _checked.length,
              onPin   : () => _bulkPin(anns, true),
              onUnpin : () => _bulkPin(anns, false),
              onDelete: () => _bulkDelete(anns),
              onClear : () => setState(() => _checked.clear()),
            ),

          // ── Feed scrollable ─────────────────────────────────────────────
          Expanded(
            child: Builder(builder: (context) {
              // En-tête du fil (agenda éventuel + stories + compositeur).
              final leading = <Widget>[
                if (_authorId != null) ...[
                  _AuthorFilterBanner(
                    name: _authorName ?? 'Cet auteur',
                    onClear: () => setState(_clearAuthor),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!feedShowRail(w)) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenAgenda,
                      icon: const Icon(Icons.event_rounded, size: 17),
                      label: const Text('Agenda'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canManage) ...[
                  FeedComposerCard(
                    avatarColor: roleColor(profile?.role),
                    avatarInitials: _selfInitials(profile?.fullName),
                    avatarUrl: profile?.avatarUrl,
                    hint: ctx.isPlatform
                        ? 'Publiez une annonce à un groupe scolaire…'
                        : ctx.isGroup
                            ? 'Publiez une annonce à votre groupe…'
                            : 'Partagez une annonce à votre établissement…',
                    onCompose: () => _openComposer(context),
                    onComposePhoto: () => _openComposer(context, attach: true),
                    onComposeDoc  : () => _openComposer(context, attach: true),
                    onComposeEvent: () => showDialog<void>(
                        context: context,
                        builder: (_) => const StaffEventFormDialog()),
                  ),
                  const SizedBox(height: 16),
                ],
              ];

              final pad = EdgeInsets.fromLTRB(
                  columns >= 2 ? 16 : 10, 14, columns >= 2 ? 16 : 10, 14);

              // États vide / sans résultat.
              if (anns.isEmpty || filtered.isEmpty) {
                return ListView(
                  padding: pad,
                  children: [
                    ...leading,
                    if (anns.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: AdminEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Aucune publication',
                          message:
                              'Les annonces de votre communauté apparaîtront ici.',
                        ),
                      )
                    else
                      StaffNoResults(onReset: _reset),
                  ],
                );
              }

              // Grand écran (≥1300) : masonry 2 colonnes (cas rare).
              if (columns >= 2) {
                return ListView(
                  padding: pad,
                  children: [
                    ...leading,
                    StaffColumnGrid(
                      columns: columns,
                      spacing: 14,
                      children: [for (final a in filtered) _annCard(a, manageable)],
                    ),
                  ],
                );
              }

              // Cas courant 1 colonne : rendu LAZY (ListView.builder).
              return ListView.builder(
                padding: pad,
                itemCount: leading.length + filtered.length,
                itemBuilder: (context, i) {
                  if (i < leading.length) return leading[i];
                  final a = filtered[i - leading.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _annCard(a, manageable),
                  );
                },
              );
            }),
          ),
        ],
      );
    });

    final scaffold = FeedScaffold(
      center   : center,
      leftRail : FeedLeftRail(
        active       : activeShortcut,
        totalCount   : anns.where((a) => !a.isArchived).length,
        pinnedCount  : pinnedCount,
        savedCount   : savedIds.length,
        upcomingCount: upcoming,
        mineCount    : mineCount,
        showMine     : canManage,
        onShortcut   : _onShortcut,
        // La création passe par le FAB rouge (bas à droite).
      ),
      rightRail: FeedRightRail(
        announcements: anns,
        onSelectAuthor: _selectAuthor,
        onKpi        : _onKpi,
        onSeeAgenda  : widget.onOpenAgenda,
        onAddEvent   : canManage
            ? () => showDialog<void>(
                  context: context,
                  builder: (_) => const StaffEventFormDialog(),
                )
            : null,
      ),
    );

    // FAB rouge « Publier » ancré en bas à droite du contenu — réservé aux
    // profils autorisés à publier (gouvernance inchangée).
    if (!canManage) return scaffold;
    return Stack(
      children: [
        Positioned.fill(child: scaffold),
        Positioned(
          right: 24,
          bottom: 24,
          child: _PublishFab(onTap: () => _openComposer(context)),
        ),
      ],
    );
  }

  void _onShortcut(FeedShortcut s) {
    switch (s) {
      case FeedShortcut.all:
        setState(() { _pinnedOnly = false; _savedOnly = false; _mineOnly = false; _clearAuthor(); });
      case FeedShortcut.mine:
        setState(() { _mineOnly = !_mineOnly; _pinnedOnly = false; _savedOnly = false; _clearAuthor(); });
      case FeedShortcut.pinned:
        setState(() { _pinnedOnly = !_pinnedOnly; _savedOnly = false; _mineOnly = false; _clearAuthor(); });
      case FeedShortcut.saved:
        setState(() { _savedOnly = !_savedOnly; _pinnedOnly = false; _mineOnly = false; _clearAuthor(); });
      case FeedShortcut.agenda:
        widget.onOpenAgenda();
    }
  }

  void _clearAuthor() { _authorId = null; _authorName = null; }

  // KPI « Vue d'ensemble » cliquables → filtres du fil.
  void _onKpi(String key) {
    switch (key) {
      case 'all':
        _onShortcut(FeedShortcut.all);
      case 'pinned':
        setState(() {
          _pinnedOnly = true; _savedOnly = false; _mineOnly = false;
          _mediaOnly = false; _clearAuthor();
        });
      case 'events':
        widget.onOpenAgenda();
      case 'week':
        setState(() { _period = 'semaine'; });
      case 'media':
        setState(() {
          _mediaOnly = true; _pinnedOnly = false; _savedOnly = false;
          _mineOnly = false; _clearAuthor();
        });
    }
  }

  void _selectAuthor(String id, String name) => setState(() {
        _authorId   = id;
        _authorName = name;
        _mineOnly   = false;
        _pinnedOnly = false;
        _savedOnly  = false;
      });

  // Construit une carte de publication (réutilisée par le grid et le builder lazy).
  Widget _annCard(
      AnnouncementDetail a, bool Function(AnnouncementDetail) manageable) {
    return StaffAnnCard(
      ann           : a,
      manageable    : manageable(a),
      checked       : _checked.contains(a.id),
      onCheckToggle : manageable(a) ? () => _toggleCheck(a.id) : null,
      onEdit        : () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => StaffAnnouncementFormDialog(existing: a)),
      onTogglePin   : () => runFeedAction(
        context,
        running: a.isPinned ? 'Désépinglage…' : 'Épinglage…',
        success: a.isPinned ? 'Publication désépinglée.' : 'Publication épinglée.',
        action: () => setAnnouncementPinnedScoped(ref, a.id, !a.isPinned),
      ),
      onArchive     : () => runFeedAction(
        context,
        running: a.isArchived ? 'Désarchivage…' : 'Archivage…',
        success: a.isArchived
            ? 'Publication désarchivée.'
            : 'Publication archivée (retirée du fil).',
        action: () => setAnnouncementArchivedScoped(ref, a.id, !a.isArchived),
      ),
      onRemoveAttachment: (att) => runFeedAction(
        context,
        running: 'Suppression du document…',
        success: 'Document retiré de la publication.',
        action: () => removeAttachmentScoped(ref, a, att),
      ),
      onDelete      : () => confirmDeleteAnnouncement(ref, context, a),
      onHashtag     : (tag) => setState(() {
        _searchCtrl.text = '#$tag';
        _search = '#$tag';
      }),
    );
  }

  void _openComposer(BuildContext context, {bool attach = false}) =>
      showDialog<void>(
        context: context,
        // Pas de fermeture accidentelle : on protège le brouillon en cours.
        barrierDismissible: false,
        builder: (_) => StaffAnnouncementFormDialog(openAttachPicker: attach),
      );
}

// ─── Barre de filtres STICKY (au-dessus du feed, hors du ListView) ───────────

class _StickyFilterBar extends StatelessWidget {
  const _StickyFilterBar({
    required this.searchCtrl,
    required this.audiences,
    required this.audience,
    required this.period,
    required this.pinnedOnly,
    required this.savedOnly,
    required this.hasFilters,
    required this.onSearch,
    required this.onAudience,
    required this.onPeriod,
    required this.onPinned,
    required this.onSaved,
    required this.onReset,
  });

  final TextEditingController searchCtrl;
  final String audience, period;
  final bool pinnedOnly, savedOnly, hasFilters;
  final Map<String, String> audiences;
  final ValueChanged<String> onSearch, onAudience, onPeriod;
  final VoidCallback onPinned, onSaved, onReset;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Zone RECHERCHE : barre large (plafonnée) + réinitialiser ──
            Row(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: StaffSearchField(
                      controller: searchCtrl,
                      hint      : 'Rechercher dans les annonces…',
                      onChanged : onSearch,
                    ),
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 10),
                StaffResetChip(onTap: onReset),
              ],
            ]),
            const SizedBox(height: 10),
            // ── Zone TRI : filtres en Wrap (reflow → jamais d'overflow) ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StaffFilterDropdown(
                  icon     : Icons.groups_rounded,
                  items    : audiences,
                  value    : audience,
                  active   : audience != 'tous',
                  onChanged: onAudience,
                ),
                StaffFilterDropdown(
                  icon     : Icons.calendar_month_rounded,
                  items    : const {
                    'tout'    : 'Toute période',
                    'mois'    : 'Ce mois',
                    'semaine' : 'Cette semaine',
                  },
                  value    : period,
                  active   : period != 'tout',
                  onChanged: onPeriod,
                ),
                StaffToggleChip(
                  icon  : Icons.push_pin_rounded,
                  label : 'Épinglées',
                  active: pinnedOnly,
                  onTap : onPinned,
                ),
                StaffToggleChip(
                  icon  : Icons.bookmark_rounded,
                  label : 'Enregistrées',
                  active: savedOnly,
                  color : kNavy,
                  onTap : onSaved,
                ),
              ],
            ),
          ],
        ),
      );
}

// ─── FAB « Publier » (pilule rouge flottante, bas à droite) ─────────────────

class _PublishFab extends StatefulWidget {
  const _PublishFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PublishFab> createState() => _PublishFabState();
}

class _PublishFabState extends State<_PublishFab>
    with SingleTickerProviderStateMixin {
  // Halo lumineux pulsant (effet « fluorescent »).
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  bool _hover = false;

  static const Color _redBright = Color(0xFFFF4D4D);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Nouvelle publication',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit : (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final t      = Curves.easeInOut.transform(_ctrl.value); // 0→1
                final glow   = (_hover ? 0.55 : 0.34) + t * 0.22;
                final spread = (_hover ? 5.0 : 1.5) + t * 4.0;
                return AnimatedScale(
                  scale: _hover ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        // Halo large fluorescent
                        BoxShadow(
                          color: kRed.withValues(alpha: glow),
                          blurRadius: 22 + t * 12,
                          spreadRadius: spread,
                        ),
                        // Coeur lumineux rapproché
                        BoxShadow(
                          color: _redBright.withValues(alpha: glow * 0.7),
                          blurRadius: 9,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_redBright, kRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25), width: 1),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Publier',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                ]),
              ),
            ),
          ),
        ),
      );
}

// ─── Barre de sélection multiple ─────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.onPin,
    required this.onUnpin,
    required this.onDelete,
    required this.onClear,
  });
  final int count;
  final VoidCallback onPin, onUnpin, onDelete, onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.04),
          border: Border(
            top   : BorderSide(color: kBorder),
            bottom: BorderSide(color: kBorder),
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
                '$count sélectionnée${count > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kNavy)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onPin,
            icon: const Icon(Icons.push_pin_rounded, size: 16),
            label: const Text('Épingler'),
            style: TextButton.styleFrom(foregroundColor: kAccent,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          TextButton.icon(
            onPressed: onUnpin,
            icon: const Icon(Icons.push_pin_outlined, size: 16),
            label: const Text('Dépingler'),
            style: TextButton.styleFrom(foregroundColor: kNavy,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Supprimer'),
            style: TextButton.styleFrom(foregroundColor: kRed,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Annuler la sélection',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close_rounded, size: 18, color: kTextMuted),
          ),
        ]),
      );
}

// Initiales de l'utilisateur courant (avatar du compositeur).
String _selfInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

// Bannière « Publications de <auteur> » (filtre déclenché par un contributeur).
class _AuthorFilterBanner extends StatelessWidget {
  const _AuthorFilterBanner({required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNavy.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Icon(Icons.person_search_rounded, size: 18, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: 'Publications de ',
                    style: TextStyle(fontSize: 13, color: kTextPrimary)),
                TextSpan(
                    text: name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Tout le fil'),
            style: TextButton.styleFrom(foregroundColor: kNavy),
          ),
        ]),
      );
}
