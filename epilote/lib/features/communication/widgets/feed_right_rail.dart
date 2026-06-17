import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/announcements_provider.dart';
import '../providers/events_provider.dart';
import 'comm_text.dart' show kMoisCourtFr;
import 'user_avatar.dart';
import 'staff_feed_ui.dart'
    show audienceColor, kAudienceLabels, roleColor, roleLabelFr;

// ════════════════════════════════════════════════════════════════════════════
//  Rail DROIT du feed (≥1080px) — TABLEAU DE BORD / KPI.
//  100 % dynamique (calculé depuis les annonces + événements du périmètre).
//  Aucune valeur en dur. La carte « Agenda » est Expanded → remplit tout
//  l'espace restant (pas de vide), liste interne scrollable.
// ════════════════════════════════════════════════════════════════════════════

class FeedRightRail extends ConsumerWidget {
  const FeedRightRail({
    super.key,
    required this.announcements,
    this.onSeeAgenda,
    this.onAddEvent,
    this.onSelectAuthor,
    this.onKpi,
  });

  final List<AnnouncementDetail> announcements;
  final VoidCallback? onSeeAgenda;
  final VoidCallback? onAddEvent;
  /// Clic sur un contributeur → filtrer le fil sur ses publications.
  final void Function(String authorId, String name)? onSelectAuthor;
  /// Clic sur un KPI « Vue d'ensemble » → filtre du fil.
  final ValueChanged<String>? onKpi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events   = ref.watch(scopedEventsProvider).valueOrNull ?? const [];
    final upcoming = events.where((e) => !e.isPast).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    // ── KPIs dynamiques ───────────────────────────────────────────────────
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final total      = announcements.length;
    final pinned     = announcements.where((a) => a.isPinned).length;
    final thisWeek   = announcements
        .where((a) => !(a.publishedAt ?? a.createdAt).toLocal().isBefore(weekStart))
        .length;
    final withMedia  = announcements.where((a) => a.attachments.isNotEmpty).length;

    // Répartition par audience (dynamique)
    final byAudience = <String, int>{};
    for (final a in announcements) {
      byAudience[a.targetAudience] = (byAudience[a.targetAudience] ?? 0) + 1;
    }
    final audienceRows = byAudience.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Top contributeurs (par nb de publications) — gouvernance comm. ──────
    // Clé = authorId (createdBy) pour pouvoir filtrer le fil au clic.
    final byAuthor = <String, _Contrib>{};
    for (final a in announcements) {
      final id = a.createdBy;
      if (id.isEmpty) continue;
      final name = (a.authorName?.trim().isNotEmpty ?? false)
          ? a.authorName!.trim()
          : 'Membre';
      byAuthor
          .putIfAbsent(
              id, () => _Contrib(id, name, a.authorRole, a.authorAvatarUrl))
          .count++;
    }
    final contributors = byAuthor.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Rail SCROLLABLE (jamais d'overflow, même sur écran court) — les cartes
    // s'enchaînent et défilent comme le rail droit d'un réseau social.
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 20, 4, 20),
      children: [
        const AdminSectionTitle('Vue d\'ensemble',
            icon: Icons.insights_rounded),
        const SizedBox(height: 12),

        // ── Grille KPI ────────────────────────────────────────────────────
        _KpiGrid(
          total   : total,
          pinned  : pinned,
          thisWeek: thisWeek,
          media   : withMedia,
          events  : upcoming.length,
          onKpi   : onKpi,
        ),
        const SizedBox(height: 12),

        // ── Répartition par audience (barres proportionnelles) ────────────
        if (audienceRows.isNotEmpty) ...[
          _AudienceCard(rows: audienceRows, total: total),
          const SizedBox(height: 12),
        ],

        // ── Contributeurs actifs (top auteurs du périmètre) ───────────────
        if (contributors.length > 1) ...[
          _ContributorsCard(
              rows: contributors,
              total: total,
              onSelectAuthor: onSelectAuthor),
          const SizedBox(height: 12),
        ],

        // ── Agenda (événements à venir) ───────────────────────────────────
        _AgendaCard(
          upcoming   : upcoming,
          onSeeAgenda: onSeeAgenda,
          onAddEvent : onAddEvent,
        ),
      ],
    );
  }
}

