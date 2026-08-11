part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PRÉPARATION PAR ÉCOLE — la table qui dit qui a fait le travail.
//
//  Elle rendait 1 000 lignes d'un coup dans une Column, sans tri ni recherche :
//  illisible à l'échelle visée, et coûteux à chaque rebuild. Trois changements :
//  virtualisation (ListView.builder borné), tri par colonne, recherche — et
//  surtout de quoi AGIR sur ce qu'on lit, en relançant les retardataires.
// ════════════════════════════════════════════════════════════════════════════

enum _AdoptTri { nom, departement, classes, eleves, etat }

final _adoptQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _adoptTriProvider =
    StateProvider.autoDispose<_AdoptTri>((ref) => _AdoptTri.eleves);
final _adoptDescProvider = StateProvider.autoDispose<bool>((ref) => true);

class _SchoolAdoptionCard extends ConsumerWidget {
  const _SchoolAdoptionCard({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearAnalyticsProvider(year.id));
    final a = async.valueOrNull;

    final q = ref.watch(_adoptQueryProvider).trim().toLowerCase();
    final tri = ref.watch(_adoptTriProvider);
    final desc = ref.watch(_adoptDescProvider);

    // `[...]` : on ne trie JAMAIS la liste du provider en place — c'est
    // exactement le bug qui cassait l'ordre chronologique du graphe d'évolution.
    final rows = <YearSchoolStat>[...?a?.bySchool];
    final filtres = q.isEmpty
        ? rows
        : rows
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.department.toLowerCase().contains(q))
            .toList();

