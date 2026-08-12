part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA LENTILLE D'ANNÉE — ce que la page regarde, et comment on en change.
//
//  Toute la page (KPI, frise, graphiques, table de préparation) porte sur UNE
//  année. Ce bandeau est le seul endroit qui le dit et le seul qui permet d'en
//  changer : il mérite d'être lisible avant tout le reste, et de survivre à un
//  groupe qui aurait quinze années d'historique.
//
//  ⚠️ POURQUOI UN RAIL PLUTÔT QU'UNE SIMPLE LISTE HORIZONTALE.
//
//  La version précédente posait les années dans un `ListView` horizontal avec
//  une barre de défilement. Quatre défauts, tous invisibles tant qu'il n'y a
//  que deux ou trois années — c'est-à-dire tant qu'on ne teste pas la cible :
//
//   • LA MOLETTE NE FAISAIT RIEN. Flutter ne lit que `scrollDelta.dx` sur un
//     `Scrollable` horizontal ; une molette de souris n'émet que `dy`. Sur
//     Windows — la plateforme de livraison — il ne restait que le glisser du
//     pouce de la barre, haut de cinq pixels. On reporte donc explicitement
//     `dy` → défilement horizontal, en laissant `dx` au `Scrollable` (trackpad)
//     pour ne pas défiler deux fois.
//
//   • L'ANNÉE SÉLECTIONNÉE POUVAIT ÊTRE HORS ÉCRAN. Les années sont triées par
//     date décroissante : une année brouillon 2027-2028 passe AVANT l'année en
//     cours, et une année ancienne choisie par l'agent se retrouve loin à
//     droite. La page affichait donc les chiffres de 2019-2020 avec, à l'écran,
//     une rangée de pastilles où aucune n'était marquée. Le rail recentre.
//
//   • RIEN NE DISAIT QU'IL Y AVAIT UNE SUITE. Un voile dégradé sur le bord
//     concerné, et des chevrons de pagination, n'apparaissent que lorsque la
//     liste déborde réellement.
//
//   • AUCUN ACCÈS EXHAUSTIF. Au-delà d'une dizaine d'années, faire défiler pour
//     retrouver 2018-2019 est une corvée : le menu « ⌄ » liste tout d'un coup.
//
//  Le clavier fait le reste : ← → changent d'année, Origine/Fin sautent aux
//  extrémités.
// ════════════════════════════════════════════════════════════════════════════

class _YearLens extends StatelessWidget {
  const _YearLens({required this.years, required this.selected});
  final List<AdminYear> years;
  final AdminYear selected;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: _LensIdentity(years: years, selected: selected),
          ),
          Divider(height: 1, thickness: 1, color: kBorder),
          _YearRail(years: years, selectedId: selected.id),
        ],
      ),
    );
  }
}

// ─── Identité : quelle année on regarde, et son état ──────────────────────────
class _LensIdentity extends ConsumerWidget {
  const _LensIdentity({required this.years, required this.selected});
  final List<AdminYear> years;
  final AdminYear selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = _status(selected);

    AdminYear? courante;
    for (final y in years) {
      if (y.isCurrent) {
        courante = y;
        break;
      }
    }
    // Se retrouver sur une année passée sans s'en rendre compte est l'erreur
    // la plus coûteuse de cette page : on lit des effectifs qui ne sont plus
    // ceux du réseau. Le retour à l'année en cours est donc offert d'un geste,
    // et seulement quand il a un sens.
    final retour = (courante != null && courante.id != selected.id)
        ? _RetourAnneeCourante(courante: courante)
        : null;

    final bloc = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: st.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(st.icon, color: st.color, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    selected.label,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: kTextPrimary,
                    ),
                  ),
                  AdminBadge(st.label, color: st.color, icon: st.icon),
                  if (selected.isDraft)
                    AdminBadge(
                      'Brouillon — non diffusée',
                      color: kAccent,
                      icon: Icons.edit_note_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Indicateurs, graphiques et table de préparation ci-dessous '
                'portent tous sur cette année.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );

    if (retour == null) return bloc;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: bloc),
              const SizedBox(width: 12),
              retour,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bloc,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: retour),
          ],
        );
      },
    );
  }
}

