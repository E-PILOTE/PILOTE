import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../data/models/class_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../providers/class_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kRed    = Color(0xFFDC2626);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kMuted  = Color(0xFF64748B);

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ModuleScaffold(
      slug: 'classes',
      title: 'Classes',
      child: _ClassesBody(),
    );
  }
}

class _ClassesBody extends ConsumerWidget {
  const _ClassesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final activeYear   = ref.watch(activeYearProvider);
    final readOnly     = ref.watch(yearReadOnlyProvider);

    return classesAsync.when(
      loading: () => const LoadingWidget(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data:    (classes) => _ClassesList(
        classes:   classes,
        yearLabel: activeYear?.label ?? '—',
        readOnly:  readOnly,
      ),
    );
  }
}

// ─── Liste ────────────────────────────────────────────────────────────────────

class _ClassesList extends ConsumerWidget {
  const _ClassesList({
    required this.classes,
    required this.yearLabel,
    required this.readOnly,
  });

  final List<ClassModel> classes;
  final String           yearLabel;
  final bool             readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalEleves = classes.fold<int>(
      0, (sum, c) => sum + (c.studentCount ?? 0));
    final totalCapacity = classes.fold<int>(
      0, (sum, c) => sum + (c.capacity ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ───────────────────────────────────────────────────────
        _Header(yearLabel: yearLabel, classCount: classes.length, readOnly: readOnly),

        // ── Bande statistiques ────────────────────────────────────────────
        _StatsBar(
          classCount:    classes.length,
          totalEleves:   totalEleves,
          totalCapacity: totalCapacity,
        ),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: classes.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: classes.length,
                  itemBuilder: (context, i) => _ClassCard(
                    classe: classes[i],
                    onTap:  () => context.push(
                      Routes.classeDetail.replaceFirst(':id', classes[i].id),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── En-tête ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.yearLabel, required this.classCount, required this.readOnly});
  final String yearLabel;
  final int    classCount;
  final bool   readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      color: _kCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Année $yearLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$classCount classe${classCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ),
          if (readOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBC04).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_clock_rounded, size: 15, color: Color(0xFFB45309)),
                SizedBox(width: 6),
                Text('Lecture seule',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E))),
              ]),
            )
          else
            PermissionGate(
              slug: 'classes',
              action: 'create',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kNavy),
                onPressed: () => _showCreateClassDialog(context),
                icon:  const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle classe'),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateClassDialog(),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.classCount,
    required this.totalEleves,
    required this.totalCapacity,
  });
  final int classCount;
  final int totalEleves;
  final int totalCapacity;

  @override
  Widget build(BuildContext context) {
    final fillPct = totalCapacity > 0
        ? ((totalEleves / totalCapacity) * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Stat(label: 'Classes',    value: '$classCount',      icon: Icons.class_rounded),
          _kDivider,
          _Stat(label: 'Élèves',     value: '$totalEleves',     icon: Icons.people_rounded),
          _kDivider,
          _Stat(label: 'Occupation', value: '$fillPct%',        icon: Icons.bar_chart_rounded),
        ],
      ),
    );
  }

  static const _kDivider = VerticalDivider(
    color: Colors.white24,
    thickness: 1,
    indent: 4,
    endIndent: 4,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String   label;
  final String   value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(
                color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Carte classe ─────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classe, required this.onTap});
  final ClassModel    classe;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    final fill   = classe.fillRate ?? 0.0;
    final isOver = fill > 1.0;
    final fillColor = isOver ? _kRed
        : fill > 0.85 ? _kGold
        : _kGreen;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom + flèche
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.class_rounded,
                        color: _kNavy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(classe.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                            )),
                        if (classe.room != null && classe.room!.isNotEmpty)
                          Text('Salle ${classe.room}',
                              style: const TextStyle(
                                  fontSize: 12, color: _kMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: _kMuted, size: 20),
                ],
              ),
              const SizedBox(height: 12),

              // Méta : élèves + prof principal
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.people_rounded,
                    label: classe.fillRateLabel,
                    color: fillColor,
                  ),
                  const SizedBox(width: 8),
                  if (classe.teacherName != null)
                    _MetaChip(
                      icon: Icons.person_rounded,
                      label: classe.teacherName!,
                      color: _kMuted,
                    ),
                ],
              ),

              // Barre de remplissage
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fill.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(fillColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── États vide / erreur ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Aucune classe',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kText)),
          const SizedBox(height: 8),
          Text('Créez la première classe pour cette année scolaire.',
              style: TextStyle(color: Colors.grey.shade500)),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: _kRed),
            const SizedBox(height: 12),
            const Text('Erreur de chargement',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: _kMuted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog création classe ───────────────────────────────────────────────────

class _CreateClassDialog extends ConsumerStatefulWidget {
  const _CreateClassDialog();

  @override
  ConsumerState<_CreateClassDialog> createState() =>
      _CreateClassDialogState();
}

class _CreateClassDialogState
    extends ConsumerState<_CreateClassDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _capCtrl  = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle classe'),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la classe *',
                  hintText: 'Ex: 6ème A, Terminale D',
                  prefixIcon: Icon(Icons.class_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacité max',
                  hintText: 'Ex: 45',
                  prefixIcon: Icon(Icons.people_rounded),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Salle',
                  hintText: 'Ex: B12',
                  prefixIcon: Icon(Icons.room_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kNavy),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile  = ref.read(authNotifierProvider).valueOrNull;
    final year     = ref.read(activeYearProvider);

    if (profile?.schoolId == null || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Aucune école ou année académique active.')),
      );
      return;
    }
    if (ref.read(yearReadOnlyProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Année archivée — création impossible (lecture seule).')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await createClass(
        schoolId:       profile!.schoolId!,
        groupId:        profile.groupId ?? '',
        academicYearId: year.id,
        name:           _nameCtrl.text.trim(),
        capacity:       int.tryParse(_capCtrl.text.trim()),
        room:           _roomCtrl.text.trim().isEmpty
            ? null : _roomCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
