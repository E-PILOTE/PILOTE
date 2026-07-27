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
  ('aucune', 'Aucune'),
];

String incidentTypeLabel(String? t) => kIncidentTypes
    .firstWhere((e) => e.$1 == t, orElse: () => ('autre', 'Autre'))
    .$2;

String sanctionLabel(String? s) => s == null || s.isEmpty
    ? '—'
    : kSanctions.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;
