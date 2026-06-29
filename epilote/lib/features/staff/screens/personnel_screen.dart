import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../communication/widgets/user_avatar.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../providers/staff_directory_provider.dart';
import 'personnel_dossier_sheet.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1E3A5F);
const _kGreen = Color(0xFF009A44);
const _kText = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

/// Couleur d'accent par catégorie métier (cohérence avec l'organigramme).
Color _catColor(StaffCategory c) => switch (c) {
      StaffCategory.direction => _kNavy,
      StaffCategory.administration => const Color(0xFF7C3AED),
      StaffCategory.enseignement => const Color(0xFF0EA5E9),
      StaffCategory.vieScolaire => _kGreen,
      StaffCategory.autres => _kMuted,
    };

IconData _catIcon(StaffCategory c) => switch (c) {
      StaffCategory.direction => Icons.workspace_premium_rounded,
      StaffCategory.administration => Icons.badge_rounded,
      StaffCategory.enseignement => Icons.menu_book_rounded,
      StaffCategory.vieScolaire => Icons.health_and_safety_rounded,
      StaffCategory.autres => Icons.groups_rounded,
    };

/// Annuaire du personnel de l'école — offline-first (lecture seule).
/// Les comptes sont provisionnés en ligne par l'admin groupe ; l'édition RH
/// (contrat / salaire) viendra avec le module Paie (Phase 5).
class PersonnelScreen extends ConsumerStatefulWidget {
  const PersonnelScreen({super.key});

  @override
  ConsumerState<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends ConsumerState<PersonnelScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  StaffCategory? _filter; // null = toutes les catégories

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffDirectoryProvider);

    return ModuleScaffold(
      slug: 'personnel',
      title: 'Personnel',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (all) {
          // Compteurs par catégorie (sur l'ensemble, avant filtres).
          final counts = <StaffCategory, int>{};
          for (final s in all) {
            final c = staffCategory(s.role);
            counts[c] = (counts[c] ?? 0) + 1;
          }

          // Filtrage : recherche + catégorie active.
          final q = _query.trim().toLowerCase();
          final filtered = [
            for (final s in all)
              if ((_filter == null || staffCategory(s.role) == _filter) &&
                  (q.isEmpty || s.searchBlob.contains(q)))
                s,
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(
                controller: _searchCtrl,
                query: _query,
                total: all.length,
                onChanged: (v) => setState(() => _query = v),
                onClear: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
              _CategoryChips(
                counts: counts,
                active: _filter,
                onSelect: (c) => setState(() => _filter = c),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(searching: q.isNotEmpty || _filter != null)
                    : _DirectoryList(staff: filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Barre de recherche + total ─────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.total,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final String query;
  final int total;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, matricule, rôle)…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: onClear,
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kNavy, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, size: 16, color: _kNavy),
                const SizedBox(width: 6),
                Text(
                  '$total agent${total > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: _kNavy, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Puces de filtre par catégorie ──────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.counts,
    required this.active,
    required this.onSelect,
  });
  final Map<StaffCategory, int> counts;
  final StaffCategory? active;
  final ValueChanged<StaffCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final present = [
      for (final c in staffCategoryOrder)
        if ((counts[c] ?? 0) > 0) c,
    ];
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Chip(
            label: 'Tous',
            color: _kNavy,
            selected: active == null,
            onTap: () => onSelect(null),
          ),
          for (final c in present) ...[
            const SizedBox(width: 8),
            _Chip(
              label: '${staffCategoryLabel(c)} (${counts[c]})',
              color: _catColor(c),
              selected: active == c,
              onTap: () => onSelect(active == c ? null : c),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : _kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _kMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Liste groupée par catégorie ────────────────────────────────────────────────
class _DirectoryList extends StatelessWidget {
  const _DirectoryList({required this.staff});
  final List<StaffMember> staff;

  @override
  Widget build(BuildContext context) {
    // Regroupe par catégorie, dans l'ordre organigramme.
    final byCat = <StaffCategory, List<StaffMember>>{};
    for (final s in staff) {
      byCat.putIfAbsent(staffCategory(s.role), () => []).add(s);
    }
    final sections = [
      for (final c in staffCategoryOrder)
        if (byCat[c] != null) (c, byCat[c]!),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final (cat, members) = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 10),
              child: Row(children: [
                Icon(_catIcon(cat), size: 15, color: _catColor(cat)),
                const SizedBox(width: 8),
                Text(
                  '${staffCategoryLabel(cat).toUpperCase()}  ·  ${members.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _kMuted,
                  ),
                ),
              ]),
            ),
            for (final s in members) ...[
              _StaffTile(staff: s),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ─── Ligne d'un agent ─────────────────────────────────────────────────────────
class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.staff});
  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final cat = staffCategory(staff.role);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStaffSheet(context, staff),
        child: Opacity(
          opacity: staff.isActive ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                UserAvatarCircle(
                  name: staff.fullName,
                  role: staff.role,
                  avatarUrl: staff.avatarUrl,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.lastFirst,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        _RoleBadge(role: staff.role, color: _catColor(cat)),
                        if (staff.phone != null && staff.phone!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.call_rounded,
                              size: 12, color: _kMuted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              staff.phone!,
                              style: const TextStyle(
                                  color: _kMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                if (!staff.isActive)
                  const _Pill(label: 'Inactif', color: _kMuted),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: _kMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.color});
  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        staffRoleLabel(role),
        style: TextStyle(
            color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Fiche détail : dossier RH riche (identité + carrière + diplômes) ─────────
void _showStaffSheet(BuildContext context, StaffMember s) {
  showStaffDossier(context, s.id);
}

// ─── États vides / erreur ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(searching ? Icons.search_off_rounded : Icons.groups_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            searching
                ? 'Aucun agent ne correspond'
                : 'Aucun membre du personnel',
            style: const TextStyle(color: _kMuted, fontSize: 14),
          ),
          if (!searching) ...[
            const SizedBox(height: 6),
            const Text(
              'Les comptes du personnel sont créés par\nl\'administrateur de votre groupe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Erreur de chargement\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