class _RetourAnneeCourante extends ConsumerWidget {
  const _RetourAnneeCourante({required this.courante});
  final AdminYear courante;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: "Revenir aux chiffres de l'année en cours",
      child: OutlinedButton.icon(
        onPressed: () =>
            ref.read(selectedAdminYearIdProvider.notifier).state = courante.id,
        icon: const Icon(Icons.restart_alt_rounded, size: 17),
        label: Text('Année en cours (${courante.label})'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreen,
          side: BorderSide(color: kGreen.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}

// ─── Le rail ──────────────────────────────────────────────────────────────────
class _YearRail extends ConsumerStatefulWidget {
  const _YearRail({required this.years, required this.selectedId});
  final List<AdminYear> years;
  final String selectedId;

  @override
  ConsumerState<_YearRail> createState() => _YearRailState();
}

class _YearRailState extends ConsumerState<_YearRail> {
  final _defilement = ScrollController();

  /// Une clé par année : c'est elle qui permet de RAMENER la sélection dans le
  /// champ de vision. Les pastilles sont donc posées dans une `Row` et non dans
  /// un `ListView.builder` — une pastille non construite n'a pas de contexte, et
  /// `ensureVisible` ne pourrait pas l'atteindre. Le domaine borne le coût : un
  /// groupe compte des dizaines d'années, jamais des milliers.
  final _cles = <String, GlobalKey>{};

  bool _deborde = false;
  bool _auDebut = true;
  bool _aLaFin = true;

  /// Largeur du rail à la dernière MISE EN PAGE — jamais renseignée depuis
  /// l'écouteur de défilement. C'est ce qui distingue « la fenêtre a changé de
  /// taille » de « l'agent fait défiler » : deux situations qui appellent la
  /// même mesure, mais des réactions opposées.
  double _largeurVue = 0;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_majBords);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _majBords();
      _centrerSurSelection(anime: false);
    });
  }

  @override
  void didUpdateWidget(covariant _YearRail old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _centrerSurSelection());
    }
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  GlobalKey _cle(String id) => _cles.putIfAbsent(id, GlobalKey.new);

  /// ⚠️ REDIMENSIONNER LA FENÊTRE NE DÉCLENCHE AUCUN ÉVÉNEMENT DE DÉFILEMENT.
  ///
  /// `_majBords` était appelée depuis l'écouteur du contrôleur et une fois au
  /// premier rendu. Rétrécir la fenêtre change pourtant `maxScrollExtent` sans
  /// que rien ne défile : le rail se mettait à rogner la pastille sélectionnée
  /// — chevrons absents, voile absent, barre de défilement absente — parce que
  /// `_deborde` valait encore `false` depuis le lancement. La mesure est donc
  /// reprise après CHAQUE mise en page, via le `LayoutBuilder` du rail.
  ///
  /// Programmée après la frame : `_majBords` appelle `setState`, et une mise en
  /// page ne peut pas reconstruire l'arbre qu'elle est en train de mesurer.
  void _planifierMajBords(double largeur) {
    // Une VRAIE mise en page — pas un simple rebuild à largeur constante.
    // L'apparition des chevrons suffit à pousser la pastille choisie hors du
    // champ de vision : on la ramène. Le recentrage ne doit surtout PAS se
    // déclencher depuis l'écouteur de défilement, sinon chaque cran de molette
    // serait aussitôt annulé et le rail paraîtrait bloqué.
    final miseEnPage = (largeur - _largeurVue).abs() > 0.5;
    _largeurVue = largeur;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _majBords();
      if (miseEnPage) _centrerSurSelection(anime: false);
    });
  }

  void _majBords() {
    if (!_defilement.hasClients) return;
    final p = _defilement.position;
    final deborde = p.maxScrollExtent > 0.5;
    final debut = p.pixels <= 0.5;
    final fin = p.pixels >= p.maxScrollExtent - 0.5;
    if (deborde == _deborde && debut == _auDebut && fin == _aLaFin) return;
    setState(() {
      _deborde = deborde;
      _auDebut = debut;
      _aLaFin = fin;
    });
  }

  void _centrerSurSelection({bool anime = true}) {
    final ctx = _cles[widget.selectedId]?.currentContext;
    if (ctx == null || !_defilement.hasClients) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: anime ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _pager(int sens) {
    if (!_defilement.hasClients) return;
    final p = _defilement.position;
    final cible = (_defilement.offset + sens * p.viewportDimension * 0.8)
        .clamp(0.0, p.maxScrollExtent);
    _defilement.animateTo(
      cible,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _choisir(String id) =>
      ref.read(selectedAdminYearIdProvider.notifier).state = id;

  /// Déplace la SÉLECTION (pas le défilement) d'un cran — le recentrage suit.
  void _voisin(int sens) {
    final i = widget.years.indexWhere((y) => y.id == widget.selectedId);
    final j = i + sens;
    if (i < 0 || j < 0 || j >= widget.years.length) return;
    _choisir(widget.years[j].id);
  }

  void _extremite(bool debut) {
    if (widget.years.isEmpty) return;
    _choisir(debut ? widget.years.first.id : widget.years.last.id);
  }

  /// Molette verticale → défilement horizontal.
  ///
  /// ⚠️ PASSER PAR LE `pointerSignalResolver`, PAS AGIR DIRECTEMENT.
  ///
  ///  Un `Listener.onPointerSignal` ne CONSOMME rien : il est notifié en plus
  ///  des autres. En faisant défiler le rail depuis ce rappel, la molette
  ///  déplaçait le rail ET la page en même temps — un seul cran, deux
  ///  mouvements, celui qu'on visait et celui qu'on n'avait pas demandé.
  ///
  ///  Le résolveur ne retient qu'UN gestionnaire par événement, le premier
  ///  inscrit, et l'inscription suit l'ordre du test de survol : du plus
  ///  profond vers la racine. Le rail est plus profond que la liste de la page,
  ///  il gagne. Le `Scrollable` horizontal, lui, ne s'inscrit jamais sur une
  ///  molette verticale (Flutter ne lit que `scrollDelta.dx` sur cet axe) — il
  ///  n'y a donc personne à qui prendre la place.
  ///
  ///  Deux abstentions volontaires, qui rendent la molette à la page :
  ///  quand le rail ne déborde pas, et quand il est déjà en butée dans le sens
  ///  demandé. C'est le chaînage attendu sur un poste de bureau : le rail
  ///  d'abord, la page ensuite.
  ///
  ///  `dx` reste au `Scrollable` (trackpad, défilement latéral natif) :
  ///  l'intercepter ferait avancer le rail deux fois plus vite que le doigt.
  void _molette(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_defilement.hasClients) return;
    if (e.scrollDelta.dx != 0) return;
    final p = _defilement.position;
    if (p.maxScrollExtent <= 0) return;
    final cible =
        (_defilement.offset + e.scrollDelta.dy).clamp(0.0, p.maxScrollExtent);
    if (cible == _defilement.offset) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      if (_defilement.hasClients) _defilement.jumpTo(cible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final years = widget.years;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _voisin(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _voisin(1),
          const SingleActivator(LogicalKeyboardKey.home): () => _extremite(true),
          const SingleActivator(LogicalKeyboardKey.end): () => _extremite(false),
        },
        child: Row(
          children: [
            if (_deborde) ...[
              _FlecheRail(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Années plus récentes',
                actif: !_auDebut,
                onTap: () => _pager(-1),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, contraintes) {
                  _planifierMajBords(contraintes.maxWidth);
                  return Stack(
                    children: [
                      Listener(
                        onPointerSignal: _molette,
                        child: Scrollbar(
                          controller: _defilement,
                          thumbVisibility: _deborde,
                          thickness: 5,
                          radius: const Radius.circular(3),
                          child: SingleChildScrollView(
                            controller: _defilement,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                for (final y in years)
                                  Padding(
                                    key: _cle(y.id),
                                    padding: const EdgeInsets.only(right: 9),
                                    child: _YearChip(
                                      year: y,
                                      selectionnee: y.id == widget.selectedId,
                                      onTap: () => _choisir(y.id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _VoileBord(
                          gauche: true, visible: _deborde && !_auDebut),
                      _VoileBord(
                          gauche: false, visible: _deborde && !_aLaFin),
                    ],
                  );
                },
              ),
            ),
            // Chevrons ET menu n'apparaissent que si le rail déborde : tant que
            // toutes les années tiennent à l'écran, le rail EST la liste
            // exhaustive et trois commandes de plus ne seraient que du bruit.
            if (_deborde) ...[
              const SizedBox(width: 6),
              _FlecheRail(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Années plus anciennes',
                actif: !_aLaFin,
                onTap: () => _pager(1),
              ),
              const SizedBox(width: 8),
              _MenuAnnees(
                years: years,
                selectedId: widget.selectedId,
                onChoisir: _choisir,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
