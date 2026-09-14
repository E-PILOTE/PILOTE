part of '../admin_settings_screen.dart';

// Onglet Sécurité : politique de mot de passe et sessions.

class _SecurityTab extends ConsumerWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminGroupSettingsProvider);
    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupSettingsProvider);
        ref.invalidate(adminRecentLoginsProvider);
        await ref.read(adminGroupSettingsProvider.future);
      },
      children: [
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (s) => _SecurityCard(initial: s.security),
        ),
        const SizedBox(height: 20),
        const _RecentLoginsCard(),
        const SizedBox(height: 20),
        const _RgpdActionsCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SecurityCard extends ConsumerStatefulWidget {
  const _SecurityCard({required this.initial});
  final SecuritySettings initial;

  @override
  ConsumerState<_SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends ConsumerState<_SecurityCard> {
  late SecuritySettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).saveSecurity(_s);
      if (mounted) _toast(context, 'Paramètres de sécurité enregistrés.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Politique de mot de passe',
              icon: Icons.password_rounded),
          const SizedBox(height: 4),
          _NumberStepper(
            icon: Icons.straighten_rounded,
            title: 'Longueur minimale',
            subtitle: 'Nombre de caractères requis',
            value: _s.minPasswordLength,
            min: 6,
            max: 32,
            suffix: 'car.',
            onChanged: (v) => setState(() => _s = _s.copyWith(minPasswordLength: v)),
          ),
          _ToggleRow(
            icon: Icons.shield_outlined,
            title: 'Mot de passe robuste',
            subtitle: 'Majuscule, chiffre et caractère spécial',
            value: _s.requireStrongPassword,
            onChanged: (v) => setState(() => _s = _s.copyWith(requireStrongPassword: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Authentification & sessions ────────────────────────────────────────
      //
      // ⚠️ CETTE SECTION PROPOSAIT QUATRE RÉGLAGES QUE RIEN N'APPLIQUAIT.
      // « Double authentification (2FA) », « Sessions multiples », « Expiration
      // de session », « Verrouillage après échecs » : les valeurs partaient
      // bien dans `group_settings.security`, et AUCUN code Dart, AUCUNE
      // fonction en base ne les lisait — vérifié des deux côtés le 2026-09-05.
      //
      // La pire des quatre était la 2FA : un administrateur de ministère
      // pouvait l'activer et croire ses comptes protégés par un second facteur
      // qui n'existe nulle part dans le produit. C'est le défaut que la section
      // « Conservation » ci-dessous a déjà connu, mot pour mot.
      //
      // On ne remplace pas une case morte par une autre : ce bloc dit ce que la
      // plateforme protège RÉELLEMENT, et où le régler quand c'est réglable.
      const _ProtectionsReelles(),
      const SizedBox(height: 20),
      // ── Conservation des données ───────────────────────────────────────────
      //
      // ⚠️ CETTE SECTION PROPOSAIT QUATRE RÉGLAGES QUE RIEN NE LISAIT.
      // « Rétention des dossiers » (60 mois par défaut), « Rétention des
      // journaux » (24 mois), « Archivage automatique » et son seuil : les
      // valeurs partaient bien dans `group_settings`, et AUCUN code, nulle
      // part, ne s'en servait. Un administrateur réglait la conservation des
      // dossiers d'élèves d'un ministère et croyait la plateforme tenue par
      // son choix.
      //
      // Une case qui ne fait rien est pire qu'une case absente : elle fait
      // prendre une décision qui n'aura pas lieu. La section dit maintenant ce
      // que la plateforme TIENT réellement (migration 0145).
      const _ConservationCard(),
      const SizedBox(height: 20),
      _SaveBar(saving: _saving, onSave: _save, error: _error),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Connexions récentes (lecture seule, profiles.last_login) ────────────────

// ─── Ce que la plateforme protège vraiment ───────────────────────────────────
class _ProtectionsReelles extends StatelessWidget {
  const _ProtectionsReelles();

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Authentification & sessions',
            icon: Icons.verified_user_outlined),
        const SizedBox(height: 4),
        Text(
          "Ce que la plateforme applique aujourd'hui. Rien ici ne se règle "
          'depuis cet écran : ce sont des comportements du produit, pas des '
          'cases à cocher.',
          style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        const _Protection(
          icone: Icons.password_rounded,
          titre: 'Mot de passe',
          detail: "La politique ci-dessus s'applique aux trois endroits où un "
              "mot de passe se pose : création d'un compte, réinitialisation "
              "par un administrateur, changement par l'intéressé.",
        ),
        const _Protection(
          icone: Icons.devices_other_outlined,
          titre: 'Sessions',
          detail: 'Un compte peut rester ouvert sur plusieurs appareils. '
              'Chacun ferme ses sessions à distance depuis « Mon profil » — y '
              "compris celle du poste qu'il vient de quitter.",
        ),
        const _Protection(
          icone: Icons.lock_clock_outlined,
          titre: 'Postes partagés',
          detail: 'Le verrouillage automatique après inactivité se règle PAR '
              'APPAREIL (2, 5, 10 minutes ou jamais), et cinq codes faux '
              "ouvrent une pause qui s'allonge à chaque essai.",
        ),
        const _Protection(
          icone: Icons.phonelink_lock_outlined,
          titre: 'Double authentification',
          detail: "Non disponible. Le second facteur n'est pas implémenté : "
              "l'annoncer comme actif donnerait une fausse assurance.",
          absente: true,
        ),
      ]),
    );
  }
}

class _Protection extends StatelessWidget {
  const _Protection({
    required this.icone,
    required this.titre,
    required this.detail,
    this.absente = false,
  });

  final IconData icone;
  final String titre;
  final String detail;

  /// Ce que la plateforme NE fait pas. Le dire vaut mieux que le taire : sans
  /// cette ligne, l'absence de second facteur se lirait comme un oubli
  /// d'affichage, et l'on continuerait de la croire acquise.
  final bool absente;

  @override
  Widget build(BuildContext context) {
    final couleur = absente ? kTextMuted : kNavy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icone, size: 17, color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(titre,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              if (absente) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kTextMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('non disponible',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: kTextMuted)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(detail,
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
