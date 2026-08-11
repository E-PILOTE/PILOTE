part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QU'IL Y A DERRIÈRE UNE LIGNE DE « PRÉPARATION PAR ÉCOLE ».
//
//  La table nommait un problème sans jamais le situer. « Lycée de Sibiti —
//  0 classe, en attente » : reste à savoir si tout le Niari est en retard, ou
//  si ce lycée est le seul de son département à ne pas avoir ouvert. Les deux
//  situations appellent des gestes opposés — relancer un établissement, ou
//  appeler une direction départementale. Faute de réponse, on quittait l'écran.
//
//  Cliquer une ligne ouvre donc son DÉPARTEMENT : l'établissement remis à son
//  rang, ses voisins, et la part que le département pèse dans le groupe. Le
//  tout s'exporte en fiche départementale — l'extrait qu'on envoie à la
//  direction concernée sans lui infliger le bilan national.
//
//  Aucune requête : tout se déduit de `bySchool`, déjà chargé par la page.
// ════════════════════════════════════════════════════════════════════════════

/// Violet du département — celui de la carte KPI « Départements couverts » et
/// de la section correspondante du bilan PDF. Getter, jamais `final` : les
/// jetons de couleur suivent le thème actif.
Color get _kDeptAccent => const Color(0xFF7C3AED);

Future<void> showYearDepartmentSheet(
  BuildContext context, {
  required AdminYear year,
  required AdminYearAnalytics analytics,
  required String department,
  String? focusSchoolId,
}) =>
    showAdminBottomModal<void>(
      context,
      builder: (_) => _DepartmentSheet(
        year: year,
        detail: YearDepartmentDetail.of(analytics, department),
        focusSchoolId: focusSchoolId,
      ),
    );

class _DepartmentSheet extends StatelessWidget {
  const _DepartmentSheet({
    required this.year,
    required this.detail,
    this.focusSchoolId,
  });

  final AdminYear year;
  final YearDepartmentDetail detail;
  final String? focusSchoolId;

