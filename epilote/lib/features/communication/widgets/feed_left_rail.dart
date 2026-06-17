import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/feed_people_provider.dart';
import 'comm_text.dart' show roleColor, roleLabelFr;

// ════════════════════════════════════════════════════════════════════════════
//  Rail GAUCHE du feed. Identité & navigation & communauté.
//  100 % dynamique : profil (auth) + périmètre (scope) + membres (presence).
//  Aucune valeur en dur. ListView → jamais d'overflow, scroll sur écran court.
// ════════════════════════════════════════════════════════════════════════════

enum FeedShortcut { all, mine, pinned, saved, agenda }

class FeedLeftRail extends ConsumerWidget {
  const FeedLeftRail({
    super.key,
    required this.active,
    required this.onShortcut,
    this.pinnedCount   = 0,
    this.savedCount    = 0,
    this.upcomingCount = 0,
    this.totalCount    = 0,
    this.mineCount     = 0,
    this.showMine      = false,
  });

  final FeedShortcut? active;
  final ValueChanged<FeedShortcut> onShortcut;
  final int pinnedCount, savedCount, upcomingCount, totalCount, mineCount;
  final bool showMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final ctx     = ref.watch(communicationContextProvider);

    final (scopeLabel, scopeHint, scopeIcon) = switch (ctx.scope) {
      CommScope.platform => (
          'Plateforme nationale',
          'Toutes les écoles',
          Icons.public_rounded
        ),
      CommScope.group => (
          'Réseau scolaire',
          'Votre groupe d\'écoles',
          Icons.hub_rounded
        ),
      CommScope.school => (
          'Mon établissement',
          'Fil de votre école',
          Icons.school_rounded
        ),
    };

    return ListView(
      padding: const EdgeInsets.only(top: 20, left: 2, right: 2, bottom: 20),
      children: [
        _IdentityCard(
          profile   : profile,
          scopeLabel: scopeLabel,
          scopeIcon : scopeIcon,
        ),
        const SizedBox(height: 12),
        _NavCard(
          active        : active,
          totalCount    : totalCount,
          pinnedCount   : pinnedCount,
          savedCount    : savedCount,
          upcomingCount : upcomingCount,
          mineCount     : mineCount,
          showMine      : showMine,
          onShortcut    : onShortcut,
        ),
        const SizedBox(height: 12),
        _CommunityCard(scopeHint: scopeHint),
      ],
    );
  }
}

// ─── Carte identité (design plateforme : AdminCard + avatar + badges) ─────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.scopeLabel,
    required this.scopeIcon,
  });

  final dynamic  profile;
  final String   scopeLabel;
  final IconData scopeIcon;

  @override
  Widget build(BuildContext context) {
    final name   = (profile?.fullName as String?)?.trim() ?? '';
    final role   = profile?.role as String?;
    final avatar = (profile?.avatarUrl as String?)?.trim();
    final color  = roleColor(role);
    final init   = _initials(name.isEmpty ? null : name);

    final initialsCircle = CircleAvatar(
      radius: 26,
      backgroundColor: color,
      child: Text(init,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    );

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null && avatar.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatar,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (_, _) => initialsCircle,
                errorWidget: (_, _, _) => initialsCircle,
              ),
            )
          else
            initialsCircle,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Mon profil' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        height: 1.2)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  AdminBadge(roleLabelFr(role),
                      color: color, icon: Icons.shield_rounded),
                  AdminBadge(scopeLabel, color: kNavy, icon: scopeIcon),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte navigation (compteurs live + bouton publier) ───────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.active,
    required this.onShortcut,
    this.totalCount    = 0,
    this.pinnedCount   = 0,
    this.savedCount    = 0,
    this.upcomingCount = 0,
    this.mineCount     = 0,
    this.showMine      = false,
  });
  final FeedShortcut? active;
  final ValueChanged<FeedShortcut> onShortcut;
  final int totalCount, pinnedCount, savedCount, upcomingCount, mineCount;
  final bool showMine;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          _NavTile(
            icon  : Icons.dynamic_feed_rounded,
            label : 'Toutes les publications',
            badge : totalCount,
            active: active == null,
            onTap : () => onShortcut(FeedShortcut.all),
          ),
          if (showMine)
            _NavTile(
              icon  : Icons.account_circle_rounded,
              label : 'Mes publications',
              badge : mineCount,
              active: active == FeedShortcut.mine,
              color : kAccent,
              onTap : () => onShortcut(FeedShortcut.mine),
            ),
          _NavTile(
            icon  : Icons.push_pin_rounded,
            label : 'Épinglées',
            badge : pinnedCount,
            active: active == FeedShortcut.pinned,
            color : kAccent,
            onTap : () => onShortcut(FeedShortcut.pinned),
          ),
          _NavTile(
            icon  : Icons.bookmark_rounded,
            label : 'Enregistrées',
            badge : savedCount,
            active: active == FeedShortcut.saved,
            color : kNavy,
            onTap : () => onShortcut(FeedShortcut.saved),
          ),
          _NavTile(
            icon  : Icons.event_rounded,
            label : 'Agenda',
            badge : upcomingCount,
            active: active == FeedShortcut.agenda,
            color : kGreen,
            onTap : () => onShortcut(FeedShortcut.agenda),
          ),
        ]),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
    this.color = kNavy,
  });
  final IconData icon;
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  final int badge;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.09) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: active ? color : kTextMuted),
              const SizedBox(width: 11),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? color : kTextPrimary)),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: active ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$badge',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : color)),
                ),
              ],
            ]),
          ),
        ),
      );
}

// ─── Carte communauté (membres + présence) ────────────────────────────────────

class _CommunityCard extends ConsumerWidget {
  const _CommunityCard({required this.scopeHint});
  final String scopeHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async  = ref.watch(communityPeopleProvider);
    final people = async.valueOrNull ?? const <FeedPerson>[];

    final sorted = [...people]..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final online = sorted.where((p) => p.isOnline).length;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.groups_2_rounded, size: 16, color: kNavy),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Communauté',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            if (people.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${people.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              ),
          ]),
          if (online > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Container(
                width: 7, height: 7,
                decoration:
                    const BoxDecoration(color: kGreen, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('$online en ligne',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kGreen)),
            ]),
          ],
          const SizedBox(height: 8),
          if (async.isLoading && sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (sorted.isEmpty)
            _EmptyMini(icon: Icons.groups_outlined, text: scopeHint)
          else
            for (final p in sorted) _PersonRow(person: p),
        ],
      ),
    );
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        ]),
      );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});
  final FeedPerson person;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(person.role);
    final init  = _pInitials(person.name);
    final sub   = (person.subtitle?.trim().isNotEmpty ?? false)
        ? person.subtitle!
        : roleLabelFr(person.role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.28)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(init,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
          if (person.isOnline)
            Positioned(
              right: -1, bottom: -1,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: kGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

String _pInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final p = parts.isNotEmpty ? parts[0] : '?';
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}
