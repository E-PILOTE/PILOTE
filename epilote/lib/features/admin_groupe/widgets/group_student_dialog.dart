import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_students_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE ÉLÈVE — vue MINISTÈRE, lecture seule.
//
//  Ce que cette fiche montre : identité et scolarité. Ce qu'elle ne montre
//  PAS, et ne doit jamais montrer : le médical (groupe sanguin, allergies) et
//  la discipline. Ces données appartiennent à l'établissement ; la plateforme
//  les cloisonne déjà pour son personnel, la même règle s'applique au-dessus.
//  Le pied de fiche le dit à l'utilisateur, pour que ce ne soit pas pris pour
//  un oubli.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showGroupStudentDialog(BuildContext context, GroupStudent s) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _StudentDialog(student: s),
  );
}

class _StudentDialog extends StatelessWidget {
  const _StudentDialog({required this.student});
  final GroupStudent student;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final accent = s.isFemale ? const Color(0xFF7C3AED) : kNavy;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ─ En-tête ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_initials(s.fullName),
                    style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: kTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      AdminBadge(s.isActive ? 'Actif' : 'Inactif',
                          color: s.isActive ? kGreen : kTextMuted,
                          icon: s.isActive
                              ? Icons.check_circle
                              : Icons.pause_circle_outline),
                      if (s.hasScholarship)
                        AdminBadge('Boursier',
                            color: kGreen, icon: Icons.school_rounded),
                      if (s.isUnplaced)
                        AdminBadge('Sans classe',
                            color: kRed, icon: Icons.help_outline_rounded),
                    ]),
                  ],
                ),
              ),
              AdminModalIconBtn(
                icon: Icons.close_rounded,
                color: kTextMuted,
                tooltip: 'Fermer',
                onTap: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // ─ Corps ──────────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminModalSectionTitle('Identité'),
                  const SizedBox(height: 8),
                  AdminDetailCard([
                    AdminDetailRow(Icons.badge_outlined, 'Matricule',
                        s.matricule ?? '—',
                        mono: s.matricule != null),
                    AdminDetailRow(
                        Icons.wc_rounded,
                        'Sexe',
                        switch (s.gender) {
                          'F' => 'Féminin',
                          'M' => 'Masculin',
                          _ => '—',
                        }),
                    AdminDetailRow(
                      Icons.cake_outlined,
                      'Date de naissance',
                      s.dateOfBirth == null
                          ? '—'
                          : DateFormat('dd MMMM yyyy', 'fr')
                              .format(s.dateOfBirth!),
                    ),
                    AdminDetailRow(Icons.hourglass_bottom_rounded, 'Âge',
                        s.age == null ? '—' : '${s.age} ans',
                        last: true),
                  ]),
                  const SizedBox(height: 16),
                  const AdminModalSectionTitle('Scolarité'),
                  const SizedBox(height: 8),
                  AdminDetailCard([
                    AdminDetailRow(Icons.account_balance_rounded,
                        'Établissement', s.schoolName),
                    AdminDetailRow(
                        Icons.map_outlined, 'Département', s.department ?? '—'),
                    AdminDetailRow(
                      Icons.class_outlined,
                      'Classe',
                      s.className ?? 'Aucune inscription cette année',
                      valueColor: s.isUnplaced ? kRed : null,
                    ),
                    AdminDetailRow(
                        Icons.engineering_outlined, 'Filière', s.filiere ?? '—'),
                    AdminDetailRow(Icons.how_to_reg_outlined,
                        'Statut d\'inscription', _statusLabel(s.enrollmentStatus),
                        last: true),
                  ]),
                  const SizedBox(height: 16),
                  _PrivacyNote(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static String _statusLabel(String? s) => switch (s) {
        'active' => 'Inscription active',
        'pending' => 'En attente de validation',
        'validated' => 'Validée',
        'rejected' => 'Rejetée',
        'withdrawn' => 'Retiré',
        'transferred' => 'Transféré',
        null => '—',
        _ => s,
      };

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.shield_outlined, size: 17, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Consultation en lecture seule. Les données médicales et '
              'disciplinaires restent à l\'établissement et ne remontent pas '
              'au niveau du groupe.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}
