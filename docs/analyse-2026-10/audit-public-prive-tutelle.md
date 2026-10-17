# Audit — groupe public (ministère), groupe privé et lien de tutelle

**Relevé du 2026-10-17, base de production `wqpdamlnrwgozfvzjjpo`.** Tout ce
qui suit a été mesuré en base ou lu dans le code ce jour-là. Un seul test a
écrit : il tournait dans une transaction annulée de force, et le retour à
l'état initial a été vérifié.

## Le parc tel qu'il est

| Groupe | Secteur | Ministère ? | Tutelle | Plan | Statut | Échéance | Écoles (facturées) | Élèves |
|---|---|---|---|---|---|---|---|---|
| MEPSA — Ministère Enseign. Primaire | public | **oui** | mepsa | Licence de tutelle | active | — | 14 | 3 781 |
| Ministère de l'Enseignement Technique et Professionnel | public | **oui** | metp | Licence de tutelle | active | — | 12 | 1 902 |
| Groupe Scolaire EDEC | **public** | **non** | mepsa | Institutionnel | **expired** | 31/07/2026 | 2 (2) | 1 725 |
| Institut Savorgnan de Brazza | **public** | **non** | mepsa | Institutionnel | active | 31/12/2026 | 2 (2) | 850 |
| Centre de Formation Technique Nsangu | privé | non | metp | Standard | trial | 31/10/2026 | 2 (**1**) | 358 |
| Complexe Professionnel La Fraternité | privé | non | metp | Standard | **expired** | 30/09/2026 | 2 (**1**) | 328 |
| Groupe Scolaire Bethel | privé | non | mepsa | Découverte | active | 15/07/2027 | 1 (1) | **237 / 100** |
| Groupe Scolaire Technique Saint-Joseph | privé | non | metp | Pro | **expired** | 30/09/2026 | 3 (**1**) | 446 |
| Réseau Scolaire Horizon | privé | non | mepsa | Pro | active | 31/12/2026 | 3 (3) | 374 |
| Réseau Scolaire Saint-Pierre | privé | non | mepsa | Standard | active | 31/12/2026 | 3 (3) | 363 |

Comment le lien est câblé : un groupe porte `tutelle` (enum `mepsa|metp`,
NOT NULL). Un déclencheur l'**impose** à chacune de ses écoles
(`fn_school_herite_tutelle`). Le ministère est **le** groupe qui porte
`administre_referentiel_national = true` pour cette valeur d'enum (index
unique 0178). Le ministère lit son réseau par trois RPC `SECURITY DEFINER`
(`tutelle_groupes`, `tutelle_ecoles`, `tutelle_destinataires`), toutes gardées
par `auth_peut_superviser()`, et filtrées sur `schools.tutelle`.

---

## 🔴 CRITIQUE — l'argent et la règle de base

### C1. Encaisser une facture restée en attente fait RECULER l'abonnement (vérifié)

`INV-2026-0043` (Saint-Joseph, 50 000 XAF) couvre la période du 01/10/2025 au
01/11/2025. Cette période est déjà payée par l'annuel `INV-2026-0051`
(1 800 000 XAF, réglé). Le groupe est `expired`. Or `mark_invoice_paid`
applique « la période payée fait foi » à tout groupe qui n'est pas `active`.

Test en transaction annulée, avec un compte super_admin :

```
{"success": true, "amount_xaf": 50000, "period_end": "2025-11-01"}
→ statut = active, fin = 2025-11-01
```

Le client paie 50 000 XAF pour un mois déjà payé il y a un an. Il reçoit
« Votre abonnement est actif jusqu'au **01/11/2025** », puis
`expire_subscriptions` le repasse en `expired` à 01 h 05. Le même piège attend
`INV-2026-0044` (La Fraternité, 30 000), `INV-2026-0045` (Nsangu, 30 000,
pour janvier-février 2026) et `INV-2026-0040` (EDEC).

