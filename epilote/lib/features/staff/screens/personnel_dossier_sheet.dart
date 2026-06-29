import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communication/widgets/user_avatar.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../providers/staff_dossier_provider.dart';

part 'personnel_dossier_forms.dart';

const _kSlug = 'personnel';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER RH DE L'AGENT — feuille plein écran : identité étendue (lecture, du
//  compte provisionné par l'admin groupe) + Parcours professionnel & Diplômes
//  (CRUD offline, gérés par l'école). Statut, grade, échelon, catégorie,
//  matricule, spécialité, naissance. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
void showStaffDossier(BuildContext context, String profileId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StaffDossierSheet(profileId: profileId),
  );
}

Color _statusColor(String? s) => switch (s) {
      'fonctionnaire' => kNavy,
      'contractuel' => const Color(0xFF0EA5E9),
      'volontaire' => kGreen,
      'prestataire' => const Color(0xFF7C3AED),
      'stagiaire' => const Color(0xFFF59E0B),
      'benevole' => const Color(0xFF0D9488),
      _ => kTextMuted,
    };

class StaffDossierSheet extends ConsumerWidget {
  const StaffDossierSheet({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffDossierProvider(profileId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (d) {
            if (d == null) {
              return const Center(child: Text('Agent introuvable'));
            }
            return _DossierBody(dossier: d, scroll: scroll);
          },
        ),
      ),
    );
  }
}

class _DossierBody extends ConsumerWidget {
  const _DossierBody({required this.dossier, required this.scroll});
  final StaffDossier dossier;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dossier;
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    return Column(children: [
      const SizedBox(height: 10),
      Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: kBorder, borderRadius: BorderRadius.circular(2))),
      // En-tête identité
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
        child: Row(children: [
          UserAvatarCircle(
              name: d.fullName, role: d.role, avatarUrl: d.avatarUrl, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.fullName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Tag(staffRoleLabel(d.role), kNavy),
                if ((d.employmentStatus ?? '').isNotEmpty)
                  _Tag(employmentStatusLabel(d.employmentStatus),
                      _statusColor(d.employmentStatus)),
              ]),
            ]),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _IdentityCard(d: d),
            const SizedBox(height: 16),
            _CareerSection(
                profileId: d.id,
                canCreate: canCreate,
                canEdit: canEdit,
                canDelete: canDelete),
            const SizedBox(height: 16),
            _DiplomaSection(
                profileId: d.id,
                canCreate: canCreate,
                canEdit: canEdit,
                canDelete: canDelete),
          ],
        ),
      ),
    ]);
  }
}

// ─── Carte identité (lecture) ────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.d});
  final StaffDossier d;

  String? _gradeLine() {
    final parts = [
      if ((d.grade ?? '').isNotEmpty) d.grade!,
      if ((d.echelon ?? '').isNotEmpty) d.echelon!,
      if ((d.category ?? '').isNotEmpty) 'cat. ${d.category!}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _birthLine() {
    final dob = (d.dateOfBirth ?? '').isNotEmpty ? d.dateOfBirth : null;
    final bp = (d.birthPlace ?? '').isNotEmpty ? d.birthPlace : null;
    if (dob == null && bp == null) return null;
    return [?dob, if (bp != null) 'à $bp'].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        _InfoRow(Icons.badge_outlined, 'Matricule', d.employeeNumber),
        _InfoRow(Icons.workspace_premium_outlined, 'Grade', _gradeLine()),
        _InfoRow(Icons.menu_book_outlined, 'Spécialité', d.speciality),
        _InfoRow(Icons.event_available_outlined, 'Prise de service', d.hireDate),
        _InfoRow(Icons.cake_outlined, 'Naissance', _birthLine()),
        _InfoRow(Icons.call_rounded, 'Téléphone', d.phone),
        _InfoRow(Icons.home_outlined, 'Adresse', d.address, last: true),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.last = false});
  final IconData icon;
  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final v = (value ?? '').trim();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: last ? 8 : 0).copyWith(
          top: 8, bottom: last ? 8 : 8),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 17, color: kTextMuted),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: kTextMuted, fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(v.isEmpty ? '—' : v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: v.isEmpty ? kTextMuted : kTextPrimary)),
          ),
        ]),
        if (!last) const Divider(height: 16),
      ]),
    );
  }
}

