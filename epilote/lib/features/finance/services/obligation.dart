// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE DOIT — décisions pures
//
//  « Élèves à jour » comptait tout élève ayant versé AU MOINS UN FRANC, faute
//  d'un montant dû quelque part : 1 000 versés sur 90 000 valaient réglé. Le dû
//  se déduit ici des barèmes applicables, sans aucune table d'échéances — un
//  frais unique est dû en entier, une mensualité s'accumule sur les mois
//  écoulés.
//
//  Les 8 130 élèves du public n'ont que des frais uniques : inscription,
//  cotisation APE, frais d'examen. La mensualité ne concerne que les 974 élèves
//  du privé — c'est ce qui autorise un calcul dérivé plutôt qu'un échéancier.
// ════════════════════════════════════════════════════════════════════════════

/// Où en est un élève vis-à-vis de ce qu'il doit.
enum EtatObligation {
  /// Aucun barème ne s'applique : on ne peut rien affirmer. Ce n'est PAS
  /// « à jour » — 30 écoles publiques sont dans ce cas, et les déclarer réglées
  /// serait aussi faux que de les déclarer débitrices.
  sansBareme,
  aJour,
  partiel,
  impaye,
}

String libelleEtat(EtatObligation e) => switch (e) {
      EtatObligation.sansBareme => 'Barème non défini',
      EtatObligation.aJour => 'À jour',
      EtatObligation.partiel => 'Avance partielle',
      EtatObligation.impaye => 'Impayé',
    };

/// Nombre de mois entamés depuis la rentrée, plafonné à l'année scolaire.
///
/// Le plafond n'est pas cosmétique : sans lui, un dossier consulté deux ans
/// plus tard afficherait vingt-quatre mensualités dues.
int moisEcoules({
  required DateTime debut,
  required DateTime fin,
  required DateTime maintenant,
}) {
  final total = (fin.year - debut.year) * 12 + (fin.month - debut.month) + 1;
  if (maintenant.isBefore(debut)) return 0;
  final ecoules =
      (maintenant.year - debut.year) * 12 + (maintenant.month - debut.month) + 1;
  return ecoules > total ? total : ecoules;
}

/// Ce qu'un barème réclame à cette date.
int duPourBareme({
  required String feeType,
  required int montant,
  required int moisEcoules,
}) =>
    feeType == 'mensualite' ? montant * moisEcoules : montant;

/// L'état d'un élève au vu de ce qu'il doit et de ce qu'il a versé.
///
/// Le trop-versé reste « à jour » : le dépassement est un sujet de contrôle du
/// tarif (cf. spec §5.7), pas de recouvrement. Le confondre ici ferait
/// apparaître comme débiteur un élève qui a trop payé.
EtatObligation etatObligation({required int du, required int verse}) {
  if (du <= 0) return EtatObligation.sansBareme;
  if (verse >= du) return EtatObligation.aJour;
  if (verse > 0) return EtatObligation.partiel;
  return EtatObligation.impaye;
}
