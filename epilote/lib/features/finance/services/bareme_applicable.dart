// ════════════════════════════════════════════════════════════════════════════
//  QUEL BARÈME S'APPLIQUE À CET ÉLÈVE ?
//
//  Depuis que le barème appartient au groupe (migration 0096), un poste voit
//  DEUX portées : le tarif du réseau (`school_id IS NULL`) et celui posé par le
//  groupe POUR son école. S'y ajoute le ciblage par niveau. Un élève de 6e peut
//  donc voir quatre lignes pour le MÊME frais — les additionner lui ferait
//  payer quatre fois.
//
//  D'où cette résolution : au plus UNE ligne par type de frais, la plus proche
//  de l'élève.
// ════════════════════════════════════════════════════════════════════════════

/// Une ligne de barème telle que le poste la voit, toutes portées confondues.
typedef LigneBareme = ({
  String id,
  String feeType,
  int montant,
  String? schoolId,
  String? levelId,
});

/// Score de spécificité : l'école (2) l'emporte sur le niveau (1), et les deux
/// se cumulent. Plus haut = plus proche de l'élève.
///
/// L'école pèse plus lourd que le niveau parce qu'un tarif posé pour un
/// établissement est une décision prise EN CONNAISSANCE de cet établissement,
/// alors qu'un tarif par niveau reste une règle générale du réseau.
int _specificite(LigneBareme b) =>
    (b.schoolId != null ? 2 : 0) + (b.levelId != null ? 1 : 0);

/// Parmi les barèmes visibles sur le poste, ceux qui s'appliquent réellement à
/// un élève du niveau [levelId] — au plus un par type de frais.
///
/// Le résultat ne dépend pas de l'ordre d'arrivée : la liste vient d'un
/// `ORDER BY` SQL, elle ne doit pas décider du tarif.
List<LigneBareme> baremesApplicables(
  List<LigneBareme> visibles, {
  required String? levelId,
}) {
  final retenu = <String, LigneBareme>{};
  for (final b in visibles) {
    // Un barème ciblant un autre niveau ne concerne pas cet élève. Un élève
    // dont le niveau est inconnu ne prend que les barèmes « toute l'école » :
    // lui appliquer un tarif de niveau au hasard serait pire que rien.
    if (b.levelId != null && b.levelId != levelId) continue;

    final actuel = retenu[b.feeType];
    if (actuel == null || _specificite(b) > _specificite(actuel)) {
      retenu[b.feeType] = b;
    }
  }
  return retenu.values.toList();
}
