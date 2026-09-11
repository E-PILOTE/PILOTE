part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COMMENT UN ÉLÈVE S'AFFICHE : la table (avec sélection), les cartes, et
//  l'avatar photo-ou-initiales commun aux deux.
// ════════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════════
//  LA LISTE, VIRTUALISÉE — pourquoi ce détour par les slivers
//
//  ── CE QUI SE PASSAIT ─────────────────────────────────────────────────────
//  L'écran était un `SingleChildScrollView` sur une `Column` : Flutter
//  construisait CHAQUE ligne, y compris les huit cents qu'on ne voit pas. Sur
//  l'école la plus chargée du parc — 868 élèves — c'est 868 `InkWell`, 868
//  avatars, 868 lignes de badges construits pour en montrer une douzaine.
//
//  Et ce n'est pas un coût payé une fois : la liste vient de `db.watch`, donc
//  elle se reconstruit à CHAQUE tick de synchro. Un poste qui reçoit ses
//  données reconstruisait huit cents lignes invisibles à chaque lot. C'est là
//  que les machines d'entrée de gamme du parc perdent leur fluidité, et le
//  symptôme — « l'appli rame quand ça synchronise » — ne désigne jamais sa
//  cause.
//
//  ── POURQUOI DES RANGÉES ET NON UNE `SliverGrid` ──────────────────────────
//  Une `SliverGrid` exige une hauteur de cellule FIXE. Or une carte d'élève
//  mesure 114 pt sans particularité et jusqu'à 174 avec quatre étiquettes :
//  fixer la hauteur imposerait soit du vide sous les cartes nues, soit un
//  débordement sur les cartes chargées.
//
//  `Wrap` — ce qu'il y avait — donne à chaque RANGÉE la hauteur de sa plus
//  haute carte. Une `SliverList` dont chaque élément est une rangée reproduit
//  donc exactement le même rendu, et ne construit que les rangées visibles.
//  Le pas de virtualisation est la rangée au lieu de la carte : à quatre
//  colonnes, c'est déjà quatre fois moins de travail que rien.
//
//  ── ET LA TABLE ───────────────────────────────────────────────────────────
//  `DecoratedSliver` peint le cadre de la carte AUTOUR d'un groupe de slivers
//  (`SliverMainAxisGroup`) sans forcer leur construction. L'en-tête reste un
//  sliver, les lignes deviennent une `SliverList` — et le rendu est le même,
//  au pixel : `_StudentRow` dessinait déjà son propre filet du bas, et sait
//  déjà se taire sur la dernière (`last`).
// ════════════════════════════════════════════════════════════════════════════