**Correctif** : refuser de solder une facture dont la période est entièrement
passée ou déjà couverte par une facture payée. Pour un groupe non actif,
`v_new_end` doit valoir au moins `CURRENT_DATE + durée`, jamais une date
passée.

### C2. Une facture en attente bloque la facturation automatique pour toujours

`_emettre_facture_renouvellement` renvoie `already_pending` dès qu'**une**
facture `pending` ou `overdue` existe, **quelle que soit sa période**.
Conséquences mesurées :

- **La Fraternité** et **Saint-Joseph** sont échues depuis le 30/09, soit
  **17 jours**. La boucle de nuit `emettre-factures` tourne et réussit chaque
  jour, mais elle n'a émis **aucune** facture de renouvellement : elle bute sur
  la facture d'octobre 2025.
- **Nsangu** fera de même au 31/10 (`INV-0045`, janvier 2026).
- **EDEC** : sa seule facture (52 000, en attente) date du 04/09, pour une
  échéance passée le 31/07.

Le revenu de ces groupes est arrêté, sans aucun signal (« 1 row », succès).
Les quatre factures restantes réclament en outre des mois déjà payés ou
antérieurs à la création du groupe, qui date du 06/09/2026.

**Correctif** : comparer la PÉRIODE de la facture à l'échéance à couvrir. Une
facture en attente sur une période échue ne bloque pas un renouvellement.
⚠️ Les quatre factures sont des faits comptables : à annuler (statut
`cancelled` + motif), jamais à supprimer. **Décision à prendre par toi.**

### C3. « Public ⇒ ministère » n'existe nulle part dans la plateforme

Ta règle : un groupe public est nécessairement un ministère. La base dit
l'inverse : **EDEC** et **Savorgnan de Brazza** sont `public` sans être
ministère. Ils comptent 4 écoles et 2 575 élèves, soit **26 % des élèves du
parc**.

- Le formulaire de groupe propose le secteur et l'interrupteur « ministère »
  comme deux champs indépendants (`group_form_modal.dart:176` et `:190`).
  Aucune contrainte en base ne les relie.
- Leur plan « Institutionnel » est `is_public_plan = true`. ~~Un plan public
  n'est jamais soumis au hard-lock.~~ **Rectifié le même jour** :
  `license-issuer` émet `hard_lock: true` pour **tous** les groupes
  (ADR-0009) ; c'est un commentaire Dart périmé qui le laissait croire.
- EDEC est échu depuis le **31/07, soit 78 jours**. L'admin du groupe est en
  lecture seule, mais les écoles, qui travaillent hors ligne, ne peuvent pas
  être bloquées.
- Le sens inverse est tenu, indirectement : un ministère est forcément sur le
  plan Licence, ce plan est public, et un plan public refuse un groupe privé.

**Décision à prendre par toi** :

- (a) Ta règle s'applique. Il faut une contrainte
  `group_type = 'public' ⇒ administre_referentiel_national`, et EDEC et
  Savorgnan doivent devenir soit privés, soit des écoles d'un ministère.
- (b) Ce sont des opérateurs publics tiers légitimes. Il faut alors écrire
  qu'ils paient au mois **sans** hard-lock, et en assumer le risque.

La mémoire projet retenait (b), le 2 septembre. Ta phrase d'aujourd'hui dit (a).

---

## 🟠 MAJEUR — le lien entre un groupe privé et son ministère

### M1. Le lien n'a jamais servi, et il ne marche que dans un sens

- **0 message** échangé entre un ministère et un groupe privé, dans un sens
  comme dans l'autre.
- Le ministère peut écrire, via `tutelle_destinataires`. Le groupe privé ne
  peut pas initier : `correspondants_ministere()` ne rend un ministère que si
  une conversation **existe déjà**, et `profiles_select` borne l'annuaire au
  groupe. Une école privée ne peut donc ni signaler, ni demander, ni répondre
  à une sollicitation qu'elle n'a pas reçue.
