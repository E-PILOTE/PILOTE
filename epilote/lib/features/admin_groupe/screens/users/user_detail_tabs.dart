part of '../admin_users_screen.dart';

// Contenu des trois onglets de la fiche.

class _UserInfoTab extends StatelessWidget {
  const _UserInfoTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Identité civile'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.badge_outlined, 'Nom complet', u.fullName),
          AdminDetailRow(Icons.wc_rounded, 'Genre', u.genderLabel),
          AdminDetailRow(Icons.cake_outlined, 'Date de naissance',
              u.dateOfBirth != null ? _fmtDate(u.dateOfBirth) : '—'),
          AdminDetailRow(Icons.location_city_outlined, 'Lieu de naissance',
              (u.birthPlace != null && u.birthPlace!.isNotEmpty) ? u.birthPlace! : '—',
              last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.email_outlined, 'Email', u.email),
          AdminDetailRow(Icons.phone_outlined, 'Téléphone',
              (u.phone != null && u.phone!.isNotEmpty) ? u.phone! : '—'),
          AdminDetailRow(Icons.home_outlined, 'Adresse',
              (u.address != null && u.address!.isNotEmpty) ? u.address! : '—',
              last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Identité système'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.tag_rounded, 'Identifiant', u.id, mono: true),
          AdminDetailRow(Icons.confirmation_number_outlined, 'Matricule',
              (u.employeeNumber != null && u.employeeNumber!.isNotEmpty)
                  ? u.employeeNumber! : '—'),
          AdminDetailRow(Icons.calendar_today_outlined, 'Créé le',
              _fmtDate(u.createdAt), last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
            icon: _userRoleIcon(u.role),
            label: u.roleLbl,
            color: _userRoleColor(u.role),
          )),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
            icon: u.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: u.isActive ? 'Actif' : 'Inactif',
            color: u.isActive ? kGreen : kRed,
          )),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
            icon: Icons.account_balance_rounded,
            label: u.schoolName ?? 'Non assigné',
            color: _kBlue,
          )),
        ]),
      ]),
    );
  }
}

class _UserAccessTab extends StatelessWidget {
  const _UserAccessTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final color = _userRoleColor(u.role);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_userRoleIcon(u.role), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.roleLbl, style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Accès limité à son établissement',
                  style: TextStyle(color: kTextMuted, fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Périmètre d\'accès'),
        const SizedBox(height: 8),
        AdminDetailCard([
          const AdminDetailRow(Icons.shield_rounded, 'Niveau', 'École'),
          AdminDetailRow(Icons.account_balance_outlined, 'Établissement',
              u.schoolName ?? 'Non assigné'),
          AdminDetailRow(Icons.verified_user_outlined, "Profil d'accès",
              u.accessProfileName ?? 'Aucun (rôle par défaut)', last: true),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Statut du compte'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(
              u.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              'État', u.isActive ? 'Compte actif' : 'Compte désactivé',
              valueColor: u.isActive ? kGreen : kRed),
          AdminDetailRow(Icons.login_rounded, 'Dernière connexion',
              _fmtDateTime(u.lastLogin), last: true),
        ]),
      ]),
    );
  }
}

class _UserActivityTab extends StatelessWidget {
  const _UserActivityTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _UserTimelineItem(
          icon: Icons.person_add_rounded,
          color: kGreen,
          title: 'Compte créé',
          subtitle: _fmtDate(u.createdAt),
        ),
        if (u.lastLogin != null)
          _UserTimelineItem(
            icon: Icons.login_rounded,
            color: kNavy,
            title: 'Dernière connexion',
            subtitle: _fmtDateTime(u.lastLogin),
          )
        else
          _UserTimelineItem(
            icon: Icons.login_rounded,
            color: kTextMuted,
            title: 'Aucune connexion enregistrée',
            subtitle: "L'utilisateur ne s'est jamais connecté",
          ),
        if (!u.isActive)
          _UserTimelineItem(
            icon: Icons.block_rounded,
            color: kRed,
            title: 'Compte actuellement désactivé',
            subtitle: "Accès bloqué — l'utilisateur ne peut pas se connecter",
            last: true,
          )
        else
          _UserTimelineItem(
            icon: Icons.verified_rounded,
            color: kGreen,
            title: 'Compte opérationnel',
            subtitle: 'Accès autorisé à la plateforme',
            last: true,
          ),
      ],
    );
  }
}

class _UserTimelineItem extends StatelessWidget {
  const _UserTimelineItem({
    required this.icon, required this.color,
    required this.title, required this.subtitle, this.last = false,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        if (!last)
          Expanded(child: Container(width: 2, color: kBorder)),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 18, top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      )),
    ]),
  );
}

// ─── Formulaire création / édition — redesign complet ────────────────────────
