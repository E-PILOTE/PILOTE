part of '../admin_settings_screen.dart';

// Onglet Général : fiche du groupe et préférences.

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(adminGroupProfileProvider);
    final settings = ref.watch(adminGroupSettingsProvider);

    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupProfileProvider);
        ref.invalidate(adminGroupSettingsProvider);
        await Future.wait([
          ref.read(adminGroupProfileProvider.future),
          ref.read(adminGroupSettingsProvider.future),
        ]);
      },
      children: [
        // ── Informations du groupe (lecture seule) ──────────────────────────
        profile.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (g) => _GroupInfoCard(group: g),
        ),
        const SizedBox(height: 20),

        // ── Aperçu temps réel : écoles, utilisateurs, quotas du plan ────────
        const _GroupStatsCard(),
        const SizedBox(height: 20),

        // ── Préférences régionales (persistées dans group_settings.general) ──
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (s) => _GeneralPrefsCard(initial: s.general),
        ),
        const SizedBox(height: 20),

        // ── Paramètres pédagogiques (persistés dans group_settings.general) ─
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (s) => _PedagogyCard(initial: s.general),
        ),
        const SizedBox(height: 20),

        // ── Barème de passage (migration 0107) ──────────────────────────────
        // Distinct des paramètres pédagogiques juste au-dessus, et pour une
        // raison de fond : ceux-ci vivent dans `group_settings`, qui n'est PAS
        // synchronisée sur les postes. Le barème, lui, doit atteindre chaque
        // école hors ligne — il est donc écrit sur `school_groups`.
        const BaremePassageCard(),
        const SizedBox(height: 20),

        // ── Apparence (local, non persisté côté DB) ─────────────────────────
        const _AppearanceCard(),
        const SizedBox(height: 20),

        // ── Partenaires sur les postes (opt-in, Phase 3b) ───────────────────
        const PartnerOptInTile(),
        const SizedBox(height: 20),

        // ── Mon compte ──────────────────────────────────────────────────────
        const _AccountCard(),
        const SizedBox(height: 20),

        // ── Mes demandes au support ──────────────────────────────────────────
        const _SupportHistoryCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GroupInfoCard extends StatelessWidget {
  const _GroupInfoCard({required this.group});
  final GroupProfile? group;

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final g = group;
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle('Informations du groupe',
            icon: Icons.business_rounded,
            trailing: g != null
                ? AdminBadge(g.isActive ? 'Actif' : 'Inactif',
                    color: g.isActive ? kGreen : kTextMuted)
                : null),
        const SizedBox(height: 14),
        if (g == null)
          Text('Aucune information disponible.', style: TextStyle(color: kTextMuted))
        else ...[
          // ── En-tête : logo + nom + badges ──────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GroupLogo(logoUrl: g.logoUrl, name: g.name),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  nomAffichableGroupe(
                    nom: g.name,
                    estMinistere: g.estMinistere,
                    tutelle: g.tutelle,
                  ),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
              // ⚠️ CETTE LIGNE MANQUAIT, ET C'EST LA PLUS IMPORTANTE DE
              // L'ÉCRAN. La fiche du MEPSA annonçait « Public · Institutionnel
              // · Actif » : trois pastilles exactes, et pas une qui dise qu'on
              // regarde un MINISTÈRE DE TUTELLE. C'est son propre écran — si
              // lui ne le dit pas, aucun autre ne le fera.
              if (g.estMinistere) ...[
                const SizedBox(height: 6),
                Text(natureGroupe(estTutelle: true),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: couleurTutelle(g.tutelle))),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (g.estMinistere)
                  BadgeMinistere(estMinistere: true, tutelle: g.tutelle),
                // ⚠️ Ce libellé avait un TROISIÈME vocabulaire à lui seul —
                // « confessionnel », « ministere », « reseau » —, qu'aucune
                // base n'a jamais accepté : l'enum ne connaît que `public` et
                // `prive`. Il lit maintenant le même référentiel que tout le
                // monde.
                AdminBadge(libelleSecteur(g.groupType), color: kNavy,
                    icon: Icons.category_outlined),
                if (libelleCaractere(g.caractere) != null)
                  AdminBadge(libelleCaractere(g.caractere)!, color: kAccent,
                      icon: Icons.groups_rounded),
                AdminBadge(g.planName, color: kAccent, icon: Icons.workspace_premium_outlined),
                AdminBadge(statusLabel(g.subscriptionStatus),
                    color: statusColor(g.subscriptionStatus), icon: Icons.verified_outlined),
                if (g.slug != null && g.slug!.isNotEmpty)
                  AdminBadge('@${g.slug}', color: kTextMuted, icon: Icons.alternate_email_rounded),
              ]),
            ])),
          ]),
          const SizedBox(height: 16),
          // ── bandeau lecture seule ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "Ces informations sont gérées par l'administration de la plateforme. "
                      'Pour toute modification, envoyez une demande ci-dessous.',
                      style: TextStyle(fontSize: 12, color: kTextMuted))),
            ]),
          ),
          const SizedBox(height: 16),
          // ── Grille d'informations responsive (2 colonnes sur grand écran) ──
          _InfoGrid(rows: [
            if (g.department != null)
              _InfoRow(label: 'Département', value: g.department!, icon: Icons.map_outlined),
            if (g.foundedYear != null)
              _InfoRow(label: 'Année de création', value: '${g.foundedYear}', icon: Icons.event_outlined),
            if (g.adminEmail != null)
              _InfoRow(label: 'Email', value: g.adminEmail!, icon: Icons.email_outlined),
            if (g.phone != null)
              _InfoRow(label: 'Téléphone', value: g.phone!, icon: Icons.phone_outlined),
            // ⚠️ « Abonnement » est le mot d'un client mensuel. Un ministère
            // exécute un marché : ses libellés le disent, sur la même ligne.
            _InfoRow(
                label: g.estMinistere ? 'Licence' : 'Plan',
                value: g.planName,
                icon: Icons.workspace_premium_outlined),
            _InfoRow(
                label: g.estMinistere ? 'Statut' : 'Statut abonnement',
                value: statusLabel(g.subscriptionStatus),
                icon: Icons.verified_outlined),
            if (g.subscriptionStart != null)
              _InfoRow(
                  label: g.estMinistere ? 'Début' : 'Début abonnement',
                  value: _fmtDate(g.subscriptionStart),
                  icon: Icons.play_circle_outline_rounded),
            if (g.subscriptionEnd != null)
              _InfoRow(label: 'Fin abonnement', value: _subEndLabel(g.subscriptionEnd!), icon: Icons.event_busy_outlined),
            if (g.address != null)
              _InfoRow(label: 'Adresse', value: g.address!, icon: Icons.location_on_outlined),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  showDialog(context: context, builder: (_) => const _RequestUpdateDialog()),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Demander une modification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  static String _subEndLabel(DateTime end) {
    final days = end.difference(DateTime.now()).inDays;
    final date = _fmtDate(end);
    if (days < 0) return '$date (expiré)';
    if (days == 0) return '$date (aujourd\'hui)';
    return '$date (dans $days j)';
  }
}

// ─── Logo du groupe (lecture seule, school_groups.logo_url) ──────────────────
class _GroupLogo extends StatelessWidget {
  const _GroupLogo({required this.logoUrl, required this.name});
  final String? logoUrl;
  final String name;

  // Règle unique du produit — cf. `initialesEtablissement`. « Groupe Scolaire
  // EDEC » et « Groupe Scolaire Bethel » donnaient tous deux « GS » ici.
  String get _initials => initialesEtablissement(name);

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    final fallback = Center(
      child: Text(_initials,
          style: TextStyle(color: kNavy, fontSize: 24, fontWeight: FontWeight.w900)),
    );
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

// ─── Grille d'infos responsive (1 ou 2 colonnes selon largeur) ───────────────
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 640) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
      }
      final pairs = <Widget>[];
      for (int i = 0; i < rows.length; i += 2) {
        pairs.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: rows[i]),
          const SizedBox(width: 28),
          Expanded(child: i + 1 < rows.length ? rows[i + 1] : const SizedBox()),
        ]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: pairs);
    });
  }
}

