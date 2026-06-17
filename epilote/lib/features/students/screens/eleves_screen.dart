import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../data/models/student_model.dart';
import '../providers/students_provider.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kText   = Color(0xFF0F172A);
const _kMuted  = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

/// Liste des élèves de l'école — offline-first (PowerSync `db.watch`).
class ElevesScreen extends ConsumerStatefulWidget {
  const ElevesScreen({super.key});

  @override
  ConsumerState<ElevesScreen> createState() => _ElevesScreenState();
}

class _ElevesScreenState extends ConsumerState<ElevesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().length >= 2;
    final listAsync = searching
        ? ref.watch(searchStudentsProvider(_query))
        : ref.watch(studentsProvider);
    final countAsync = ref.watch(studentCountProvider);

    return ModuleScaffold(
      slug: 'eleves',
      title: 'Élèves',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barre de recherche + total ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un élève (nom ou matricule)…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
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
                countAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (n) => _CountBadge(count: n),
                ),
              ],
            ),
          ),

          // ── Liste ───────────────────────────────────────────────────────
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: '$e'),
              data: (students) {
                if (students.isEmpty) {
                  return _EmptyState(searching: searching);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _StudentTile(student: students[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge total ────────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            '$count élève${count > 1 ? 's' : ''}',
            style: const TextStyle(
              color: _kNavy, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Ligne élève ──────────────────────────────────────────────────────────────
class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});
  final StudentModel student;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(student.firstName, student.lastName);
    final avatarColor = student.gender == 'F' ? _kGold : _kNavy;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/user/eleves/${student.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor.withValues(alpha: 0.12),
                // Cache disque : la photo reste visible HORS LIGNE après un
                // 1er affichage en ligne ; repli = initiales (offline-first).
                foregroundImage: (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(student.photoUrl!)
                    : null,
                onForegroundImageError: (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                    ? (_, _) {}
                    : null,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: avatarColor, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.lastFirst,
                      style: const TextStyle(
                        color: _kText, fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mat. ${student.matricule}'
                      '${student.age != null ? "  ·  ${student.age} ans" : ""}',
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (student.isBoarder) const _Tag(label: 'Interne', color: _kNavy),
              if (student.hasScholarship) ...[
                const SizedBox(width: 6),
                const _Tag(label: 'Boursier', color: _kGreen),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _kMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    final s = '$f$l'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}

// ─── Petit tag ──────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
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
          Icon(searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            searching
                ? 'Aucun élève ne correspond à la recherche'
                : 'Aucun élève inscrit pour le moment',
            style: const TextStyle(color: _kMuted, fontSize: 14),
          ),
          if (!searching) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.inscriptions),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Inscrire un élève'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kNavy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
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
