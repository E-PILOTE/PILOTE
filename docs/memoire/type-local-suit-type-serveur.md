---
name: type-local-suit-type-serveur
description: "Une colonne PowerSync locale typée différemment du serveur fait perdre TOUT le lot d'écritures (22P02)"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-07-29T09:31:15.901Z
---

# Le type local doit suivre le type serveur — sinon PowerSync perd le lot

**2026-07-29.** `student_payments.amount_xaf` = `integer` en Postgres (le franc
CFA n'a pas de subdivision), mais déclaré `Column.real` dans
`powersync_schema.dart`. SQLite stockait `10000.0`, le connecteur l'envoyait
tel quel, Postgres refusait :

```
invalid input syntax for type integer: "10000.0"   (SQLSTATE 22P02)
```

⚠️ **PowerSync n'écarte pas la ligne fautive : il ABANDONNE la transaction
entière.** Chaque paiement encaissé hors ligne disparaissait, avec toutes les
écritures du même lot. Silencieux, et sur de l'argent.

**Why:** même famille que [[perte-silencieuse-identifiants-vides]] — une valeur
invalide ne coûte pas une ligne, elle coûte le LOT. Le journal d'échecs
([[sync-failure-journal]]) est ce qui a rendu la panne visible : sans lui, rien
à l'écran.

**How to apply:**
- Toute colonne numérique du schéma local doit avoir le type de la colonne
  serveur. `real` ↔ `numeric`/`double precision` : OK. `real` ↔ `integer` :
  **perte de données**.
- Garde-fou : `test/powersync_money_columns_test.dart` — aucune colonne `_xaf`
  ne peut être `real`. Vérifié non vide (il échoue sur l'ancien schéma).
- Audit fait le 2026-07-29 : c'était la SEULE divergence du schéma. Les autres
  `real` (average, class_average, score, max_score, min_average,
  overall_average, weighted_average, evaluation_grade, fee_amount, latitude,
  longitude) font face à `numeric`/`double precision` — légitimes.
- Requête d'audit : comparer `Column.real(...)` du schéma local à
  `information_schema.columns` du live.

## Fenêtres de calcul — deux pièges du même jour
- **« Élèves à jour »** se comptait sur le MOIS CIVIL : 0 % le 1er de chaque
  mois et pendant les vacances de juillet-août, alors que la page Rapports
  comptait sur l'année et affichait 69 %. La scolarité se règle par TRANCHES
  sur l'année scolaire (sept→juin) — c'est la fenêtre à retenir.
- **« Revenus du mois »** tombait à zéro faute d'encaissement dans le mois
  courant. On montre le dernier mois encaissé **en le nommant** — même règle
  que [[reseau-vs-national-reference]] : un chiffre d'une autre période ne
  s'affiche jamais sans sa date.

Liens : [[perte-silencieuse-identifiants-vides]] · [[sync-failure-journal]] ·
[[inscription-validation-effectif-a-verifier]]