- Nulle part l'espace d'un groupe privé ne lui dit qui est son ministère de
  tutelle. Le sigle n'apparaît que dans un champ en lecture seule du
  formulaire d'école (`school_institution_type_field.dart:115`) et sur le PDF
  d'état de rentrée.

### M2. Le lien est un enum, pas le ministère lui-même

Un groupe privé est « sous MEPSA » parce qu'il porte la valeur `mepsa`, et non
parce qu'il pointe le groupe ministère. Le retrait du rôle de tutelle n'est
« jamais bloqué » (décision 0178). Si on le retire au MEPSA :

- les 5 groupes et 11 écoles de MEPSA n'ont plus de superviseur ;
- le référentiel national `mepsa` (5 examens) n'a plus d'écrivain ;
- **rien ne le signale**, ni à l'écran ni en base.

C'est le trou que 0179 a fermé pour la suppression, mais pas pour le retrait.

### M3. Un groupe sans école est invisible pour son ministère

`tutelle_groupes` fait une **jointure** sur `schools` (`JOIN`, pas
`LEFT JOIN`), et `tutelle_destinataires` exige une école. Un groupe privé tout
juste créé sous METP n'apparaît donc pas chez le METP, et lui écrire renvoie
« Ce groupe n'est pas placé sous votre tutelle ». Ce cas ne concerne aucun
groupe aujourd'hui, mais **chaque création passe par cet état**.

### M4. Un groupe ne relève que d'un seul ministère, et l'école n'a pas son mot

`fn_school_herite_tutelle` **écrase** `schools.tutelle` à chaque INSERT ou
UPDATE. Un promoteur privé qui possède une école primaire (MEPSA) et un lycée
technique (METP) doit être scindé en deux groupes : deux abonnements, deux
administrateurs, deux tableaux de bord. Le code l'assume
(`group_tutelle_selector.dart:10` : « un groupe n'est jamais mixte »), mais
c'est un choix de modèle, pas une vérité du terrain. Saint-Joseph et Nsangu
sont précisément des complexes. **Décision à prendre par toi.**

### M5. L'agrément est saisi au groupe et recopié de force sur chaque école

`fn_school_herite_agrement` réécrase le numéro, le type et la date à
**chaque** mise à jour d'une école. Or un agrément autorise l'ouverture **d'un
établissement**. Résultat : les 3 écoles de Saint-Joseph portent le même
numéro, et aucune école ne peut avoir le sien. L'admin du groupe ne peut pas le
saisir non plus : le garde de colonnes 0154 l'interdit. Mesuré : **4 groupes
privés sur 6 n'ont aucun agrément**, et ils fonctionnent normalement. La KPI
« agrément » du ministère reste donc creuse.

### M6. La chaîne administrative MEPSA est vide

- Le référentiel `inspections` contient **10 circonscriptions, toutes METP**.
  MEPSA : **zéro**.
- **25 écoles sur 44** n'ont ni inspection ni type d'établissement : ce sont
  exactement toutes les écoles du côté MEPSA (le ministère, EDEC, Savorgnan,
  Bethel, Horizon, Saint-Pierre).
- `schools.inspection_id` n'est **ni lu ni écrit** par l'application : aucun
  écran ne le renseigne. Le côté METP n'est complet que parce que le seed l'a
  rempli.

Un ministère qui veut ventiler son réseau par circonscription ne le peut pas
aujourd'hui.

### M7. L'assiette facturée est fausse sur 3 groupes privés sur 6

`billed_schools` vaut 1 alors que Nsangu a 2 écoles, La Fraternité 2 et
Saint-Joseph 3. `fn_regularize_school_count` s'arrête dans trois cas :
`auth.uid()` nul (seed, script), groupe non actif, ou essai en cours.
Conséquence directe : la facture d'essai de Nsangu est à **30 000** (une
école) alors que le tarif réel est **40 000** (deux écoles). Le
renouvellement recalcule correctement, mais il est bloqué par C2.

