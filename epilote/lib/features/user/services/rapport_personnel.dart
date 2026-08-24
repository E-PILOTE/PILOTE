import '../../staff/providers/staff_directory_provider.dart'
    show StaffCategory, staffCategory, staffCategoryLabel, staffCategoryOrder;

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT DU PERSONNEL — qui est en poste, et à quel titre
//
//  ⚠️ LE REGROUPEMENT N'EST PAS REFAIT ICI. `staffCategory` est importé de
//  l'annuaire : c'est lui qui décide depuis toujours qu'un comptable relève de
//  l'administration et un CPE de la vie scolaire. En recopier la table, ce
//  serait installer une seconde vérité — et le jour où l'une des deux change,
//  l'annuaire et l'état signé cesseraient de s'accorder.
//
//  ── CE QU'UN ÉTAT DU PERSONNEL DÉCLARE ─────────────────────────────────────
//  Qui est EN POSTE. Un agent désactivé n'y entre donc pas dans l'effectif —
//  mais il ne disparaît pas non plus : sans ligne pour lui, une école qui a
//  désactivé cinq comptes montrerait une baisse que rien n'explique.
// ════════════════════════════════════════════════════════════════════════════

/// Un agent, réduit à ce qu'un état du personnel compte.
typedef AgentCompte = ({String role, bool actif, String? statutEmploi});

/// Une ligne d'état : une catégorie métier, un statut d'emploi, ou un cumul.
typedef LignePersonnel = ({String libelle, int enFonction, int inactifs});

/// Libellé du regroupement des agents dont le statut d'emploi n'est pas saisi.
///
/// ⚠️ Même règle que le sexe non renseigné sur l'état des effectifs : les
/// ranger d'office chez les fonctionnaires donnerait un état où la somme des
/// statuts égale l'effectif — donc invérifiable, et faux.
const String kStatutNonRenseigne = 'Non renseigné';

/// Le personnel par catégorie métier, dans l'ordre de l'organigramme.
///
/// Les catégories sans aucun agent sont omises : une ligne « Vie scolaire — 0 »
/// n'apprend rien sur une école primaire qui n'en a pas. L'absence qui compte
/// vraiment — celle de la direction — se signale à l'écran avant l'impression,
/// pas par une ligne vide au milieu d'un tableau.
List<LignePersonnel> personnelParCategorie(Iterable<AgentCompte> agents) {
  final enFonction = <StaffCategory, int>{};
  final inactifs = <StaffCategory, int>{};
  for (final a in agents) {
    final c = staffCategory(a.role);
    if (a.actif) {
      enFonction[c] = (enFonction[c] ?? 0) + 1;
    } else {
      inactifs[c] = (inactifs[c] ?? 0) + 1;
    }
  }
  return [
    for (final c in staffCategoryOrder)
      if ((enFonction[c] ?? 0) + (inactifs[c] ?? 0) > 0)
        (
          libelle: staffCategoryLabel(c),
          enFonction: enFonction[c] ?? 0,
          inactifs: inactifs[c] ?? 0,
        ),
  ];
}

/// Le personnel par statut d'emploi (fonctionnaire, volontaire, prestataire…),
/// du plus nombreux au moins nombreux, le non-renseigné toujours en dernier.
///
/// ⚠️ L'ordre suit l'effectif et non l'alphabet : ce que lit d'abord une
/// direction départementale, c'est de quoi l'école est majoritairement faite.
List<LignePersonnel> personnelParStatut(Iterable<AgentCompte> agents) {
  final enFonction = <String, int>{};
  final inactifs = <String, int>{};
  for (final a in agents) {
    final brut = (a.statutEmploi ?? '').trim();
    final cle = brut.isEmpty ? kStatutNonRenseigne : brut;
    if (a.actif) {
      enFonction[cle] = (enFonction[cle] ?? 0) + 1;
    } else {
      inactifs[cle] = (inactifs[cle] ?? 0) + 1;
    }
  }
  final cles = {...enFonction.keys, ...inactifs.keys}.toList()
    ..sort((a, b) {
      if (a == kStatutNonRenseigne) return 1;
      if (b == kStatutNonRenseigne) return -1;
      final ea = (enFonction[a] ?? 0) + (inactifs[a] ?? 0);
      final eb = (enFonction[b] ?? 0) + (inactifs[b] ?? 0);
      final o = eb.compareTo(ea);
      return o != 0 ? o : a.compareTo(b);
    });
  return [
    for (final c in cles)
      (
        libelle: c,
        enFonction: enFonction[c] ?? 0,
        inactifs: inactifs[c] ?? 0,
      ),
  ];
}

/// Additionne des lignes en une seule — un seul chemin d'addition, donc une
/// seule occasion de se tromper.
LignePersonnel cumulPersonnel(String libelle, Iterable<LignePersonnel> lignes) {
  var f = 0, i = 0;
  for (final l in lignes) {
    f += l.enFonction;
    i += l.inactifs;
  }
  return (libelle: libelle, enFonction: f, inactifs: i);
}

/// L'école a-t-elle au moins un agent de direction en poste ?
///
/// ⚠️ Une école sans direction en fonction n'est pas une école : c'est une
/// donnée à corriger avant qu'un état ne soit signé — et signé par qui ?
bool aUneDirectionEnPoste(Iterable<AgentCompte> agents) => agents.any(
    (a) => a.actif && staffCategory(a.role) == StaffCategory.direction);
