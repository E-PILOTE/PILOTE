// ════════════════════════════════════════════════════════════════════════════
//  MODÈLES D'ÉTABLISSEMENT
//
//  Une EPP a six niveaux, un CEG en a quatre, un lycée trois. Ce sont toujours
//  les mêmes. Les faire cocher un par un, mille fois, pour mille écoles, c'est
//  mille occasions d'en oublier un — et un niveau oublié, c'est une classe
//  qu'on ne peut pas ouvrir en novembre.
//
//  Un modèle ne fait qu'une chose : désigner les CYCLES. Les niveaux, eux,
//  viennent du référentiel national — on ne les recopie pas ici. Écrire
//  « CP1, CP2, CE1… » en dur dans l'application, c'est créer une deuxième
//  source de vérité qui divergera de la base au premier arrêté ministériel.
//
//  Le modèle est un POINT DE DÉPART, pas un verrou : tout reste décochable
//  ensuite. Une école qui n'ouvre pas encore sa Terminale retire la Terminale.
// ════════════════════════════════════════════════════════════════════════════

class ModeleEtablissement {
  const ModeleEtablissement({
    required this.nom,
    required this.cycles,
    required this.description,
    this.choisirFilieres = false,
  });

  final String nom;

  /// Codes de cycle du référentiel (`education_cycles.code`).
  final List<String> cycles;

  /// Ce que le modèle recouvre, dans les mots du terrain.
  final String description;

  /// Le modèle pose le cycle mais PAS les niveaux : ils dépendent des filières
  /// que l'établissement ouvre réellement. Cocher les 63 niveaux de la
  /// formation professionnelle serait faux pour chaque école du pays.
  final bool choisirFilieres;
}

/// Les formes d'établissement du système congolais.
///
/// L'ordre suit celui du parcours de l'élève, pas une fréquence supposée.
const kModelesEtablissement = <ModeleEtablissement>[
  ModeleEtablissement(
    nom: 'École maternelle',
    cycles: ['prescolaire'],
    description: 'Petite, moyenne et grande section.',
  ),
  ModeleEtablissement(
    nom: 'École primaire',
    cycles: ['primaire'],
    description: 'CP1 à CM2. La forme la plus répandue du pays.',
  ),
  ModeleEtablissement(
    nom: 'Complexe scolaire',
    cycles: ['prescolaire', 'primaire'],
    description: 'Maternelle et primaire sur le même site.',
  ),
  ModeleEtablissement(
    nom: 'CEG',
    cycles: ['college'],
    description: 'Collège d\'enseignement général : 6ᵉ à 3ᵉ.',
  ),
  ModeleEtablissement(
    nom: 'Lycée d\'enseignement général',
    cycles: ['lycee'],
    description: 'Seconde, Première, Terminale.',
  ),
  ModeleEtablissement(
    nom: 'Lycée avec collège',
    cycles: ['college', 'lycee'],
    description: 'Second degré complet, de la 6ᵉ à la Terminale.',
  ),
  ModeleEtablissement(
    nom: 'Lycée technique ou professionnel',
    cycles: ['formation_pro'],
    description: 'Les niveaux dépendent des filières ouvertes : '
        'choisissez-les ensuite.',
    choisirFilieres: true,
  ),
];

/// Le modèle qui décrit exactement cette combinaison de cycles, s'il existe.
///
/// Sert à afficher « c'est un CEG » plutôt que « collège » : une école déjà
/// configurée doit se reconnaître dans le modèle, sinon l'utilisateur croit
/// qu'en cliquer un effacerait son travail.
ModeleEtablissement? modelePour(Iterable<String> codesCycles) {
  final actuel = codesCycles.toSet();
  if (actuel.isEmpty) return null;
  for (final m in kModelesEtablissement) {
    if (m.cycles.length == actuel.length && actuel.containsAll(m.cycles)) {
      return m;
    }
  }
  return null;
}
