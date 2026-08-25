// ════════════════════════════════════════════════════════════════════════════
//  POURQUOI UN ÉLÈVE QUITTE L'EFFECTIF — nomenclature, source unique
//
//  ⚠️ CETTE LISTE DOIT RESTER IDENTIQUE À LA CONTRAINTE `CHECK` DE LA
//  MIGRATION 0082. Un motif accepté ici et refusé en base ferait échouer la
//  remontée — et PowerSync abandonne le LOT ENTIER sur un rejet du serveur.
//  Même règle que le barème de mentions et l'INE.
//
//  ── POURQUOI FERMER LA LISTE ───────────────────────────────────────────────
//  Le motif était du texte libre, et le dialogue écrivait « Radiation » quand
//  l'agent ne saisissait rien. On ne peut rien compter là-dessus. Or c'est le
//  chiffre qu'un ministère publie : combien d'enfants sortent, et pourquoi.
//  « Abandon économique » et « mariage ou grossesse » n'appellent pas la même
//  politique publique — les confondre revient à n'en mener aucune.
//
//  Le texte libre n'est pas supprimé pour autant : la catégorie sert à
//  compter, le commentaire à comprendre un cas particulier.
//
//  ⚠️ LISTE À FAIRE VALIDER par le MEPSA et le METP. Elle s'appuie sur les
//  catégories usuelles des statistiques de déperdition scolaire ; aucune n'a
//  encore été confirmée.
// ════════════════════════════════════════════════════════════════════════════

/// Un motif de sortie : son code en base, son libellé, et ce qu'il signifie.
class SortieMotif {
  const SortieMotif(this.code, this.label, this.hint);
  final String code, label, hint;
}

/// Sorties DÉCLARÉES — l'enfant reste scolarisé, ailleurs.
const List<SortieMotif> kMotifsTransfert = [
  SortieMotif('transfert', 'Transfert vers un autre établissement',
      'L\'enfant poursuit sa scolarité ailleurs.'),
  SortieMotif('demenagement', 'Déménagement',
      'La famille quitte la localité.'),
];

/// Sorties de scolarisation — la déperdition proprement dite.
const List<SortieMotif> kMotifsRadiation = [
  SortieMotif('abandon_economique', 'Abandon — raisons économiques',
      'Frais de scolarité, travail de l\'enfant.'),
  SortieMotif('abandon_familial', 'Abandon — mariage, grossesse, famille',
      'Motif qui touche massivement les filles ; le distinguer est la '
      'condition pour agir dessus.'),
  SortieMotif('abandon_distance', 'Abandon — éloignement',
      'Distance à l\'établissement.'),
  SortieMotif('maladie', 'Maladie', 'Interruption pour raison de santé.'),
  SortieMotif('deces', 'Décès', 'À renseigner avec précaution.'),
  SortieMotif('exclusion', 'Exclusion disciplinaire',
      'Décision prononcée par l\'établissement.'),
  SortieMotif('fin_de_scolarite', 'Fin de scolarité',
      'Diplômé, ou dernier niveau atteint.'),
  SortieMotif('non_reinscrit', 'Ne s\'est pas représenté',
      'L\'école ignore ce qu\'est devenu l\'enfant. C\'est une réponse '
      'honnête, et le premier signal de déperdition.'),
  SortieMotif('autre', 'Autre', 'À préciser dans le commentaire.'),
];

/// Les motifs proposés pour une sortie donnée.
///
/// Un transfert et une radiation ne se justifient pas de la même façon :
/// proposer « décès » dans une liste de transferts serait au mieux absurde.
List<SortieMotif> motifsPour({required bool transfert}) =>
    transfert ? kMotifsTransfert : kMotifsRadiation;

/// Libellé lisible d'un code stocké, y compris venu d'une version plus
/// récente : on rend le code brut plutôt que rien.
String sortieMotifLabel(String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final m in [...kMotifsTransfert, ...kMotifsRadiation]) {
    if (m.code == code) return m.label;
  }
  return code;
}