// ─── Panneau KPI compact ──────────────────────────────────────────────────────
//  Tuiles légères (teinte 6 %) au lieu de gros blocs pleins → lecture rapide,
//  hauteur contenue, aucun overflow. Responsive : 2 colonnes, 1 si étroit.

class _Stat {
  const _Stat(this.key, this.label, this.value, this.icon, this.color);
  final String   key, label, value;
  final IconData icon;
  final Color    color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.total,
    required this.pinned,
    required this.thisWeek,
    required this.media,
    required this.events,
    this.onKpi,
  });
  final int total, pinned, thisWeek, media, events;
  final ValueChanged<String>? onKpi;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat('all', 'Publications', '$total', Icons.campaign_rounded, kNavy),
      _Stat('pinned', 'Épinglées', '$pinned', Icons.push_pin_rounded, kAccent),
      _Stat('week', 'Cette semaine', '$thisWeek', Icons.trending_up_rounded, kGreen),
      _Stat('events', 'Événements', '$events', Icons.event_rounded,
          const Color(0xFF0EA5E9)),
      _Stat('media', 'Avec médias', '$media', Icons.attach_file_rounded,
          const Color(0xFF7C3AED)),
    ];

    return AdminCard(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(builder: (context, c) {
        const gap  = 8.0;
        final cross = c.maxWidth >= 260 ? 2 : 1;
        final tileW = (c.maxWidth - (cross - 1) * gap) / cross;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats)
              SizedBox(
                  width: tileW,
                  child: _MiniStat(
                      stat: s,
                      onTap: onKpi == null ? null : () => onKpi!(s.key))),
          ],
        );
      }),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.stat, this.onTap});
  final _Stat stat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: stat.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: stat.color.withValues(alpha: 0.14)),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, size: 16, color: stat.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: stat.color)),
                Text(stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted)),
              ],
            ),
          ),
        ]),
      ),
      ),
    );
}

// ─── Répartition par audience ─────────────────────────────────────────────────

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({required this.rows, required this.total});
  final List<MapEntry<String, int>> rows;
  final int total;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.donut_small_rounded, size: 15, color: kNavy),
              SizedBox(width: 8),
              Text('Répartition par audience',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ]),
            const SizedBox(height: 12),
            for (final e in rows.take(5)) _AudienceBar(
              label: kAudienceLabels[e.key] ?? e.key,
              color: audienceColor(e.key),
              count: e.value,
              ratio: total == 0 ? 0 : e.value / total,
            ),
          ],
        ),
      );
}

class _AudienceBar extends StatelessWidget {
  const _AudienceBar({
    required this.label,
    required this.color,
    required this.count,
    required this.ratio,
  });
  final String label;
  final Color  color;
  final int    count;
  final double ratio;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
              ),
              Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio == 0 ? null : ratio.clamp(0.04, 1.0),
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
}

// ─── Contributeurs actifs (top auteurs) ───────────────────────────────────────

class _Contrib {
  _Contrib(this.id, this.name, this.role, this.avatarUrl);
  final String  id, name;
  final String? role;
  final String? avatarUrl;
  int count = 0;
}

class _ContributorsCard extends StatefulWidget {
  const _ContributorsCard(
      {required this.rows, required this.total, this.onSelectAuthor});
  final List<_Contrib> rows;
  final int total;
  final void Function(String authorId, String name)? onSelectAuthor;

  @override
  State<_ContributorsCard> createState() => _ContributorsCardState();
}

class _ContributorsCardState extends State<_ContributorsCard> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Barre de recherche dès qu'il y a plusieurs contributeurs.
    final searchable = widget.rows.length >= 2;
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.rows
        : widget.rows.where((c) => c.name.toLowerCase().contains(q)).toList();
    // On limite l'affichage : 6 sans recherche, jusqu'à 12 en recherche.
    final shown = filtered.take(q.isEmpty ? 6 : 12).toList();

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.workspace_premium_rounded, size: 15, color: kNavy),
            SizedBox(width: 8),
            Expanded(
              child: Text('Contributeurs actifs',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Touchez un nom pour voir ses publications',
              style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          if (searchable) ...[
            const SizedBox(height: 10),
            _RailSearchField(
              controller: _ctrl,
              hint: 'Rechercher une personne…',
              onChanged: (v) => setState(() => _q = v),
            ),
          ],
          const SizedBox(height: 10),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun contributeur trouvé',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            )
          else
            for (final c in shown)
              _ContributorRow(
                  c: c,
                  total: widget.total,
                  onSelectAuthor: widget.onSelectAuthor),
        ],
      ),
    );
  }
}

