// ════════════════════════════════════════════════════════════════════════════
//  LIRE UN BOOLÉEN DANS LA BASE LOCALE
//
//  ── LE DÉFAUT QUE CE FICHIER EXISTE POUR EMPÊCHER ──────────────────────────
//  Une colonne booléenne arrive du SQLite de PowerSync sous trois formes :
//  `1`, `0`, ou **`null`** — cette dernière quand la ligne a été écrite par
//  l'application elle-même sans renseigner la colonne, la valeur par défaut
//  vivant côté serveur.
//
//  Le dépôt s'est doté partout du même petit helper : `_b(v) => v == 1 || v ==
//  true`. Il est JUSTE, mais seulement pour les booléens dont la valeur par
//  défaut est FAUSSE — `is_repeating`, `has_scholarship`, `is_published`. Pour
//  ceux dont la valeur par défaut est VRAIE, il inverse la réponse : l'absence
//  d'information devient « non ».
//
//  C'est ce qui est arrivé à `profiles.is_active` dans l'annuaire du personnel :
//  `is_active == 1` y rendait « inactif » un agent dont la colonne n'était pas
//  renseignée, pendant que le tableau de bord de la même école — qui écrit
//  `COALESCE(is_active, 1) <> 0` — le comptait parmi les agents en fonction.
//  Deux écrans, deux réponses, aucun moyen de savoir lequel croire.
//
//  ── POURQUOI DEUX FONCTIONS NOMMÉES, ET PAS UNE ────────────────────────────
//  Parce que la question « quelle est la valeur par défaut de cette colonne ? »
//  doit être posée à l'écriture du code, pas découverte à l'usage. Un helper
//  unique appelé `_b` ne la pose jamais.
//
//  ⚠️ Côté SQL, la forme correspondante est `COALESCE(is_active, 1) <> 0`,
//  imposée à l'échelle du dépôt par `offline_booleen_test.dart` — qui garde
//  aussi la forme Dart ci-dessous.
//
//  ⚠️ Ce fichier ne vaut que pour le chemin OFFLINE (SQLite de PowerSync,
//  valeur en `int?`). Les deux espaces qui lisent Supabase en direct —
//  `super_admin` et `admin_groupe` — reçoivent un `bool?` de PostgREST et ont
//  leur propre lecture : `core/utils/booleen_en_ligne.dart`.
// ════════════════════════════════════════════════════════════════════════════

/// Un booléen dont la valeur par défaut est **VRAIE** (`is_active`, et tout
/// `NOT NULL DEFAULT true`).
///
/// L'absence d'information vaut donc « oui » : une ligne que l'application
/// vient de créer est active tant que rien ne dit le contraire.
bool actifOffline(Object? valeur) => valeur != 0 && valeur != false;

/// Un booléen dont la valeur par défaut est **FAUSSE** (`is_repeating`,
/// `has_scholarship`, `is_boarder`, `is_published`…).
///
/// ⚠️ L'absence d'information vaut « non », et c'est irrattrapable : rien ne
/// distingue « faux » de « pas renseigné ». Une colonne par défaut fausse dont
/// la valeur compte doit donc être écrite EXPLICITEMENT à l'insertion — le
/// COALESCE ne sauve que le cas par défaut vrai.
bool vraiOffline(Object? valeur) => valeur == 1 || valeur == true;
