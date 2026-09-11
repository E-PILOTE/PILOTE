part of '../school_groups_screen.dart';

// Contenu des onglets, jauge de quota.

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = group;
    // ⚠️ « Email » désignait le CONTACT du formulaire, et se lisait comme un
    // identifiant. Sur les huit administrateurs de la base, aucune des deux
    // adresses ne coïncidait : une connexion a échoué pour ça. Les deux
    // figurent désormais, chacune sous son vrai nom — le compte d'abord,
    // c'est lui qu'on vient chercher pour dépanner quelqu'un.
    final comptes = ref.watch(comptesAdminParGroupeProvider).maybeWhen(
          data: (m) => m[g.id] ?? const <CompteAdmin>[],
          orElse: () => const <CompteAdmin>[],
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        _DetailCard([
          for (final c in comptes)
            _DetailRow(
                Icons.key_rounded,
                comptes.length > 1
                    ? 'Compte · ${c.nom}'
                    : 'Compte de connexion',
                c.actif ? c.email : '${c.email}  (désactivé)'),
          _DetailRow(Icons.email_outlined, 'E-mail de contact', g.adminEmail),
          _DetailRow(Icons.phone_outlined, 'Téléphone', g.phone ?? '—'),
          _DetailRow(Icons.location_on_outlined, 'Département', g.department ?? '—'),
          _DetailRow(Icons.home_outlined, 'Adresse', g.address ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        const _SectionTitle('Paramètres'),
        const SizedBox(height: 8),
        _DetailCard([
          // ⚠️ « Nature » AVANT « Type ». La fiche d'un ministère annonçait
          // « Type : Public » — exact, et trompeur : c'est ce qu'affiche aussi
          // une école publique ordinaire. La première ligne doit dire ce que
          // la chose EST.
          _DetailRow(
              g.administreReferentielNational
                  ? Icons.account_balance_rounded
                  : Icons.corporate_fare_outlined,
              'Nature',
              natureGroupe(estTutelle: g.administreReferentielNational)),
          _DetailRow(Icons.business_outlined, 'Secteur', g.groupTypeLabel),
          // ⚠️ Sur un groupe PUBLIC, on n'affiche pas la ligne du tout : la
          // question ne se pose pas. Sur un groupe privé, « Non renseigné »
          // DIT le manque — c'est une case qu'on peut encore remplir.
          if (caractereSeSaisit(g.groupType))
            _DetailRow(iconeCaractere(g.caractere), 'Caractère',
                libelleCaractereOuManque(g.caractere)),
          // « Non renseignée » plutôt qu'un tiret : l'absence de tutelle est
          // une lacune à combler, pas une case vide sans conséquence — un
          // groupe sans ministère ne remonte dans aucun état ministériel.
          _DetailRow(Icons.account_balance_outlined, 'Tutelle',
              g.tutelleLabel ?? 'Non renseignée'),
          // ⚠️ « Non déclaré », jamais « non agréé » : E-PILOTE enregistre une
          // mention, elle n'instruit aucun dossier.
          _DetailRow(Icons.verified_outlined, 'Agrément',
              !g.aDeclareUnAgrement
                  ? 'Non déclaré'
                  : '${g.agrementNumero}'
                      '${g.agrementType == null ? '' : ' · ${g.agrementType == 'definitif' ? 'définitif' : 'provisoire'}'}'),
          if (g.foundedYear != null)
            _DetailRow(Icons.history_edu_outlined, 'Fondé en',
                g.foundedYear.toString()),
          _DetailRow(Icons.link_outlined, 'Slug', g.slug ?? '—'),
          _DetailRow(Icons.calendar_today_outlined, 'Créé le',
              DateFormat('dd/MM/yyyy').format(g.createdAt)),
          _DetailRow(Icons.update_outlined, 'Mis à jour',
              DateFormat('dd/MM/yyyy').format(g.updatedAt), last: true),
        ]),
        if (g.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          const _SectionTitle('Notes'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Text(g.notes!, style: TextStyle(
                color: _kMuted, fontSize: 13, height: 1.5)),
          ),
        ],
        const SizedBox(height: 14),
        // Méta rapide
        Row(children: [
          Expanded(child: _MetaChip(
            icon: Icons.school_rounded,
            label: '${g.schoolCount} école${g.schoolCount > 1 ? 's' : ''}',
            color: _kNavy,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.people_rounded,
            label: '${g.maxStudents == -1 ? "∞" : g.maxStudents} élèves max',
            color: _kGreen,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.account_balance_wallet_rounded,
            label: '${_fmtXaf(g.priceXaf.toDouble())}/${g.periodSuffix}',
            color: _kGold,
          )),
        ]),
      ]),
    );
  }
}

