import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/subject_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/subjects_provider.dart';

const _kSlug   = 'matieres';
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kRed    = Color(0xFFEF4444);
const _kMuted  = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF0F4F8);

/// Module Matières (catalogue `matieres`) — offline-first, gated par profil.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ModuleScaffold(
      slug: _kSlug,
      title: 'Matières',
      child: _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Matières enseignées',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kNavy)),
                SizedBox(height: 4),
                Text('Catalogue des matières de l\'établissement et leurs coefficients',
                    style: TextStyle(fontSize: 13, color: _kMuted)),
              ]),
            ),
            PermissionGate(
              slug: _kSlug,
              action: 'create',
              child: FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle matière'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: _kRed))),
            data: (subjects) {
              if (subjects.isEmpty) return const _Empty();
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SubjectCard(subject: subjects[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {SubjectModel? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _SubjectDialog(existing: existing),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.menu_book_rounded, size: 56, color: _kMuted),
          SizedBox(height: 12),
          Text('Aucune matière',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy)),
          SizedBox(height: 4),
          Text('Ajoutez les matières enseignées dans votre établissement.',
              style: TextStyle(fontSize: 13, color: _kMuted)),
        ]),
      );
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.subject});
  final SubjectModel subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.menu_book_rounded, color: _kNavy, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(subject.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('Coef. ${subject.coefficient}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen)),
        ),
        PermissionGate(
          slug: _kSlug,
          action: 'update',
          child: IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_rounded, size: 18, color: _kMuted),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _SubjectDialog(existing: subject),
            ),
          ),
        ),
        PermissionGate(
          slug: _kSlug,
          action: 'delete',
          child: IconButton(
            tooltip: 'Archiver',
            icon: const Icon(Icons.archive_rounded, size: 18, color: _kRed),
            onPressed: () => _confirmArchive(context, ref),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver cette matière ?'),
        content: Text('« ${subject.name} » ne sera plus proposée. '
            'Les notes existantes sont conservées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(
      context,
      () => archiveSubject(subject.id),
      success: 'Matière archivée',
    );
  }
}

// ─── Formulaire création / édition ──────────────────────────────────────────
class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog({this.existing});
  final SubjectModel? existing;

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late int _coef = widget.existing?.coefficient ?? 1;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Modifier la matière' : 'Nouvelle matière',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
              const SizedBox(height: 18),
              const Text('Nom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: _deco('Ex. Mathématiques'),
              ),
              const SizedBox(height: 14),
              const Text('Coefficient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              Row(children: [
                _StepBtn(icon: Icons.remove_rounded, onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
                Expanded(
                  child: Center(
                    child: Text('$_coef',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kNavy)),
                  ),
                ),
                _StepBtn(icon: Icons.add_rounded, onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kMuted,
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Enregistrer' : 'Créer'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
      );

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le nom est requis'), backgroundColor: _kRed));
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || schoolId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('École introuvable'), backgroundColor: _kRed));
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (widget.existing != null) {
          await updateSubject(id: widget.existing!.id, name: _name.text, coefficient: _coef);
        } else {
          await createSubject(groupId: groupId, schoolId: schoolId, name: _name.text, coefficient: _coef);
        }
      },
      success: widget.existing != null ? 'Matière mise à jour' : 'Matière créée',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 18, color: _kNavy),
        ),
      );
}