  @override
  Widget build(BuildContext context) {
    final focus = focusSchoolId == null
        ? null
        : detail.ecoles.where((e) => e.id == focusSchoolId).firstOrNull;

    return AdminBottomModal(
      icon: Icons.map_rounded,
      accent: _kDeptAccent,
      title: detail.department,
      subtitle: [
        'préparation ${year.label}',
        '${detail.ecolesTotal} établissement${detail.ecolesTotal > 1 ? 's' : ''}',
        '${detail.classes} classe${detail.classes > 1 ? 's' : ''}',
        '${detail.eleves} élève${detail.eleves > 1 ? 's' : ''}',
      ].join('  ·  '),
      maxWidth: 940,
      // 0,90 et non 0,86 : le tableau est le SUJET de cette feuille, et quatre
      // points de hauteur en plus lui rendent une ligne et demie.
      heightFactor: 0.90,
      headerTrailing: AdminBadge(
        detail.ecolesTotal == 0
            ? 'Vide'
            : detail.ecolesEnAttente == 0
                ? 'Département prêt'
                : '${detail.ecolesEnAttente} en attente',
        color: detail.ecolesEnAttente == 0 ? kGreen : kAccent,
      ),
      hero: focus == null ? null : _FocusBand(detail: detail, school: focus),
      footer: _Footer(year: year, detail: detail),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Kpis(detail: detail),
        const SizedBox(height: 14),
        _PartDansLeGroupe(detail: detail),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Établissements du département'),
        const SizedBox(height: 10),
        if (detail.ecolesTotal == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text('Aucun établissement rattaché à ce département.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted)),
            ),
          )
        else ...[
          const _DeptHeaderRow(),
          Divider(height: 12, color: kBorder),
          // Hauteur bornée + ListView.builder : seules les lignes visibles sont
          // construites. Un département peut compter plus de cent
          // établissements à la cible nationale.
          SizedBox(
            height: (detail.ecolesTotal * 40.0).clamp(40.0, 340.0),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: detail.ecolesTotal,
              itemExtent: 40,
              itemBuilder: (_, i) => _DeptSchoolRow(
                school: detail.ecoles[i],
                rang: detail.rangDe(detail.ecoles[i].id),
                enAvant: detail.ecoles[i].id == focusSchoolId,
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Bandeau : l'établissement d'où l'on vient, remis à son rang ──────────────
//  Fixe sous l'en-tête : on parcourt la liste sans perdre de vue celui qu'on
//  était venu regarder.
class _FocusBand extends StatelessWidget {
  const _FocusBand({required this.detail, required this.school});
  final YearDepartmentDetail detail;
  final YearSchoolStat school;

  @override
  Widget build(BuildContext context) {
    final rang = detail.rangDe(school.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: BoxDecoration(
        color: _kDeptAccent.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _kDeptAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(rang == null ? '—' : '$rang',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kDeptAccent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(school.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(
                  rang == null
                      ? _typeLabel(school.type)
                      : '${_typeLabel(school.type)} · '
                          '$rang${rang == 1 ? 'ᵉʳ' : 'ᵉ'} sur '
                          '${detail.ecolesTotal} par effectif',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Chiffre(valeur: '${school.classes}', legende: 'classes'),
        const SizedBox(width: 18),
        _Chiffre(valeur: '${school.eleves}', legende: 'élèves'),
        const SizedBox(width: 16),
        AdminBadge(school.adopted ? 'Préparée' : 'En attente',
            color: school.adopted ? kGreen : kTextMuted),
      ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.valeur, required this.legende});
  final String valeur, legende;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          Text(legende, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      );
}

// ─── Indicateurs du département ───────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.detail});
  final YearDepartmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final taux = (detail.tauxPreparation * 100).round();
    final cells = <({String v, String l, Color c})>[
      (
        v: '${detail.ecolesPreparees}/${detail.ecolesTotal}',
        l: 'Établissements préparés',
        c: detail.ecolesEnAttente == 0 ? kGreen : kAccent
      ),
      (v: '$taux %', l: 'Taux de préparation', c: _kDeptAccent),
      (v: '${detail.classes}', l: 'Classes ouvertes', c: kNavy),
      (v: '${detail.eleves}', l: 'Élèves inscrits', c: kGreen),
      (
        v: detail.moyenneElevesParClasse.toStringAsFixed(1),
        l: 'Moy. élèves / classe',
        c: kNavy
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 780 ? 5 : (c.maxWidth >= 480 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 74,
        ),
        itemBuilder: (_, i) {
          final k = cells[i];
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: k.c.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: k.c.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(k.v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, color: k.c)),
                const SizedBox(height: 3),
                Text(k.l,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ],
            ),
          );
        },
      );
    });
  }
}

// ─── Part dans le groupe ──────────────────────────────────────────────────────
//  Un chiffre départemental isolé ne se compare à rien : « 4 300 élèves » est
//  beaucoup ou peu selon que le groupe en compte 6 000 ou 300 000.
class _PartDansLeGroupe extends StatelessWidget {
  const _PartDansLeGroupe({required this.detail});
  final YearDepartmentDetail detail;

  @override
  Widget build(BuildContext context) {
    // Trois mesures CÔTE À CÔTE, non empilées : empilées, elles poussaient le
    // tableau — le sujet de cette feuille — sous la ligne de flottaison, et
    // l'on ouvrait un département sans voir un seul de ses établissements.
    final parts = <({String l, double p, String d, Color c})>[
      (
        l: 'Élèves',
        p: detail.partEleves,
        d: '${detail.eleves} sur ${detail.groupeEleves}',
        c: kGreen
      ),
      (
        l: 'Classes',
        p: detail.partClasses,
        d: '${detail.classes} sur ${detail.groupeClasses}',
        c: kNavy
      ),
      (
        l: 'Établissements',
        p: detail.partEcoles,
        d: '${detail.ecolesTotal} sur ${detail.groupeEcoles}',
        c: _kDeptAccent
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminModalSectionTitle('Part dans le groupe'),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final colonne = c.maxWidth < 520;
          final tuiles = [
            for (final p in parts)
              _Part(label: p.l, part: p.p, detailTexte: p.d, color: p.c),
          ];
          if (colonne) {
            return Column(
              children: [
                for (final t in tuiles)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8), child: t),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tuiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tuiles[i]),
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({
    required this.label,
    required this.part,
    required this.detailTexte,
    required this.color,
  });
  final String label, detailTexte;
  final double part;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            Text('${(part * 100).toStringAsFixed(1)} %',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ]),
          const SizedBox(height: 2),
          Text(detailTexte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 7),
          // La barre se remplit à l'ouverture : elle donne à VOIR la proportion
          // plutôt que de la poser d'un coup, déjà finie.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: part.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: kCardBg,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Table des établissements du département ─────────────────────────────────
class _DeptHeaderRow extends StatelessWidget {
  const _DeptHeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget h(String t, int flex, {TextAlign align = TextAlign.left}) => Expanded(
          flex: flex,
          child: Text(t.toUpperCase(),
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextMuted)),
        );
    return Row(children: [
      SizedBox(width: 34, child: h('Rg', 1)),
      const SizedBox(width: 8),
      h('Établissement', 7),
      h('Type', 2, align: TextAlign.center),
      h('Classes', 2, align: TextAlign.center),
      h('Élèves', 2, align: TextAlign.center),
      h('État', 3, align: TextAlign.right),
    ]);
  }
}

class _DeptSchoolRow extends StatefulWidget {
  const _DeptSchoolRow({
    required this.school,
    required this.rang,
    required this.enAvant,
  });
  final YearSchoolStat school;
  final int? rang;

  /// L'établissement d'où vient le clic : surligné pour qu'on le retrouve dans
  /// une liste où il n'est qu'une ligne parmi cent.
  final bool enAvant;

  @override
  State<_DeptSchoolRow> createState() => _DeptSchoolRowState();
}

class _DeptSchoolRowState extends State<_DeptSchoolRow> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    final fond = widget.enAvant
        ? _kDeptAccent.withValues(alpha: 0.10)
        : _survol
            ? kSurface
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(7),
          border: widget.enAvant
              ? Border.all(color: _kDeptAccent.withValues(alpha: 0.30))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Text(widget.rang == null ? '—' : '${widget.rang}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.enAvant ? _kDeptAccent : kTextMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: s.adopted ? kGreen : kBorder,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Gouttière : un nom écrêté ne doit pas venir toucher la
                // colonne suivante — les deux se liraient d'un seul tenant.
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: widget.enAvant
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: kTextPrimary)),
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(_typeLabel(s.type),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: _typeColor(s.type))),
          ),
          Expanded(
            flex: 2,
            child: Text('${s.classes}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text('${s.eleves}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: AdminBadge(s.adopted ? 'Préparée' : 'En attente',
                  color: s.adopted ? kGreen : kTextMuted),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Pied : la fiche départementale ──────────────────────────────────────────
class _Footer extends StatefulWidget {
  const _Footer({required this.year, required this.detail});
  final AdminYear year;
  final YearDepartmentDetail detail;

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  bool _busy = false;

  // Le document est construit UNE FOIS, avant l'aperçu, et les mêmes octets
  // servent à l'affichage et à l'enregistrement : le fichier déposé porte la
  // référence et l'heure d'édition lues à l'écran.
  Future<void> _exporter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final octets = await YearDepartmentPdfService.buildPdf(
          year: widget.year, detail: widget.detail);
      if (!mounted) return;
      await showPdfPreviewDialog(
        context,
        title: 'Fiche départementale — ${widget.detail.department}',
        subtitle: 'Préparation ${widget.year.label} · '
            '${widget.detail.ecolesPreparees}/${widget.detail.ecolesTotal} '
            'établissements préparés',
        pdfFileName: 'Fiche_${widget.detail.department}.pdf',
        accent: _kDeptAccent,
        build: (_) async => octets,
        onDownload: () => YearDepartmentPdfService.downloadReport(
            year: widget.year, detail: widget.detail, bytes: octets),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(messageErreur(e, contexte: 'Fiche départementale'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Row(children: [
      Icon(
          d.ecolesEnAttente == 0
              ? Icons.check_circle_rounded
              : Icons.pending_actions_rounded,
          size: 17,
          color: d.ecolesEnAttente == 0 ? kGreen : kAccent),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          d.ecolesTotal == 0
              ? 'Aucun établissement rattaché à ce département.'
              : d.ecolesEnAttente == 0
                  ? "Tous les établissements du département ont préparé l'année."
                  : '${d.ecolesEnAttente} établissement'
                      '${d.ecolesEnAttente > 1 ? 's n\'ont' : " n'a"} pas '
                      "encore ouvert de classe pour l'année ${widget.year.label}.",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: kTextMuted),
        ),
      ),
      const SizedBox(width: 14),
      if (d.ecolesTotal > 0)
        AdminPrimaryButton(
          label: _busy ? 'Génération…' : 'Fiche départementale (PDF)',
          icon: Icons.picture_as_pdf_rounded,
          color: _kDeptAccent,
          saving: _busy,
          onTap: _exporter,
        ),
    ]);
  }
}