class _GeneralPrefsCard extends ConsumerStatefulWidget {
  const _GeneralPrefsCard({required this.initial});
  final GeneralSettings initial;

  @override
  ConsumerState<_GeneralPrefsCard> createState() => _GeneralPrefsCardState();
}

class _GeneralPrefsCardState extends ConsumerState<_GeneralPrefsCard> {
  late GeneralSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _weekDays = [
    (1, 'Lundi'), (7, 'Dimanche'),
  ];

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      // Patch : ne réécrire que les champs régionaux pour ne pas écraser
      // la pédagogie / politique de frais (même blob group_settings.general).
      final current = await ref.read(adminGroupSettingsProvider.future);
      final merged = current.general.copyWith(
        defaultLanguage:        _s.defaultLanguage,
        timezone:               _s.timezone,
        dateFormat:             _s.dateFormat,
        academicYearStartMonth: _s.academicYearStartMonth,
        currencyDisplay:        _s.currencyDisplay,
        weekStartsOn:           _s.weekStartsOn,
      );
      await ref.read(adminSettingsServiceProvider).saveGeneral(merged);
      if (mounted) _toast(context, 'Préférences générales enregistrées.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Préférences régionales',
            icon: Icons.public_rounded,
            subtitle: 'Langue, fuseau, format de date et année scolaire'),
        const SizedBox(height: 8),
        _SettingDropdown<String>(
          label: 'Langue par défaut',
          icon: Icons.translate_rounded,
          value: _s.defaultLanguage,
          items: const [
            DropdownMenuItem(value: 'fr', child: Text('Français')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(defaultLanguage: v)),
        ),
        _SettingDropdown<String>(
          label: 'Fuseau horaire',
          icon: Icons.schedule_rounded,
          value: _s.timezone,
          items: const [
            DropdownMenuItem(value: 'Africa/Brazzaville', child: Text('Brazzaville (GMT+1)')),
            DropdownMenuItem(value: 'Africa/Kinshasa', child: Text('Kinshasa (GMT+1)')),
            DropdownMenuItem(value: 'UTC', child: Text('UTC')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(timezone: v)),
        ),
        _SettingDropdown<String>(
          label: 'Format de date',
          icon: Icons.calendar_month_rounded,
          value: _s.dateFormat,
          items: const [
            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('31/12/2026')),
            DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('2026-12-31')),
            DropdownMenuItem(value: 'dd MMM yyyy', child: Text('31 déc. 2026')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(dateFormat: v)),
        ),
        _SettingDropdown<int>(
          label: "Début de l'année scolaire",
          icon: Icons.school_outlined,
          value: _s.academicYearStartMonth,
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(_months[m - 1])),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(academicYearStartMonth: v)),
        ),
        _SettingDropdown<int>(
          label: 'Premier jour de la semaine',
          icon: Icons.view_week_outlined,
          value: _s.weekStartsOn,
          items: [
            for (final d in _weekDays) DropdownMenuItem(value: d.$1, child: Text(d.$2)),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(weekStartsOn: v)),
        ),
        _SettingDropdown<String>(
          label: 'Affichage de la devise',
          icon: Icons.payments_outlined,
          value: _s.currencyDisplay,
          items: const [
            DropdownMenuItem(value: 'XAF', child: Text('XAF')),
            DropdownMenuItem(value: 'FCFA', child: Text('FCFA')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(currencyDisplay: v)),
        ),
        const SizedBox(height: 16),
        _SaveBar(saving: _saving, onSave: _save, error: _error),
      ]),
    );
  }
}

// ─── Aperçu temps réel : écoles, utilisateurs, quotas du plan ────────────────
