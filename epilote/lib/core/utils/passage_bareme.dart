import 'mention.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE BARÈME DE PASSAGE — source unique, côté Dart.
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  La barre de passage était écrite en dur, `annualAverage >= 10`, dans
//  `suggestedVerdict` — sans même passer par `kPassingMark`, la constante qui
//  vivait à côté. Deux exemplaires du même nombre dans le même dépôt.
//
//  Ce dépôt a déjà payé cette facture. Le barème des MENTIONS a vécu en trois
//  exemplaires ; deux avaient dérivé de deux points, et c'est la version
//  décalée qui s'imprimait sur les bulletins : 8/20, une note d'échec,
//  ressortait « Passable ». Deux jeux de tests verrouillaient la dérive, ce qui
//  la faisait passer pour délibérée.
//
//  Ici, une dérive de deux points ne changerait pas une étiquette sur un
//  papier : elle changerait qui redouble. D'où un seul endroit, et un miroir
//  SQL (`verdict_passage()`, migration 0107) tenu identique.
//
//  ── LA ZONE DE DÉLIBÉRATION ────────────────────────────────────────────────
//  Une barre seule fait couperet : 9,98 redouble, 10,00 passe. Aucun conseil de
//  classe ne fonctionne ainsi, et les systèmes voisins d'Afrique francophone
//  documentent tous une bande où l'avis du conseil est requis.
//
//  D'où le plancher, facultatif :
//
//      moyenne ≥ barre                     →  passe
//      plancher ≤ moyenne < barre          →  RIEN — le conseil tranche
//      moyenne < plancher                  →  redouble
//
//  Plancher absent = comportement d'avant, la barre fait couperet. C'est le
//  réglage par défaut : poser ce fichier ne change le sort d'aucun élève tant
//  que le ministère n'a pas décidé d'ouvrir une zone.
//
//  ⚠️ Dans la zone, la proposition est L'ABSENCE de proposition. Ce n'est pas
//  un trou à combler par un défaut prudent : « redouble par défaut » ferait
//  redoubler tout élève que le conseil n'a pas eu le temps d'examiner, et
//  « passe par défaut » ferait passer tout le monde. Le vide est le message.
// ════════════════════════════════════════════════════════════════════════════

/// Les deux bornes qui décident du sort d'une année.
class BaremePassage {
  const BaremePassage({required this.barre, this.plancher});

  /// Moyenne annuelle à atteindre pour passer, sur 20. Atteinte = passée :
  /// un élève à exactement 10,00 passe, il ne « frôle » pas.
  final double barre;

  /// Seuil sous lequel le redoublement se propose sans discussion.
  /// `null` = aucune zone de délibération, la barre fait couperet.
  final double? plancher;

  /// Le barème officiel du METP, en l'absence de tout réglage : la barre à
  /// 10/20, celle de `mentionFor`, et pas de zone de délibération.
  static const officiel = BaremePassage(barre: kPassingMark);

  bool get aZoneDeliberation => plancher != null;

  /// Le barème tel qu'on l'affiche à l'écran : « 10/20 » ou « 10/20 · conseil
  /// entre 8,5 et 10 ».
  String get libelle {
    final b = _fmt(barre);
    final p = plancher;
    if (p == null) return '$b/20';
    return '$b/20 · conseil entre ${_fmt(p)} et $b';
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'[.,]$'), '')
        .replaceAll('.', ',');
  }

  /// Applique une dérogation de niveau par-dessus le barème du groupe.
  ///
  /// Les deux bornes se surchargent SÉPARÉMENT : un niveau peut abaisser la
  /// barre sans toucher au plancher, et réciproquement.
  ///
  /// ⚠️ Une dérogation incohérente (plancher au-dessus de la barre) est
  /// IGNORÉE plutôt que corrigée. La contrainte SQL l'interdit déjà en base ;
  /// si une telle ligne atteint malgré tout un poste, mieux vaut retomber sur
  /// le barème du groupe — connu et valide — que de deviner laquelle des deux
  /// bornes l'emporte. Deviner produirait une zone de délibération à l'envers,
  /// où un élève à 11 attend le conseil pendant qu'un élève à 9 est déjà admis.
  BaremePassage avecDerogation({double? barre, double? plancher}) {
    final b = barre ?? this.barre;
    final p = plancher ?? this.plancher;
    if (b <= 0 || b > 20) return this;
    if (p != null && (p < 0 || p >= b)) return this;
    return BaremePassage(barre: b, plancher: p);
  }
}

/// Ce que le barème a à dire sur une moyenne.
enum PropositionPassage {
  /// Aucune moyenne : l'élève n'a pas de note. On ne délibère pas dans le vide.
  sansMoyenne,

  /// La moyenne atteint la barre.
  passe,

  /// La moyenne est sous le plancher.
  redouble,

  /// Entre le plancher et la barre : au conseil de trancher.
  deliberation,
}

/// La proposition du barème pour cette moyenne.
PropositionPassage propositionPour(double? moyenne, BaremePassage bareme) {
  if (moyenne == null) return PropositionPassage.sansMoyenne;
  if (moyenne >= bareme.barre) return PropositionPassage.passe;
  final p = bareme.plancher;
  if (p == null) return PropositionPassage.redouble;
  return moyenne < p
      ? PropositionPassage.redouble
      : PropositionPassage.deliberation;
}

/// Le code de verdict proposé, ou `null` quand le barème ne propose rien.
///
/// `null` recouvre deux situations que l'écran doit distinguer mais que
/// l'ÉCRITURE traite pareil — dans les deux cas on n'écrit pas de décision.
/// Utiliser [propositionPour] pour les séparer à l'affichage.
///
/// Ne rend jamais `reoriente` : la réorientation est un choix d'orientation,
/// jamais la conséquence d'un seuil. Miroir exact de `verdict_passage()` en SQL.
String? verdictPropose(double? moyenne, BaremePassage bareme) =>
    switch (propositionPour(moyenne, bareme)) {
      PropositionPassage.passe => 'passe',
      PropositionPassage.redouble => 'redouble',
      _ => null,
    };

/// Pourquoi aucun verdict n'a pu être proposé, en clair — pour le compte rendu
/// d'une campagne appliquée à toute l'école.
String motifSansProposition(PropositionPassage p, BaremePassage bareme) =>
    switch (p) {
      PropositionPassage.sansMoyenne =>
        'aucune moyenne — pas de note saisie cette année',
      PropositionPassage.deliberation =>
        'moyenne en zone de délibération (${bareme.libelle}) — au conseil de '
            'trancher',
      _ => '',
    };
