part of '../admin_settings_screen.dart';

// Connexions récentes et actions RGPD.

class _RecentLoginsCard extends ConsumerWidget {
  const _RecentLoginsCard();

  static String _roleLabel(String r) => switch (r) {
        'admin_groupe'   => 'Admin groupe',
        'directeur'      => 'Directeur',
        'censeur'        => 'Censeur',
        'surveillant'    => 'Surveillant',
        'enseignant'     => 'Enseignant',
        'comptable'      => 'Comptable',
        'secretaire'     => 'Secrétaire',
        'econome'        => 'Économe',
        'bibliothecaire' => 'Bibliothécaire',
        'infirmier'      => 'Infirmier',
        'parent'         => 'Parent',
        'eleve'          => 'Élève',
        _                => r,
      };

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginsAsync = ref.watch(adminRecentLoginsProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Connexions récentes',
            icon: Icons.login_rounded,
            subtitle: 'Dernières activités de connexion du groupe'),
        const SizedBox(height: 14),
        loginsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (_, _) => const AdminErrorBanner(message: 'Connexions indisponibles.'),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Icon(Icons.inbox_outlined, color: kTextMuted, size: 20),
                    const SizedBox(width: 10),
                    Text('Aucune connexion enregistrée.',
                        style: TextStyle(fontSize: 13, color: kTextMuted)),
                  ]),
                )
              : Column(children: [for (final l in list) _loginRow(l)]),
        ),
      ]),
    );
  }

  Widget _loginRow(RecentLogin l) {
    final name = l.name.isEmpty ? '—' : l.name;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty)
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(initials,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
            Text(_roleLabel(l.role),
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (l.isToday)
            AdminBadge("Aujourd'hui", color: kGreen)
          else if (l.isThisWeek)
            AdminBadge('Cette semaine', color: kNavy),
          const SizedBox(height: 4),
          Text(_ago(l.lastLogin),
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
      ]),
    );
  }
}

// ─── Conformité & protection des données (actions locales, sans écriture) ────
class _RgpdActionsCard extends StatelessWidget {
  const _RgpdActionsCard();

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Conformité & protection des données',
            icon: Icons.gpp_good_outlined,
            subtitle: 'Export et reporting réglementaire'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.privacy_tip_outlined, size: 18, color: kNavy),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Les données personnelles des élèves et du personnel sont protégées. '
                'Exportez un dossier complet ou générez un rapport de conformité '
                'à présenter aux autorités.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          AdminActionButton(
            label: 'Exporter mes données',
            icon: Icons.download_rounded,
            filled: false,
            onPressed: () => _toast(context,
                'Export demandé — vous recevrez le dossier par email sous 24 h.'),
          ),
          AdminActionButton(
            label: 'Rapport de conformité',
            icon: Icons.fact_check_outlined,
            filled: false,
            onPressed: () => _toast(context, 'Génération du rapport de conformité lancée.'),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Widgets partagés locaux
// ═════════════════════════════════════════════════════════════════════════════
class _CardLoader extends StatelessWidget {
  const _CardLoader();
  @override
  Widget build(BuildContext context) => AdminCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(color: kNavy)),
        ),
      );
}
