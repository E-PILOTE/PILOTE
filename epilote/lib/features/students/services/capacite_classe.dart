// ════════════════════════════════════════════════════════════════════════════
//  CE QU'UNE CLASSE PEUT ENCORE ACCUEILLIR
//
//  ── POURQUOI CE FICHIER ────────────────────────────────────────────────────
//  Le sélecteur de classe affiche « 6e A (24/25) », et c'est suffisant quand on
//  inscrit UN élève : l'agent lit le rapport et décide.
//
//  Il ne l'est plus pour une réaffectation GROUPÉE. Sélectionner trente élèves
//  et les déplacer vers « 6e A (24/25) » portait la classe à cinquante-quatre
//  sans un mot — le rapport affiché décrivait l'état AVANT, et la seule
//  information qui comptait (ce que la classe contiendra après) n'était nulle
//  part. La surcharge se découvrait le jour de la rentrée, dans la salle.
//
//  ── CE N'EST PAS UN REFUS ──────────────────────────────────────────────────
//  Les effectifs réels dépassent régulièrement la capacité déclarée, et une
//  plateforme qui l'interdirait serait contournée le premier jour. On énonce le
//  fait, on demande confirmation, et on laisse l'école décider — c'est elle qui
//  connaît sa salle.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que devient une classe après y avoir déplacé un groupe d'élèves.
class DebordementClasse {
  const DebordementClasse({
    required this.className,
    required this.avant,
    required this.apres,
    required this.capacite,
  });

  final String className;

  /// Effectif de la classe avant le déplacement, et après.
  final int avant, apres;

  /// Places déclarées.
  final int capacite;

  /// Combien d'élèves au-delà de la capacité.
  int get exces => apres - capacite;

  String get message =>
      '« $className » compte $avant élève(s) pour $capacite place(s). '
      'Après ce déplacement, elle en comptera $apres — soit $exces de plus que '
      'la capacité déclarée.';
}

/// `null` si le déplacement ne fait pas déborder la classe — ou si l'on ne peut
/// pas le savoir.
///
/// Deux silences volontaires :
///  • une capacité nulle ou nulle-ou-zéro n'est pas une capacité de zéro, c'est
///    une capacité NON RENSEIGNÉE : on ne prévient pas d'un dépassement qu'on
///    n'a aucun moyen de constater ;
///  • une classe DÉJÀ pleine où l'on ne déplace personne ne déclenche rien —
///    l'alerte porte sur le geste en cours, pas sur l'état des lieux.
DebordementClasse? debordementApresDeplacement({
  required String className,
  required int effectifActuel,
  required int? capacite,
  required int aDeplacer,
}) {
  if (capacite == null || capacite <= 0) return null;
  if (aDeplacer <= 0) return null;
  final apres = effectifActuel + aDeplacer;
  if (apres <= capacite) return null;
  return DebordementClasse(
    className: className,
    avant: effectifActuel,
    apres: apres,
    capacite: capacite,
  );
}
