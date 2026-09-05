part of '../admin_users_screen.dart';

// Badges de rôle et de statut, partagés par les trois vues.

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'directeur'       => kNavy,
      'enseignant'      => _kBlue,
      'secretaire'      => _kPurple,
      'comptable'       => kAccent,
      'surveillant'     => _kOrange,
      _                 => kTextMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(roleLabel(role), style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w700,
      ), overflow: TextOverflow.ellipsis),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color),
    const SizedBox(width: 4),
    Flexible(child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