    filtres.sort((x, y) {
      final c = switch (tri) {
        _AdoptTri.nom => x.name.toLowerCase().compareTo(y.name.toLowerCase()),
        _AdoptTri.departement => x.department.compareTo(y.department),
        _AdoptTri.classes => x.classes.compareTo(y.classes),
        _AdoptTri.eleves => x.eleves.compareTo(y.eleves),
        _AdoptTri.etat => (x.adopted ? 1 : 0).compareTo(y.adopted ? 1 : 0),
      };
      return desc ? -c : c;
    });

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Préparation par école',
            icon: Icons.account_tree_rounded,
            subtitle: "État d'adoption de l'année ${year.label} — "
                'cliquez une ligne pour ouvrir son département',
            trailing: a == null
                ? null
                : AdminBadge('${a.ecolesPreparees}/${a.ecolesTotal} prêtes',
                    color: a.ecolesPreparees == a.ecolesTotal
                        ? kGreen
                        : kAccent),
          ),
          const SizedBox(height: 12),
          if (async.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          // ⚠️ L'ERREUR AVANT LE VIDE. Cette carte affichait « Aucune école
          // active dans le groupe » dès que `valueOrNull` valait `null` — donc
          // aussi quand la RPC avait échoué. Sur un réseau congolais coupé, la
          // page annonçait au ministère que son réseau était vide.
          else if (async.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _ChartError(
                quoi: "l'état de préparation des écoles",
                onRetry: () =>
                    ref.invalidate(adminYearAnalyticsProvider(year.id)),
              ),
            )
          else if (a == null || a.bySchool.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: _ChartEmpty(message: 'Aucune école active dans le groupe.'),
            )
          else ...[
            _AdoptionToolbar(year: year, analytics: a, affiche: filtres.length),
            const SizedBox(height: 12),
            const _AdoptionHeaderRow(),
            Divider(height: 14, color: kBorder),
            if (filtres.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text('Aucun établissement ne correspond à « $q ».',
                      style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                ),
              )
            else
              // Hauteur bornée + ListView.builder : seules les lignes visibles
              // sont construites. Indispensable à 1 000 écoles.
              //
              // La barre de défilement est TOUJOURS visible quand la liste
              // dépasse : sans elle, une table écrêtée à 520 px ressemble à une
              // table complète, et personne ne devine qu'il reste neuf cents
              // établissements en dessous.
              SizedBox(
                height: (filtres.length * 38.0).clamp(38.0, 520.0),
                child: Scrollbar(
                  thumbVisibility: filtres.length * 38.0 > 520,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(right: 8),
                    itemCount: filtres.length,
                    itemExtent: 38,
                    itemBuilder: (_, i) => _AdoptionRow(
                      school: filtres[i],
                      // Chaque ligne ouvre le DÉPARTEMENT de l'établissement :
                      // « 0 classe, en attente » ne dit pas s'il est seul en
                      // retard ou si tout son département l'est — deux
                      // situations, deux gestes opposés.
                      onTap: () => showYearDepartmentSheet(
                        context,
                        year: year,
                        analytics: a,
                        department: filtres[i].department,
                        focusSchoolId: filtres[i].id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Barre d'outils : recherche + relance ─────────────────────────────────────
class _AdoptionToolbar extends ConsumerStatefulWidget {
  const _AdoptionToolbar({
    required this.year,
    required this.analytics,
    required this.affiche,
  });
  final AdminYear year;
  final AdminYearAnalytics analytics;
  final int affiche;

  @override
  ConsumerState<_AdoptionToolbar> createState() => _AdoptionToolbarState();
}

class _AdoptionToolbarState extends ConsumerState<_AdoptionToolbar> {
  // Un contrôleur, et non un champ libre : sans lui, la croix d'effacement ne
  // peut pas vider ce que l'agent a tapé — elle remettrait le filtre à zéro en
  // laissant le texte affiché, et la table cesserait de correspondre au champ.
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retard = widget.analytics.ecolesEnRetard.length;
    final q = ref.watch(_adoptQueryProvider);
    final affiche = widget.affiche;

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _recherche,
            onChanged: (v) =>
                ref.read(_adoptQueryProvider.notifier).state = v,
            decoration: adminFilledInput(
              'Rechercher une école, un département',
              icon: Icons.search_rounded,
            ).copyWith(
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: kTextMuted),
                      onPressed: () {
                        _recherche.clear();
                        ref.read(_adoptQueryProvider.notifier).state = '';
                      },
                    ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Text(
            q.trim().isEmpty
                ? '$affiche établissement${affiche > 1 ? 's' : ''}'
                : '$affiche sur ${widget.analytics.ecolesTotal}',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
        const Spacer(),
        if (retard > 0 && !widget.year.isLocked)
          _RelanceButton(year: widget.year, nbEnRetard: retard),
      ],
    );
  }
}

class _RelanceButton extends ConsumerStatefulWidget {
  const _RelanceButton({required this.year, required this.nbEnRetard});
  final AdminYear year;
  final int nbEnRetard;
  @override
  ConsumerState<_RelanceButton> createState() => _RelanceButtonState();
}

class _RelanceButtonState extends ConsumerState<_RelanceButton> {
  bool _busy = false;

  Future<void> _relancer() async {
    final n = widget.nbEnRetard;
    final ok = await showAdminConfirm(
      context,
      title: 'Relancer les établissements en retard',
      icon: Icons.campaign_rounded,
      confirmLabel: 'Envoyer la relance',
      confirmIcon: Icons.send_rounded,
      message: "$n établissement${n > 1 ? 's n\'ont' : " n'a"} encore aucune "
          "classe ouverte pour l'année ${widget.year.label}.\n\n"
          'Une notification sera envoyée au chef de chacun de ces '
          'établissements (directeur ou proviseur). Cette action est tracée '
          "dans le journal d'audit.",
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final envoyees = await ref
          .read(adminCalendarServiceProvider)
          .remindPendingSchools(widget.year.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: envoyees == 0 ? kAccent : kGreen,
        content: Text(envoyees == 0
            ? 'Aucun chef d\'établissement joignable : ces écoles n\'ont pas '
                'de directeur ni de proviseur enregistré.'
            : 'Relance envoyée à $envoyees destinataire'
                '${envoyees > 1 ? 's' : ''}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(messageErreur(e, contexte: 'Relance'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _relancer,
      icon: _busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.campaign_rounded, size: 17),
      label: Text(_busy
          ? 'Envoi…'
          : 'Relancer ${widget.nbEnRetard} école'
              '${widget.nbEnRetard > 1 ? 's' : ''}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: BorderSide(color: kAccent.withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── En-tête cliquable (tri) ──────────────────────────────────────────────────
class _AdoptionHeaderRow extends ConsumerWidget {
  const _AdoptionHeaderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tri = ref.watch(_adoptTriProvider);
    final desc = ref.watch(_adoptDescProvider);

    void bascule(_AdoptTri t) {
      if (tri == t) {
        ref.read(_adoptDescProvider.notifier).state = !desc;
      } else {
        ref.read(_adoptTriProvider.notifier).state = t;
        // Texte : A→Z d'abord. Nombres : le plus grand d'abord.
        ref.read(_adoptDescProvider.notifier).state =
            t != _AdoptTri.nom && t != _AdoptTri.departement;
      }
    }

    Widget col(String label, _AdoptTri t, int flex, {TextAlign? align}) {
      final on = tri == t;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => bascule(t),
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: align == TextAlign.right
                  ? MainAxisAlignment.end
                  : align == TextAlign.center
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: on ? kNavy : kTextMuted)),
                ),
                if (on)
                  Icon(
                      desc
                          ? Icons.arrow_drop_down_rounded
                          : Icons.arrow_drop_up_rounded,
                      size: 17,
                      color: kNavy),
              ],
            ),
          ),
        ),
      );
    }

    // Le retrait de 6 et la réserve de 18 reproduisent EXACTEMENT la géométrie
    // d'une ligne de données (marge du fond de survol + colonne du chevron).
    // Sans eux, les en-têtes glissent de trente pixels par rapport aux valeurs
    // qu'ils nomment.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          col('Établissement', _AdoptTri.nom, 4),
          col('Département', _AdoptTri.departement, 3),
          col('Classes', _AdoptTri.classes, 2, align: TextAlign.center),
          col('Élèves', _AdoptTri.eleves, 2, align: TextAlign.center),
          col('État', _AdoptTri.etat, 2, align: TextAlign.right),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

/// Une ligne de la table — cliquable, et qui le MONTRE.
///
/// Une ligne qui réagit au clic sans rien laisser paraître ne se découvre que
/// par accident : le survol pose un fond et un chevron, le curseur devient une
/// main. Sans ces trois signes, la fonction existe pour qui la connaît déjà.
class _AdoptionRow extends StatefulWidget {
  const _AdoptionRow({required this.school, required this.onTap});
  final YearSchoolStat school;
  final VoidCallback onTap;

  @override
  State<_AdoptionRow> createState() => _AdoptionRowState();
}

class _AdoptionRowState extends State<_AdoptionRow> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final school = widget.school;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Opaque : la zone cliquable couvre toute la ligne, y compris les vides
        // entre colonnes — pas seulement les pixels du texte.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _survol ? kSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: school.adopted ? kGreen : kBorder,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      // Gouttière à droite : sans elle, un nom écrêté vient
                      // coller au département et les deux se lisent d'un seul
                      // tenant — « Lycée Technique Industriel Th…Brazzaville ».
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(school.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kTextPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(school.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
              Expanded(
                flex: 2,
                child: Text('${school.classes}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              Expanded(
                flex: 2,
                child: Text('${school.eleves}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AdminBadge(
                      school.adopted ? 'Préparée' : 'En attente',
                      color: school.adopted ? kGreen : kTextMuted),
                ),
              ),
              // Le chevron n'apparaît qu'au survol : affiché en permanence sur
              // mille lignes, il ferait un mur de flèches ; absent, rien ne dit
              // que la ligne mène quelque part.
              SizedBox(
                width: 18,
                child: AnimatedOpacity(
                  opacity: _survol ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: kTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