class _SubscriptionTab extends ConsumerWidget {
  const _SubscriptionTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = group;
    final daysLeft = g.subscriptionEnd?.difference(DateTime.now()).inDays;
    final modulesAsync = ref.watch(groupModuleAccessProvider(g.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Plan actuel
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavy.withValues(alpha: 0.05), _kNavy.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kNavy.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_rounded, color: _kNavy, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Plan ${g.planName}', style: TextStyle(
                  color: _kNavy, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${_fmtXaf(g.priceXaf.toDouble())} / ${g.periodSuffix}',
                  style: TextStyle(color: _kGold, fontSize: 14, fontWeight: FontWeight.w700)),
            ])),
            _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel),
          ]),
        ),
        const SizedBox(height: 20),

        const _SectionTitle('Quotas'),
        const SizedBox(height: 12),

        _QuotaBar(
          label: 'Écoles utilisées',
          used: g.schoolCount,
          max:  g.maxSchools == -1 ? null : g.maxSchools,
          color: _kNavy,
        ),
        const SizedBox(height: 12),
        _QuotaBar(
          label: 'Capacité élèves',
          used: 0,
          max:  g.maxStudents == -1 ? null : g.maxStudents,
          color: _kGreen,
          showUsed: false,
        ),
        const SizedBox(height: 20),

        const _SectionTitle('Période'),
        const SizedBox(height: 12),
        _InfoGrid([
          _InfoItem('Début', g.subscriptionStart != null
              ? DateFormat('dd/MM/yyyy').format(g.subscriptionStart!)
              : '—', Icons.play_circle_rounded),
          _InfoItem('Fin', g.subscriptionEnd != null
              ? DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!)
              : '—', Icons.stop_circle_rounded),
          if (daysLeft != null)
            _InfoItem(
              daysLeft > 0 ? 'Jours restants' : 'Expiré depuis',
              daysLeft > 0 ? '$daysLeft jours' : '${(-daysLeft)} jours',
              Icons.timer_rounded,
            ),
        ]),
        const SizedBox(height: 20),

        // ─ Modules accessibles ────────────────────────────────────────────────
        const _SectionTitle('Modules du plan'),
        const SizedBox(height: 12),
        modulesAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          error: (e, _) => Text(messageErreur(e),
              style: const TextStyle(color: _kRed, fontSize: 12)),
          data: (modules) {
            if (modules.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text('Aucun module configuré dans ce plan.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              );
            }
            final byCategory = <String, List<GroupModuleAccess>>{};
            for (final m in modules) {
              (byCategory[m.categoryName] ??= []).add(m);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: byCategory.entries.map((entry) {
                final accessCount = entry.value.where((m) => m.isAccessible).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(entry.key, style: TextStyle(
                          color: _kNavy, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accessCount > 0 ? _kGreen.withValues(alpha: 0.1) : _kMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$accessCount/${entry.value.length}',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: accessCount > 0 ? _kGreen : _kMuted)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Column(
                          children: entry.value.asMap().entries.map((me) {
                            final mod = me.value;
                            final isLast = me.key == entry.value.length - 1;
                            return Container(
                              decoration: BoxDecoration(
                                border: isLast ? null : Border(
                                  bottom: BorderSide(color: _kBorder),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                leading: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: mod.isAccessible
                                        ? _kGreen.withValues(alpha: 0.1)
                                        : _kMuted.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    mod.isAccessible
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_rounded,
                                    size: 14,
                                    color: mod.isAccessible ? _kGreen : _kMuted,
                                  ),
                                ),
                                title: Text(mod.moduleName, style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: mod.isAccessible ? _kText : _kMuted,
                                )),
                                trailing: mod.isAccessible
                                    ? Text('Actif',
                                        style: TextStyle(
                                          color: _kGreen, fontSize: 11,
                                          fontWeight: FontWeight.w600))
                                    : Text('Verrouillé',
                                        style: TextStyle(
                                          color: _kMuted, fontSize: 11)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TimelineItem(
          icon: Icons.add_circle_rounded,
          color: _kGreen,
          title: 'Groupe créé',
          date: g.createdAt,
        ),
        if (g.subscriptionStart != null)
          _TimelineItem(
            icon: Icons.play_arrow_rounded,
            color: _kNavy,
            title: 'Abonnement démarré — Plan ${g.planName}',
            date: g.subscriptionStart!,
          ),
        if (g.subscriptionEnd != null && g.subscriptionEnd!.isBefore(DateTime.now()))
          _TimelineItem(
            icon: Icons.event_busy_rounded,
            color: _kRed,
            title: 'Abonnement expiré',
            date: g.subscriptionEnd!,
          ),
        _TimelineItem(
          icon: Icons.update_rounded,
          color: _kMuted,
          title: 'Dernière mise à jour',
          date: g.updatedAt,
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(DateFormat('dd MMMM yyyy', 'fr').format(date),
            style: TextStyle(color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.used,
    required this.max,
    required this.color,
    this.showUsed = true,
  });
  final String label;
  final int used;
  final int? max;
  final Color color;
  final bool showUsed;

  @override
  Widget build(BuildContext context) {
    final pct = max != null && max! > 0 ? (used / max!).clamp(0.0, 1.0) : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: _kMuted, fontSize: 12)),
        const Spacer(),
        Text(max == null || max == -1
            ? (showUsed ? '$used / ∞' : 'Illimité')
            : '$used / $max',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: max == null || max == -1 ? 0.1 : pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ─── Bouton Sauvegarder Premium ───────────────────────────────────────────────
