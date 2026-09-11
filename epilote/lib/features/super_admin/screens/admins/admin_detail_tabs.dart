part of '../administrators_screen.dart';

// Contenu des onglets, badges et lignes de détail.

class _AdmInfoTab extends StatelessWidget {
  const _AdmInfoTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _AdmSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.email_outlined, 'Email', a.email, copyable: true),
          _AdmDetailRow(Icons.phone_outlined, 'Téléphone', a.phone ?? '—'),
          _AdmDetailRow(Icons.badge_outlined, 'Nom complet', a.fullName,
              last: true),
        ]),
        const SizedBox(height: 14),
        const _AdmSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.tag_rounded, 'UUID', a.id, copyable: true,
              mono: true),
          _AdmDetailRow(Icons.confirmation_number_outlined, 'Référence',
              a.id.substring(0, 8).toUpperCase()),
          _AdmDetailRow(Icons.calendar_today_outlined, 'Créé le',
              _fmtDate(a.createdAt)),
          _AdmDetailRow(Icons.update_outlined, 'Mis à jour',
              _fmtDate(a.updatedAt), last: true),
        ]),
        const SizedBox(height: 14),
        // Méta rapide
        Row(children: [
          Expanded(child: _AdmMetaChip(
            icon: _roleIcon(a.role),
            label: a.roleLabel,
            color: _roleColor(a.role),
          )),
          const SizedBox(width: 8),
          Expanded(child: _AdmMetaChip(
            icon: a.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: a.isActive ? 'Actif' : 'Inactif',
            color: a.isActive ? _kGreen : _kRed,
          )),
          const SizedBox(width: 8),
          Expanded(child: _AdmMetaChip(
            icon: Icons.business_rounded,
            label: a.groupName ??
                (a.role == 'super_admin' ? 'Plateforme' : 'Non assigné'),
            color: _kGold,
          )),
        ]),
      ]),
    );
  }
}

// ─── Onglet Rôle & Accès ────────────────────────────────────────────────────

class _AdmAccessTab extends StatelessWidget {
  const _AdmAccessTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    final color = _roleColor(a.role);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Carte rôle principale
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_roleIcon(a.role), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(a.roleLabel, style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                a.role == 'super_admin'
                    ? 'Accès total à la plateforme'
                    : 'Accès limité à son groupe scolaire',
                style: TextStyle(color: _kMuted, fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ])),
            _AdmStatusBadge(isActive: a.isActive),
          ]),
        ),
        const SizedBox(height: 20),

        const _AdmSectionTitle('Périmètre d\'accès'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(Icons.shield_rounded, 'Niveau',
              a.role == 'super_admin' ? 'Plateforme globale' : 'Groupe scolaire'),
          _AdmDetailRow(Icons.data_usage_rounded, 'Données',
              a.role == 'super_admin'
                  ? 'Toutes les écoles & groupes'
                  : 'Écoles du groupe assigné'),
          _AdmDetailRow(Icons.business_rounded, 'Groupe',
              a.groupName ??
                  (a.role == 'super_admin' ? 'Plateforme E-PILOTE' : 'Non assigné'),
              last: true),
        ]),
        const SizedBox(height: 20),

        const _AdmSectionTitle('Statut du compte'),
        const SizedBox(height: 8),
        _AdmDetailCard([
          _AdmDetailRow(
            a.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            'État', a.isActive ? 'Compte actif' : 'Compte désactivé'),
          _AdmDetailRow(Icons.login_rounded, 'Dernière connexion',
              _fmtDateTime(a.lastLogin), last: true),
        ]),
      ]),
    );
  }
}

// ─── Onglet Activité ────────────────────────────────────────────────────────

class _AdmActivityTab extends StatelessWidget {
  const _AdmActivityTab({required this.admin});
  final AdminDetail admin;

  @override
  Widget build(BuildContext context) {
    final a = admin;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _AdmTimelineItem(
          icon: Icons.person_add_rounded,
          color: _kGreen,
          title: 'Compte créé',
          date: a.createdAt,
        ),
        if (a.lastLogin != null)
          _AdmTimelineItem(
            icon: Icons.login_rounded,
            color: _kNavy,
            title: 'Dernière connexion',
            date: a.lastLogin!,
          ),
        _AdmTimelineItem(
          icon: Icons.update_rounded,
          color: _kMuted,
          title: 'Dernière mise à jour du profil',
          date: a.updatedAt,
        ),
        if (!a.isActive)
          _AdmTimelineItem(
            icon: Icons.block_rounded,
            color: _kRed,
            title: 'Compte actuellement désactivé',
            date: a.updatedAt,
          ),
      ],
    );
  }
}

// ─── Helpers modal détail (style groupe scolaire) ────────────────────────────

class _AdmStatusBadge extends StatelessWidget {
  const _AdmStatusBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _AdmDetailCard extends StatelessWidget {
  const _AdmDetailCard(this.rows);
  final List<_AdmDetailRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _AdmDetailRow extends StatelessWidget {
  const _AdmDetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11.5 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copier',
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copié : $value'),
                    backgroundColor: _kNavy,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

class _AdmMetaChip extends StatelessWidget {
  const _AdmMetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(
          color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _AdmSectionTitle extends StatelessWidget {
  const _AdmSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _AdmTimelineItem extends StatelessWidget {
  const _AdmTimelineItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.date,
  });
  final IconData icon;
  final Color color;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(_fmtDate(date), style: TextStyle(
            color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────
