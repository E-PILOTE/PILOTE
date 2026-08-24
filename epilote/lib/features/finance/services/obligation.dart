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

  /// Un barème s'applique, mais l'exonération le ramène à zéro : cet élève ne
  /// doit rien, et ce n'est ni « à jour » (il n'a rien versé) ni « sans
  /// barème » (le tarif existe). Sans cet état, un boursier à 100 % ressortait
  /// « Barème non défini » et la caisse partait chercher un tarif qui existe.
  exonere,
  aJour,
  partiel,
  impaye,
}

String libelleEtat(EtatObligation e) => switch (e) {
      EtatObligation.sansBareme => 'Barème non défini',
      EtatObligation.exonere => 'Exonéré',
      EtatObligation.aJour => 'À jour',
      EtatObligation.partiel => 'Avance partielle',
      EtatObligation.impaye => 'Impayé',
    };

/// Les mois de mensualité que CET élève doit réellement.
///
/// Sans [entree] ni [sortie], c'est simplement le nombre de mois entamés depuis
/// la rentrée, plafonné à l'année scolaire — le plafond n'est pas cosmétique :
/// sans lui, un dossier consulté deux ans plus tard afficherait vingt-quatre
/// mensualités dues.
///
/// ── POURQUOI LE COMPTEUR DE L'ANNÉE NE SUFFIT PAS ───────────────────────────
///
/// La version précédente ne savait compter QUE depuis la rentrée, pour tout le
/// monde pareil. Un élève transféré en mars se voyait donc réclamer, le jour
/// même de son arrivée, les
/// six mois qu'il avait passés dans une AUTRE école — il apparaissait débiteur
/// de 150 000 F avant d'avoir posé son cartable. Symétriquement, un élève radié
/// en décembre continuait d'accumuler des mensualités jusqu'en juillet : sa
/// dette grossissait tout seule, longtemps après son départ.
///
/// Le dû se compte donc sur la FENÊTRE DE PRÉSENCE : de son entrée (jamais
/// avant la rentrée) à son départ (jamais après la fin de l'année, ni après
/// aujourd'hui).
///
/// ⚠️ Le mois d'arrivée compte pour un mois ENTIER, et le mois de départ aussi.
/// Aucune école congolaise ne facture à la semaine ; découper plus fin
/// produirait des montants que la caisse ne saurait pas justifier au parent.
///
/// ⚠️ [entree] antérieure à la rentrée est ignorée : c'est le cas normal d'une
/// réinscription saisie en août pour une année qui commence en octobre. La
/// prendre au mot ferait payer des mois où l'école n'avait pas ouvert.
int moisDus({
  required DateTime debutAnnee,
  required DateTime finAnnee,
  required DateTime maintenant,
  DateTime? entree,
  DateTime? sortie,
}) {
  final debut =
      (entree != null && entree.isAfter(debutAnnee)) ? entree : debutAnnee;

  var fin = maintenant.isBefore(finAnnee) ? maintenant : finAnnee;
  if (sortie != null && sortie.isBefore(fin)) fin = sortie;

  // Comparaison au JOUR, pas au mois : une année qui démarre le 15 ne doit
  // rien le 1er. Règle héritée du compteur d'année, conservée telle quelle.
  if (fin.isBefore(debut)) return 0;

  return (fin.year - debut.year) * 12 + (fin.month - debut.month) + 1;
}

/// Les types de frais qu'une exonération de scolarité couvre.
///
/// ⚠️ SEULE autorité sur cette liste — la migration 0109 y renvoie plutôt que
/// de la redire en SQL, précisément pour qu'il n'en existe qu'un exemplaire.
///
/// `frais_examens` en est exclu : ce sont les frais de L'ÉTAT, une école ne
/// peut pas en dispenser. `autre` aussi : la cantine et le transport sont des
/// services que l'école décaisse réellement — les exonérer par défaut lui
/// ferait supporter des repas et du carburant qu'elle a payés. Une école qui
/// veut aussi remettre la cantine le fait par un arrangement distinct.
const kFraisScolarite = {'inscription', 'mensualite', 'cotisation_ape'};

/// Ce qui reste dû après application d'un taux d'exonération.
///
/// [taux] est un pourcentage 1–100, ou `null` quand aucune exonération n'a été
/// accordée. Un boursier à 100 % ne doit rien ; à 50 %, la moitié.
///
/// ⚠️ L'arrondi porte sur le montant EXONÉRÉ, pas sur le reste : c'est ce qui
/// garantit qu'un taux de 100 % rende exactement zéro, quel que soit le
/// montant. Arrondir le reste laisserait des francs orphelins qu'aucune caisse
/// ne pourrait encaisser et qui feraient éternellement apparaître « Impayé ».
int apresExoneration(int du, int? taux) {
  if (taux == null || taux <= 0) return du;
  if (taux >= 100) return 0;
  return du - (du * taux / 100).round();
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
///
/// [exonereTotal] distingue les deux façons d'avoir un dû nul : aucun tarif
/// publié, ou un tarif intégralement remis. Les confondre envoyait la caisse
/// réclamer un barème à propos d'un boursier — cf. [EtatObligation.exonere].
EtatObligation etatObligation({
  required int du,
  required int verse,
  bool exonereTotal = false,
}) {
  if (exonereTotal) return EtatObligation.exonere;
  if (du <= 0) return EtatObligation.sansBareme;
  if (verse >= du) return EtatObligation.aJour;
  if (verse > 0) return EtatObligation.partiel;
  return EtatObligation.impaye;
}