// ─── Section Parcours professionnel ──────────────────────────────────────────
class _CareerSection extends ConsumerWidget {
  const _CareerSection({
    required this.profileId,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });
  final String profileId;
  final bool canCreate, canEdit, canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffCareerProvider(profileId));
    return _Section(
      icon: Icons.timeline_rounded,
      title: 'Parcours professionnel',
      onAdd: canCreate
          ? () => showCareerForm(context, profileId: profileId)
          : null,
      child: async.when(
        loading: () => const _Loading(),
        error: (e, _) => Text('Erreur : $e'),
        data: (rows) {
          if (rows.isEmpty) return const _Empty('Aucun poste enregistré');
          return Column(
            children: [
              for (final c in rows)
                _CareerCard(
                  entry: c,
                  onEdit: canEdit
                      ? () => showCareerForm(context,
                          profileId: profileId, entry: c)
                      : null,
                  onDelete: canDelete
                      ? () => _confirmDelete(context,
                          'Supprimer « ${c.position} » ?',
                          () => deleteCareerEntry(c.id))
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CareerCard extends StatelessWidget {
  const _CareerCard({required this.entry, this.onEdit, this.onDelete});
  final CareerEntry entry;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final c = entry;
    final period = [
      if ((c.startDate ?? '').isNotEmpty) c.startDate!,
      c.isCurrent ? 'présent' : ((c.endDate ?? '').isNotEmpty ? c.endDate! : ''),
    ].where((e) => e.isNotEmpty).join(' → ');
    return _ItemCard(
      onEdit: onEdit,
      onDelete: onDelete,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(c.position,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          if (c.isCurrent) const _Tag('Actuel', kGreen),
        ]),
        if ((c.organization ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(c.organization!,
              style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
        ],
        if (period.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(period,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: kNavy)),
        ],
        if ((c.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(c.notes!.trim(),
              style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        ],
      ]),
    );
  }
}

// ─── Section Diplômes ────────────────────────────────────────────────────────
class _DiplomaSection extends ConsumerWidget {
  const _DiplomaSection({
    required this.profileId,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });
  final String profileId;
  final bool canCreate, canEdit, canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffDiplomasProvider(profileId));
    return _Section(
      icon: Icons.school_rounded,
      title: 'Diplômes & qualifications',
      onAdd: canCreate
          ? () => showDiplomaForm(context, profileId: profileId)
          : null,
      child: async.when(
        loading: () => const _Loading(),
        error: (e, _) => Text('Erreur : $e'),
        data: (rows) {
          if (rows.isEmpty) return const _Empty('Aucun diplôme enregistré');
          return Column(
            children: [
              for (final dp in rows)
                _DiplomaCard(
                  diploma: dp,
                  onEdit: canEdit
                      ? () => showDiplomaForm(context,
                          profileId: profileId, diploma: dp)
                      : null,
                  onDelete: canDelete
                      ? () => _confirmDelete(
                          context, 'Supprimer « ${dp.title} » ?',
                          () => deleteDiploma(dp.id))
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DiplomaCard extends StatelessWidget {
  const _DiplomaCard({required this.diploma, this.onEdit, this.onDelete});
  final Diploma diploma;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final dp = diploma;
    final sub = [
      if ((dp.field ?? '').isNotEmpty) dp.field!,
      if ((dp.institution ?? '').isNotEmpty) dp.institution!,
      if (dp.yearObtained != null) '${dp.yearObtained}',
    ].join(' · ');
    return _ItemCard(
      onEdit: onEdit,
      onDelete: onDelete,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(dp.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          if ((dp.level ?? '').isNotEmpty) _Tag(dp.level!, const Color(0xFF7C3AED)),
        ]),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ]),
    );
  }
}

// ─── Briques partagées ───────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.onAdd,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, size: 18, color: kNavy),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: kNavy)),
        const Spacer(),
        if (onAdd != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_rounded, color: kNavy),
            tooltip: 'Ajouter',
          ),
      ]),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.child, this.onEdit, this.onDelete});
  final Widget child;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: child),
        if (onEdit != null || onDelete != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: kTextMuted),
            onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
            itemBuilder: (_) => [
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              if (onDelete != null)
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer', style: TextStyle(color: kRed))),
            ],
          ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
}

Future<void> _confirmDelete(
    BuildContext context, String title, Future<void> Function() action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await runModuleWrite(context, action, success: 'Supprimé');
}
