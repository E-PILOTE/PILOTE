import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/profile_model.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques « compte » partagées entre « Mon profil » et « Paramètres » du
//  personnel scolaire : libellés de rôle, formatage de dates, carte identité,
//  carte « À propos du compte » et dialog de confirmation de déconnexion.
//  Données : 100 % issues de la ligne `profiles` locale (PowerSync).
// ════════════════════════════════════════════════════════════════════════════

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Libellé français du rôle (personnel scolaire).
String staffRoleLabel(String role) => switch (role) {
      'directeur' => 'Directeur',
      'proviseur' => 'Proviseur',
      'enseignant' => 'Enseignant',
      'cpe' => 'CPE',
      'comptable' => 'Comptable',
      'secretaire' => 'Secrétaire',
      'surveillant' => 'Surveillant',
      'parent' => 'Parent',
      'eleve' => 'Élève',
      'infirmier' => 'Infirmier',
      'responsable_cantine' => 'Resp. Cantine',
      _ => 'Personnel',
    };

/// Initiales pour l'avatar (« Jean Mavoungou » → « JM »).
String staffInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Date + heure : « 9 juin 2026 à 14:32 » — ou « Jamais » si null.
String staffFmtDateTime(DateTime? d) => d == null
    ? 'Jamais'
    : DateFormat("d MMM yyyy 'à' HH:mm", 'fr_FR').format(d.toLocal());

/// Date seule : « 9 juin 2026 » — ou « — » si null.
String staffFmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMMM yyyy', 'fr_FR').format(d.toLocal());

// ─── Titre de section + contenu (mise en page standard des pages compte) ────
class StaffSection extends StatelessWidget {
  const StaffSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(title, icon: icon),
          const SizedBox(height: 12),
          child,
        ],
      );
}

// ─── Carte identité (avatar + nom + badges) ──────────────────────────────────
class StaffIdentityCard extends StatelessWidget {
  const StaffIdentityCard({
    super.key,
    required this.profile,
    this.schoolName,
    this.email,
  });
  final ProfileModel profile;
  final String? schoolName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: kGreen,
          child: Text(staffInitials(profile.fullName),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.fullName.isEmpty ? '—' : profile.fullName,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              if (email != null && email!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(email!,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                AdminBadge(staffRoleLabel(profile.role),
                    color: kGreen, icon: Icons.shield_rounded),
                if (schoolName != null)
                  AdminBadge(schoolName!,
                      color: kNavy, icon: Icons.business_rounded),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Carte « À propos du compte » (lecture seule, ligne profiles locale) ─────
class AboutAccountCard extends StatelessWidget {
  const AboutAccountCard({super.key, required this.profile, this.schoolName});
  final ProfileModel profile;
  final String? schoolName;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AdminCard(
      child: AdminDetailCard([
        AdminDetailRow(Icons.business_rounded, 'École', schoolName ?? '—'),
        AdminDetailRow(
            Icons.shield_rounded, 'Rôle', staffRoleLabel(p.role)),
        AdminDetailRow(Icons.tag_rounded, 'Matricule',
            (p.employeeNumber?.isNotEmpty ?? false) ? p.employeeNumber! : '—'),
        AdminDetailRow(
          Icons.circle,
          'Statut du compte',
          p.isActive ? 'Actif' : 'Inactif',
          valueColor: p.isActive ? kGreen : kRed,
        ),
        AdminDetailRow(Icons.history_rounded, 'Dernière connexion',
            staffFmtDateTime(p.lastLogin)),
        AdminDetailRow(Icons.event_rounded, 'Membre depuis',
            staffFmtDate(p.createdAt), last: true),
      ]),
    );
  }
}

// ─── Confirmation de déconnexion ─────────────────────────────────────────────

/// Ouvre le dialog de confirmation ; renvoie `true` si l'utilisateur confirme.
Future<bool> showLogoutConfirmDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const LogoutConfirmDialog(),
    ) ??
    false;

/// Dialog de confirmation de déconnexion — style admin, bandeau rouge.
class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _DangerDialogHeader(
            title: 'Déconnexion',
            subtitle: 'Confirmer la sortie de votre espace',
            icon: Icons.logout_rounded,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Voulez-vous vraiment vous déconnecter ?\n'
              'Vous devrez saisir à nouveau vos identifiants pour accéder '
              'à votre espace.',
              style:
                  TextStyle(fontSize: 13.5, color: kTextPrimary, height: 1.5),
            ),
          ),
          AdminDialogFooter(
            saving: false,
            submitLabel: 'Se déconnecter',
            submitColor: kRed,
            submitIcon: Icons.logout_rounded,
            onCancel: () => Navigator.of(context).pop(false),
            onSubmit: () => Navigator.of(context).pop(true),
          ),
        ]),
      ),
    );
  }
}

/// Bandeau de dialog « action destructive » : même anatomie que
/// `AdminDialogHeader`, en gradient rouge (réservé aux confirmations).
class _DangerDialogHeader extends StatelessWidget {
  const _DangerDialogHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });
  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(kRed, Colors.black, 0.30) ?? kRed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [dark, kRed]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
        ),
      ]),
    );
  }
}
