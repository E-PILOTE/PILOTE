// ════════════════════════════════════════════════════════════════════════════
//  LE RANG SE COMPTE, IL NE SE LIT PAS DANS UNE LISTE TRIÉE
//
//  ── CE QUI NE MARCHAIT PAS ─────────────────────────────────────────────────
//  Le bulletin attribuait le rang par la POSITION dans une liste triée :
//  `rang = index + 1`. Deux élèves à 14,50 recevaient donc 3 et 4 — l'un
//  devant l'autre sans qu'aucune note ne les sépare, sur un document que la
//  famille garde et qu'un conseil de classe lit.
//
//  Et `List.sort` n'est pas stable en Dart : l'ordre de deux valeurs égales
//  n'est pas garanti. Le même élève pouvait donc être 3ᵉ sur le poste du
//  secrétariat et 4ᵉ sur celui du directeur, pour le même trimestre — la même
//  classe de défaut que les barèmes de frais, où deux postes réclamaient deux
//  sommes différentes au même élève.
//
//  ── LA RÈGLE ───────────────────────────────────────────────────────────────
//  Rang de compétition : les ex æquo PARTAGENT le rang, et le suivant saute.
//
//      14,50 · 14,50 · 12,00   →   1 · 1 · 3
//
//  Elle se compte — « combien font strictement mieux ? » — au lieu de se lire
//  dans un ordre. Aucun tri, donc aucune dépendance à sa stabilité : deux
//  postes tombent forcément sur le même nombre.
//
//  Le projet appliquait déjà cette règle pour le rang d'une école dans son
//  département ; le bulletin, lui, ne l'appliquait pas. Elle vit désormais ici,
//  en un seul exemplaire.
// ════════════════════════════════════════════════════════════════════════════

/// Rang de [valeur] parmi [toutes], ex æquo compris.
///
/// [toutes] doit contenir [valeur] ; si ce n'est pas le cas, le résultat reste
/// cohérent — c'est le rang que la valeur OCCUPERAIT.
int rangDeCompetition(num valeur, Iterable<num> toutes) =>
    1 + toutes.where((v) => v > valeur).length;
