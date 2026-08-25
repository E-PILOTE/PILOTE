// ════════════════════════════════════════════════════════════════════════════
//  VOCABULAIRE DE LA DISCIPLINE — source unique.
//
//  Les mêmes faits sont saisis par l'établissement (Vie scolaire, offline) et
//  relus par le ministère (dossier de l'élève, online). Deux listes séparées
//  finiraient par diverger, et un même incident s'appellerait « Indiscipline
//  en classe » d'un côté et autre chose de l'autre — pour un fait qui peut
//  fonder une sanction, c'est inacceptable.
//
//  Ce fichier ne dépend NI de PowerSync NI de Supabase : c'est ce qui permet
//  aux deux espaces de le partager sans que l'un traîne l'infrastructure de
//  l'autre.
// ════════════════════════════════════════════════════════════════════════════

const kIncidentTypes = <(String, String)>[
  ('retard_repete', 'Retards répétés'),
  ('absence_injustifiee', 'Absence injustifiée'),
  ('indiscipline', 'Indiscipline en classe'),
  ('violence', 'Violence / bagarre'),
  ('triche', 'Tricherie'),
  ('degradation', 'Dégradation de matériel'),
  ('manque_respect', 'Manque de respect'),
  ('autre', 'Autre'),
];

const kSanctions = <(String, String)>[
  ('avertissement', 'Avertissement'),
  ('travail_supplementaire', 'Travail supplémentaire'),
  ('retenue', 'Retenue'),
  ('exclusion_cours', 'Exclusion de cours'),
  ('exclusion_temporaire', 'Exclusion temporaire'),
  ('convocation_parents', 'Convocation des parents'),
  ('conseil_discipline', 'Conseil de discipline'),
  // La seule sanction qui met fin à une scolarité. Elle manquait : une école
  // qui excluait définitivement un élève n'avait aucun mot pour le dire, et
  // l'inscription restait `active` — l'enfant continuait de compter dans un
  // effectif où il n'était plus.
  ('exclusion_definitive', 'Exclusion définitive'),
  ('aucune', 'Aucune'),
];

/// Cette sanction met-elle fin à la scolarité dans l'établissement ?
///
/// Une exclusion TEMPORAIRE renvoie l'élève quelques jours ; une exclusion
/// DÉFINITIVE le renvoie tout court. Confondre les deux, c'est soit fermer
/// l'inscription d'un enfant qui revient lundi, soit laisser ouverte celle
/// d'un enfant qui ne reviendra jamais.
///
/// ⚠️ Cette fonction ne FERME rien : elle sert à PROPOSER. Une exclusion est
/// un acte de l'établissement — il se prononce, il ne se déduit pas.
bool sanctionMetFinALaScolarite(String? s) => s == 'exclusion_definitive';

String incidentTypeLabel(String? t) => kIncidentTypes
    .firstWhere((e) => e.$1 == t, orElse: () => ('autre', 'Autre'))
    .$2;

String sanctionLabel(String? s) => s == null || s.isEmpty
    ? '—'
    : kSanctions.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;
