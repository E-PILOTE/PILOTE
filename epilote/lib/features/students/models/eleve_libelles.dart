// ════════════════════════════════════════════════════════════════════════════
//  LES LIBELLÉS DE L'ÉLÈVE — un code en base, un mot pour l'écran.
//
//  ── POURQUOI CE FICHIER ────────────────────────────────────────────────────
//  La situation familiale est stockée en code (`monoparentale_pere`) et la
//  liste déroulante en connaissait le libellé. Le RÉCAPITULATIF, lui, affichait
//  le code brut — à l'écran précis où l'on relit avant d'enregistrer, le
//  secrétariat lisait « monoparentale_pere ».
//
//  C'est exactement le défaut déjà corrigé pour le lien de parenté, qui
//  affichait « (mere) » au même endroit, et dont la correction avait donné
//  `tutorRelationshipLabel`. La même cause a reproduit le même effet sur le
//  champ voisin, parce que la table de correspondance vivait à l'intérieur du
//  widget de saisie : invisible à qui écrit l'écran de relecture.
//
//  Elle vit donc ici, avec sa fonction de lecture, et les deux écrans de saisie
//  (assistant d'inscription et modification d'un dossier) la partagent au lieu
//  d'en tenir chacun une copie.
// ════════════════════════════════════════════════════════════════════════════

/// Les situations familiales retenues, du code de base vers le mot affiché.
const Map<String, String> kSituationsFamiliales = {
  'biparentale': 'Biparentale',
  'monoparentale_pere': 'Monoparentale (père)',
  'monoparentale_mere': 'Monoparentale (mère)',
  'orphelin_partiel': 'Orphelin partiel',
  'orphelin_total': 'Orphelin total',
  'tuteur': 'Sous tutelle',
};

/// Libellé d'une situation familiale (`monoparentale_pere` → « Monoparentale
/// (père) »).
///
/// Un code inconnu est rendu TEL QUEL plutôt que masqué : si la base se met à
/// porter une valeur que l'application ignore, mieux vaut la voir à l'écran que
/// lire un tiret et croire le champ vide.
String situationFamilialeLabel(String? code) {
  if (code == null || code.trim().isEmpty) return '—';
  return kSituationsFamiliales[code] ?? code;
}

/// Les groupes sanguins proposés à la saisie.
///
/// La même table était recopiée dans TROIS écrans (assistant d'inscription,
/// modification au guichet, modification au registre). Une liste figée ne
/// diverge pas toute seule — mais c'est ce qu'on croyait aussi de la situation
/// familiale, et elle avait fini par exister en quatre exemplaires dont un
/// muet.
const Map<String, String> kGroupesSanguins = {
  'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-',
  'AB+': 'AB+', 'AB-': 'AB-', 'O+': 'O+', 'O-': 'O-',
};