/// Les slivers de la liste d'élèves, prêts pour le `CustomScrollView` de
/// l'écran. Table ou cartes selon [isTable].
List<Widget> studentListSlivers({
  required List<StudentRow> rows,
  required bool isTable,
  required bool sortAsc,
  required bool readOnly,
  required Set<String> selected,
  required VoidCallback onSort,
  required void Function(String, bool) onSelect,
  required ValueChanged<bool> onSelectAll,
  required ValueChanged<StudentRow> onOpen,
}) {
  if (isTable) {
    final allSel = rows.isNotEmpty &&
        rows.every((r) => selected.contains(r.enrollmentId));
    return [
      DecoratedSliver(
        // Reprise à l'identique de `AdminCard` (fond, rayon, filet, ombre) :
        // le cadre est peint par le sliver, pas par un `Container` qui aurait
        // exigé de construire tout son contenu pour se mesurer.
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        sliver: SliverMainAxisGroup(slivers: [
          SliverToBoxAdapter(
            child: _TableHeader(
              readOnly: readOnly,
              allSelected: allSel,
              sortAsc: sortAsc,
              onSort: onSort,
              onSelectAll: onSelectAll,
            ),
          ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _StudentRow(
              s: rows[i],
              last: i == rows.length - 1,
              readOnly: readOnly,
              selected: selected.contains(rows[i].enrollmentId),
              onSelect: (v) => onSelect(rows[i].enrollmentId!, v),
              onOpen: () => onOpen(rows[i]),
            ),
          ),
        ]),
      ),
    ];
  }

  return [
    SliverLayoutBuilder(
      builder: (context, cns) {
        // Mêmes seuils que la `Wrap` d'origine : le rendu ne bouge pas.
        final w = cns.crossAxisExtent;
        final cols = w >= 1180 ? 4 : (w >= 880 ? 3 : (w >= 560 ? 2 : 1));
        const gap = 14.0;
        final rangees = (rows.length / cols).ceil();
        return SliverList.builder(
          itemCount: rangees,
          itemBuilder: (context, i) {
            final debut = i * cols;
            final fin = (debut + cols) > rows.length ? rows.length : debut + cols;
            return Padding(
              padding: EdgeInsets.only(bottom: i == rangees - 1 ? 0 : gap),
              child: Row(
                // `start`, comme `Wrap` : une carte sans étiquette ne s'étire
                // pas jusqu'à la hauteur de sa voisine.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = debut; j < fin; j++) ...[
                    if (j > debut) const SizedBox(width: gap),
                    Expanded(
                      child: _StudentCard(
                        s: rows[j],
                        readOnly: readOnly,
                        selected: selected.contains(rows[j].enrollmentId),
                        onSelect: (v) => onSelect(rows[j].enrollmentId!, v),
                        onOpen: () => onOpen(rows[j]),
                      ),
                    ),
                  ],
                  // La dernière rangée est complétée par du vide : sans cela,
                  // deux cartes restantes s'étaleraient sur toute la largeur
                  // et la grille se briserait sur sa dernière ligne.
                  for (var k = fin; k < debut + cols; k++) ...[
                    const SizedBox(width: gap),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            );
          },
        );
      },
    ),
  ];
}

// ─── Table ───────────────────────────────────────────────────────────────────
/// L'en-tête de la table — extrait de l'ancien `_StudentTable`, qui posait
/// en-tête ET lignes dans une seule `Column` et construisait donc les huit
/// cents lignes de l'école la plus chargée du parc pour en montrer douze.
class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.readOnly,
    required this.allSelected,
    required this.sortAsc,
    required this.onSort,
    required this.onSelectAll,
  });
  final bool readOnly, allSelected, sortAsc;
  final VoidCallback onSort;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(children: [
          if (!readOnly) _Check(value: allSelected, onChanged: onSelectAll),
          if (!readOnly) const SizedBox(width: 6),
          _Th('ÉLÈVE', flex: 4, onTap: onSort, asc: sortAsc),
          const _Th('MATRICULE', flex: 2),
          // L'identifiant national ne figurait nulle part dans la liste, alors
          // que c'est lui qui suit l'enfant d'une école à l'autre — et lui
          // qu'on relit à voix haute au téléphone.
          const _Th('IDENT. NATIONAL', flex: 3),
          const _Th('SEXE · ÂGE', flex: 2),
          const _Th('CLASSE', flex: 3),
          const _Th('PARTICULARITÉS', flex: 3),
          const SizedBox(width: 36),
        ]),
      );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex, this.onTap, this.asc});
  final String label;
  final int flex;
  final VoidCallback? onTap;
  final bool? asc;
  @override
  Widget build(BuildContext context) {
    final child = Row(children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      ),
      if (asc != null)
        Icon(asc! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: kTextMuted),
    ]);
    return Expanded(
        flex: flex,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child));
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.s,
    required this.last,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final StudentRow s;
  final bool last, readOnly, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sexe = s.gender == 'F' ? 'F' : (s.gender == 'M' ? 'M' : '—');
    final age = s.age;
    final tags = <String>[
      if (s.isBoarder) 'Interne',
      if (s.isAffecte) 'Affecté',
      if (s.hasScholarship) 'Boursier',
      if (s.hasSocialAid) 'Aide sociale',
    ];
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.04) : null,
          border:
              last ? null : Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          if (!readOnly)
            _Check(value: selected, onChanged: onSelect),
          if (!readOnly) const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Row(children: [
              _Avatar(name: s.fullName, photoUrl: s.photoUrl, size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Text(s.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(s.matricule.isEmpty ? '—' : s.matricule,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(
            flex: 3,
            child: Text(
                // Un élève saisi hors ligne n'en a pas encore : le dire vaut
                // mieux qu'un tiret, qu'on lirait comme un oubli de saisie.
                s.ine == null ? 'en attente' : formatIne(s.ine),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: kTextMuted,
                    fontStyle:
                        s.ine == null ? FontStyle.italic : FontStyle.normal)),
          ),
          Expanded(
            flex: 2,
            child: Text('$sexe${age != null ? '  ·  $age ans' : ''}',
                style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
          ),
          Expanded(
            flex: 3,
            child: Row(children: [
              AdminBadge(s.className ?? '—', color: _cycColor(s.cycleCode)),
            ]),
          ),
          Expanded(
            flex: 3,
            child: tags.isEmpty
                ? Text('—',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))
                : Text(tags.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          SizedBox(
            width: 36,
            child: Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ),
        ]),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: kNavy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: kTextMuted, width: 1.5),
        ),
      );
}

// ─── Carte d'un élève ────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.s,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final StudentRow s;
  final bool readOnly, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final age = s.age;
    final sexe = s.gender == 'F' ? 'Fille' : (s.gender == 'M' ? 'Garçon' : '—');
    return AdminCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      accent: _cycColor(s.cycleCode),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Avatar(name: s.fullName, photoUrl: s.photoUrl, size: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(
                  '$sexe${age != null ? ' · $age ans' : ''}'
                  '${s.matricule.isNotEmpty ? ' · ${s.matricule}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          if (!readOnly) _Check(value: selected, onChanged: onSelect),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          AdminBadge(s.className ?? '—', color: _cycColor(s.cycleCode)),
          const Spacer(),
          if ((s.levelCode ?? '').isNotEmpty)
            Text(s.levelCode!,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
        if (s.isBoarder || s.hasScholarship || s.hasSocialAid || s.isAffecte) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (s.isBoarder) const _Tag('Interne'),
            if (s.isAffecte) const _Tag('Affecté'),
            if (s.hasScholarship) const _Tag('Boursier'),
            if (s.hasSocialAid) const _Tag('Aide sociale'),
          ]),
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
      );
}

// ─── Avatar (photo ou initiales) ─────────────────────────────────────────────
// La pastille d'élève vit désormais dans `core/widgets/photo_avatar.dart` :
// depuis que la photo se prend HORS LIGNE, son URL publique peut désigner un
// fichier encore en file d'envoi, et une copie qui l'ignore affiche un avatar
// cassé. La règle est à un seul endroit ; ce nom reste pour ne pas réécrire
// les vingt appels de cet écran.
typedef _Avatar = PhotoAvatar;
