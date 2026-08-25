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
  String nom,
  int montant,
  String? schoolId,
  String? levelId,
});

/// Le type `autre` est la catégorie OUVERTE du barème : cantine, transport,
/// tenue, fournitures, assurance. L'enum `fee_type` n'ayant que cinq valeurs,
/// tout ce qu'une école privée facture en plus de la scolarité y atterrit.
const kFeeTypeAnnexe = 'autre';

/// Sous quelle clé une ligne se met en concurrence avec une autre.
///
/// Pour les types à instance unique, c'est le TYPE : deux tarifs d'inscription
/// sont deux versions du même tarif, et une seule doit s'appliquer.
///
/// Pour `autre`, c'est le type ET l'intitulé : la cantine et le bus sont deux
/// choses, toutes deux dues. Les mettre en concurrence — ce que faisait la
/// version précédente — en faisait disparaître une : l'école enregistrait deux
/// frais et n'en réclamait qu'un, sans que rien ne le signale.
///
/// L'intitulé est normalisé comme il l'est dans l'index
/// `uniq_fee_structure_annexe_active` (migration 0108) : les deux doivent voir
/// « Cantine » et « cantine  » comme une seule et même chose, sans quoi la base
/// accepterait ce que le client dédoublerait.
String _cle(LigneBareme b) => b.feeType == kFeeTypeAnnexe
    ? '$kFeeTypeAnnexe|${b.nom.trim().toLowerCase()}'
    : b.feeType;

/// Score de spécificité : l'école (2) l'emporte sur le niveau (1), et les deux
/// se cumulent. Plus haut = plus proche de l'élève.
///
/// L'école pèse plus lourd que le niveau parce qu'un tarif posé pour un
/// établissement est une décision prise EN CONNAISSANCE de cet établissement,
/// alors qu'un tarif par niveau reste une règle générale du réseau.
int _specificite(LigneBareme b) =>
    (b.schoolId != null ? 2 : 0) + (b.levelId != null ? 1 : 0);

/// [candidat] doit-il remplacer [tenant] ?
///
/// ⚠️ La spécificité seule ne suffit pas : deux barèmes de MÊME portée peuvent
/// coexister sur un poste. La migration 0099 les interdit désormais en base,
/// mais un appareil hors ligne peut porter, le temps d'une synchro, l'ancien
/// et le nouveau. Un `>` strict laissait alors gagner le PREMIER ARRIVÉ — et
/// la requête amont n'a pas d'`ORDER BY`. Deux postes de la même école
/// pouvaient réclamer deux sommes différentes au même élève.
///
/// D'où un ordre TOTAL, qui ne dépend d'aucune horloge ni d'aucun tri SQL :
///   1. le plus spécifique ;
///   2. à égalité, **le moins cher** — une famille ne doit jamais payer le
///      supplément d'une hésitation administrative ;
///   3. à égalité encore, le plus petit `id`, pour que deux appareils tombent
///      sur la même ligne.
bool _emporte(LigneBareme candidat, LigneBareme tenant) {
  final ds = _specificite(candidat) - _specificite(tenant);
  if (ds != 0) return ds > 0;
  if (candidat.montant != tenant.montant) return candidat.montant < tenant.montant;
  return candidat.id.compareTo(tenant.id) < 0;
}

/// Parmi les barèmes visibles sur le poste, ceux qui s'appliquent réellement à
/// un élève du niveau [levelId] — au plus un par CLÉ de résolution (cf. [_cle] :
/// un par type de frais, mais un par intitulé pour les frais annexes).
///
/// Le résultat ne dépend d'AUCUN ordre d'arrivée, y compris entre deux lignes
/// de portée identique : `_emporte` définit un ordre total (cf. sa doc).
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

    final cle = _cle(b);
    final actuel = retenu[cle];
    if (actuel == null || _emporte(b, actuel)) {
      retenu[cle] = b;
    }
  }
  return retenu.values.toList();
}