### M8. Les quotas du plan gratuit ne tiennent pas

Bethel est sur Découverte (100 élèves maximum) et compte **237 élèves actifs**.
Son échéance est fixée au 15/07/2027, soit 14 mois et demi gratuits. Le quota
d'élèves n'est appliqué nulle part sur le chemin hors ligne.

### M9. La licence d'un ministère n'a ni terme ni effet

- Aucune fonction n'écrit le statut `echue` : le 31/12/2026, les deux licences
  resteront « active ».
- `auth_peut_superviser()` ignore complètement la licence. Seul
  `acces_suspendu` coupe l'accès, et c'est voulu (0187). Mais une licence échue
  ou résiliée ne change donc **rien**.
- Mesuré : **0 XAF réglé sur 80 M**, et ni référence de marché ni signataire
  sur l'une ou l'autre.

---

## 🟡 MINEUR

- **m1** Le nom du MEPSA en base est tronqué et inexact (« Ministère Enseign.
  Primaire »). MEPSA désigne le Primaire, le **Secondaire** et
  l'Alphabétisation. L'autre ministère est écrit en toutes lettres. Ce nom brut
  sort partout où `nomAffichableGroupe` n'est pas utilisé.
- **m2** Nsangu : groupe créé le 06/09/2026, essai « commencé » le 15/01/2026,
  soit un essai de 9 mois et demi, avec une facture d'essai rétrodatée.
- **m3** `tutelle_groupes` compte les élèves des écoles **inactives** dans le
  total du groupe (le filtre `is_active` ne porte que sur le nombre d'écoles).
- **m4** Le bucket PowerSync `circulaires_ecole` est toujours synchronisé
  alors que la fonctionnalité a été retirée (0 ligne : sans coût, mais c'est du
  code mort).
- **m5** `auth_peut_superviser`, `auth_group_tutelle`,
  `licence_changer_statut`, `circulaire_publier`, etc. sont exécutables par
  `anon` / `PUBLIC`. Toutes se refusent elles-mêmes, donc il n'y a pas de
  fuite, mais c'est contraire à la règle du projet (`REVOKE ... FROM PUBLIC`).

## ✅ Vérifié sain

- Un seul ministère par tutelle : index unique **et** déclencheur.
- Un ministère ne se supprime pas (23514) ; un groupe privé, si (23503).
- Plan Licence ⇔ ministère, dans les deux sens. Un groupe privé ne peut pas
  être sur un plan public.
- Secteur école = secteur groupe et tutelle école = tutelle groupe :
  **0 incohérence sur 44 écoles**. Type d'établissement cohérent avec la
  tutelle : 0 écart.
- Les RPC de tutelle refusent un groupe privé (42501) et filtrent sur la
  tutelle de l'appelant. Un ministère ne voit pas les écoles de l'autre.
- Un admin de groupe ne peut écrire ni `tutelle`, ni
  `administre_referentiel_national`, ni l'agrément (garde de colonnes).
- La table `inspections`, lisible par tout compte authentifié, est un
  référentiel public, sans donnée d'école : ce n'est pas une fuite.

## Ordre de traitement proposé

1. **C1 + C2** (argent, sans décision de fond) : corriger
   `mark_invoice_paid` et `_emettre_facture_renouvellement`, puis annuler
   proprement les quatre factures caduques, **avec ton accord**.
2. **C3, M4, M5** : trois décisions de modèle qui t'appartiennent.
3. **M1, M2, M3** : rendre le lien réel dans les deux sens. Afficher « votre
   ministère », permettre au privé d'écrire, alerter sur un retrait de rôle
   qui orpheline un réseau, voir un groupe sans école.
4. **M6–M9**, puis les mineurs.
