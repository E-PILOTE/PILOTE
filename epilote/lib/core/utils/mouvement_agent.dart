// ════════════════════════════════════════════════════════════════════════════
//  LES MOUVEMENTS DE L'AGENT — vocabulaire, source unique
//
//  ⚠️ CETTE LISTE DOIT RESTER IDENTIQUE AUX CONTRAINTES `CHECK` DE LA
//  MIGRATION 0083 (`staff_affectations` et `profiles.departure_motif`). Même
//  règle que le barème de mentions, l'INE et les motifs de sortie d'élève.
//
//  ── CE QUE ÇA CORRIGE ──────────────────────────────────────────────────────
//  `profiles.is_active` était un booléen : un retraité, un muté, un
//  démissionnaire, un révoqué et un mort y devenaient la même chose. Ils
//  n'appellent pourtant pas les mêmes actes — et surtout, LE MUTÉ N'EST PAS
//  INACTIF. Il sert ailleurs, et on l'attend à son nouveau poste.
//
//  D'où la séparation, qui traverse tout ce fichier :
//    • MUTER      → l'agent change d'école, reste actif   (`muter_agent`)
//    • RADIER     → l'agent quitte le service              (`radier_agent`)
//    • RÉINTÉGRER → l'agent revient                        (`reintegrer_agent`)
//
//  ⚠️ VOCABULAIRE À FAIRE VALIDER par le MEPSA et le METP. Il reprend les
//  termes statutaires usuels de la fonction publique ; aucun n'a été confirmé.
// ════════════════════════════════════════════════════════════════════════════

/// Un motif de mouvement : son code en base, son libellé, ce qu'il signifie.
class MouvementMotif {
  const MouvementMotif(this.code, this.label, this.hint, {this.reversible = true});

  final String code, label, hint;

  /// Peut-on réintégrer l'agent après ce départ ? Une révocation et un décès
  /// ne se défont pas d'un clic — la base les refuse aussi.
  final bool reversible;
}

/// Pourquoi un agent ARRIVE dans un établissement.
const List<MouvementMotif> kMotifsArrivee = [
  MouvementMotif('recrutement', 'Recrutement',
      'Premier poste : l\'agent entre dans le système.'),
  MouvementMotif('mutation', 'Mutation',
      'Vient d\'un autre établissement.'),
  MouvementMotif('detachement', 'Détachement',
      'Mis à disposition par une autre administration.'),
  MouvementMotif('mise_a_disposition', 'Mise à disposition',
      'Reste rattaché à son corps d\'origine.'),
  MouvementMotif('interim', 'Intérim',
      'Occupe temporairement le poste d\'un autre.'),
  MouvementMotif('reintegration', 'Réintégration',
      'Revient après disponibilité, détachement ou congé.'),
];

/// Pourquoi un agent QUITTE le service.
///
/// « Mutation » n'y figure pas, et c'est le cœur du correctif : un agent muté
/// n'a pas quitté le service, il a changé de poste. La base refuse d'ailleurs
/// une radiation pour mutation.
const List<MouvementMotif> kMotifsDepart = [
  MouvementMotif('retraite', 'Retraite',
      'Le dossier reste consultable : pension, attestations.'),
  MouvementMotif('demission', 'Démission', 'À l\'initiative de l\'agent.'),
  MouvementMotif('detachement', 'Détachement',
      'Part servir dans une autre administration ; reviendra.'),
  MouvementMotif('disponibilite', 'Mise en disponibilité',
      'Suspension temporaire de fonctions, à sa demande.'),
  MouvementMotif('licenciement', 'Licenciement',
      'Rupture de contrat à l\'initiative de l\'employeur.'),
  MouvementMotif('revocation', 'Révocation',
      'Sanction disciplinaire définitive. Aucun retour possible '
      'sans correction explicite du dossier.',
      reversible: false),
  MouvementMotif('abandon_de_poste', 'Abandon de poste',
      'L\'agent ne s\'est pas présenté et ne s\'est pas justifié.'),
  MouvementMotif('deces', 'Décès',
      'À renseigner avec précaution : le dossier se ferme définitivement.',
      reversible: false),
  MouvementMotif('fin_de_contrat', 'Fin de contrat',
      'Terme normal d\'un engagement à durée déterminée.'),
  MouvementMotif('fin_interim', 'Fin d\'intérim',
      'Le titulaire du poste reprend ses fonctions.'),
  MouvementMotif('autre', 'Autre', 'À préciser dans les observations.'),
];

/// Libellé lisible d'un code stocké, y compris venu d'une version plus
/// récente : on rend le code brut plutôt que rien.
String mouvementLabel(String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final m in [...kMotifsArrivee, ...kMotifsDepart]) {
    if (m.code == code) return m.label;
  }
  // Motifs techniques, jamais proposés à la saisie.
  if (code == 'reprise_historique') return 'Reprise de l\'existant';
  return code;
}

/// Un départ pour ce motif se rattrape-t-il ? Un code inconnu est réputé
/// réversible : mieux vaut laisser corriger que bloquer sur une ignorance.
bool departReversible(String? code) {
  for (final m in kMotifsDepart) {
    if (m.code == code) return m.reversible;
  }
  return true;
}