// ─── Champ de recherche compact (rail droit) ──────────────────────────────────
class _RailSearchField extends StatelessWidget {
  const _RailSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFFF4F6F9),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kNavy, width: 1.4),
            ),
          ),
        ),
      );
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow(
      {required this.c, required this.total, this.onSelectAuthor});
  final _Contrib c;
  final int      total;
  final void Function(String authorId, String name)? onSelectAuthor;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(c.role);
    final share = total == 0 ? 0.0 : c.count / total;

    return InkWell(
      onTap: onSelectAuthor == null ? null : () => onSelectAuthor!(c.id, c.name),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(children: [
        UserAvatarCircle(
            name: c.name, role: c.role, avatarUrl: c.avatarUrl, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(roleLabelFr(c.role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${c.count} · ${(share * 100).round()}%',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
      ]),
      ),
    );
  }
}

// ─── Agenda (événements à venir, remplit l'espace) ────────────────────────────

class _AgendaCard extends StatefulWidget {
  const _AgendaCard({
    required this.upcoming,
    this.onSeeAgenda,
    this.onAddEvent,
  });
  final List<EventModel> upcoming;
  final VoidCallback? onSeeAgenda;
  final VoidCallback? onAddEvent;

  @override
  State<_AgendaCard> createState() => _AgendaCardState();
}

class _AgendaCardState extends State<_AgendaCard> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchable = widget.upcoming.length >= 2;
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.upcoming
        : widget.upcoming
            .where((e) =>
                e.title.toLowerCase().contains(q) ||
                (e.location?.toLowerCase().contains(q) ?? false))
            .toList();
    final shown = filtered.take(q.isEmpty ? 8 : 20).toList();

    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(children: [
              const Icon(Icons.event_rounded, size: 16, color: kNavy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Événements à venir',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              if (widget.upcoming.isNotEmpty && widget.onSeeAgenda != null)
                GestureDetector(
                  onTap: widget.onSeeAgenda,
                  child: const Text('Agenda',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kNavy)),
                ),
            ]),
          ),
          if (searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _RailSearchField(
                controller: _ctrl,
                hint: 'Rechercher un événement…',
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          const Divider(height: 1, color: kBorder),
          if (widget.upcoming.isEmpty)
            _EventsEmpty(onAddEvent: widget.onAddEvent)
          else if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('Aucun événement trouvé',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _EventRow(event: shown[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EventsEmpty extends StatelessWidget {
  const _EventsEmpty({this.onAddEvent});
  final VoidCallback? onAddEvent;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available_rounded, size: 36, color: kBorder),
              const SizedBox(height: 10),
              const Text('Aucun événement à venir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted)),
              const SizedBox(height: 4),
              const Text('Planifiez un événement pour votre communauté',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4)),
              if (onAddEvent != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onAddEvent,
                  icon : const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Nouvel événement',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kNavy,
                    side: const BorderSide(color: kBorder),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(event.eventDate);
    final now = DateTime.now();
    final isToday = d != null &&
        d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 44,
          height: 48,
          decoration: BoxDecoration(
            color: isToday ? kNavy : kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border:
                isToday ? null : Border.all(color: kNavy.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(d == null ? '—' : '${d.day}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isToday ? Colors.white : kNavy)),
              Text(d == null ? '' : kMoisCourtFr[d.month - 1],
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white70 : kTextMuted)),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                      height: 1.3)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(
                    event.location != null
                        ? Icons.place_rounded
                        : Icons.schedule_rounded,
                    size: 11,
                    color: kTextMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                      event.location ?? event.startTime ?? 'Toute la journée',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kTextMuted)),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
