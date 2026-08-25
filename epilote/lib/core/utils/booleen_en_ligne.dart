// ════════════════════════════════════════════════════════════════════════════
//  LIRE UN BOOLÉEN DANS UNE RÉPONSE SUPABASE (ESPACES EN LIGNE)
//
//  ── LE DÉFAUT QUE CE FICHIER EXISTE POUR EMPÊCHER ──────────────────────────
//  `school_groups.is_active` se lisait sous TROIS formes dans les deux espaces
//  qui interrogent Supabase en direct — dont deux dans le MÊME fichier :
//
//    super_dashboard_provider.dart:304   g['is_active'] == true          inactif
//    super_dashboard_provider.dart:341   grp['is_active'] as bool? ?? false
//                                                                       inactif
//    school_groups_provider.dart:64      m['is_active'] as bool? ?? true   actif
//
//  Même colonne, trois sémantiques, et ces valeurs alimentent les compteurs de
//  l'opérateur de plateforme (« groupes actifs »). Deux lectures analogues
//  comptaient de la même façon les écoles et le personnel actifs d'un groupe
//  (`admin_settings_provider.dart`).
//
//  ── CE QUE DIT LA BASE (vérifié sur le LIVE le 18/08/2026) ─────────────────
//  `school_groups.is_active`, `schools.is_active` et `profiles.is_active` sont
//  toutes `is_nullable = NO`, `column_default = true`, et aucune migration ne
//  les a jamais desserrées : le seul `DROP NOT NULL` du dépôt porte sur
//  `fee_structures.school_id` (0096). Comptage du même jour : 0 ligne NULL —
//  et même 0 ligne à `false` — sur 7 groupes, 37 écoles, 344 profils.
//
//  Autrement dit, les trois lectures rendaient EXACTEMENT le même chiffre sur
//  la donnée réelle. C'est précisément ce qui rendait la divergence dangereuse :
//  elle ne se voyait sur aucun écran.
//
//  ── PAR OÙ LE NULL ARRIVE QUAND MÊME ───────────────────────────────────────
//  `map['is_active']` rend `null` pour deux raisons indiscernables : la colonne
//  vaut NULL (impossible ici), ou **elle n'est pas dans le `select()`**. Le
//  second cas est déjà arrivé au dépôt — le bucket `directory` ne projetait
//  aucune colonne de carrière. Le jour où un `select()` perd `is_active`,
//  `== true` et `?? false` annoncent « 0 groupe actif » à l'opérateur : pas
//  d'erreur, pas de ligne manquante, juste un compteur faux. `?? true` rend le
//  défaut de la colonne et reste juste.
//
//  C'est aussi la lecture qui tient si le `NOT NULL` sautait un jour : une
//  ligne NULL serait alors une ligne que le serveur n'a pas encore défautée,
//  donc active.
//
//  ── POURQUOI PAS `actifOffline()` ──────────────────────────────────────────
//  `core/utils/booleen_offline.dart` traite l'AUTRE chemin de données : le
//  SQLite de PowerSync, où la colonne arrive en `int?` et où le null vient de
//  l'écriture locale. Ici la valeur vient de PostgREST en `bool?` et le null
//  vient de la projection. Les deux fonctions se ressemblent ; leur cause, leur
//  type et leur garde-fou diffèrent, et confondre les deux chemins est
//  exactement ce qui a produit la divergence ci-dessus.
//
//  ⚠️ Cette fonction ne vaut QUE pour les colonnes dont le défaut est VRAI.
//  Pour un défaut FAUX (`payment_configs.is_active`, `is_published`…) l'absence
//  vaut « non », et c'est irrattrapable — rien ne distingue « faux » de « pas
//  renseigné ». Ces lectures gardent leur `?? false`, qui est juste.
// ════════════════════════════════════════════════════════════════════════════

/// Un booléen lu dans une réponse Supabase, dont la valeur par défaut en base
/// est **VRAIE** (`school_groups.is_active`, `schools.is_active`,
/// `profiles.is_active`, et tout `NOT NULL DEFAULT TRUE`).
///
/// L'absence d'information vaut donc « oui » : elle signifie que la colonne
/// n'était pas dans le `select()`, pas que la ligne est désactivée.
///
/// Le paramètre est `Object?` et non `bool?` : une lecture de map rend
/// `dynamic`, et un état officiel qui ne sait pas lire une valeur doit montrer
/// la ligne plutôt que la faire disparaître — un surplus visible se corrige,
/// une absence silencieuse non.
bool actifEnLigne(Object? valeur) => valeur != false && valeur != 0;
