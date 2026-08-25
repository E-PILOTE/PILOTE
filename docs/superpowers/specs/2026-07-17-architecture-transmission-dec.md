# Architecture — E-PILOTE ↔ DEC : le système amont

**Date** : 2026-07-17 · **Statut** : décision d'architecture (aucun code écrit)
**Déclencheur** : « chaque ministère dispose déjà de son propre système d'inscription, indépendant de notre plateforme. Notre rôle consiste à produire des listes de candidats structurées, exploitables, imprimables et transférables. »

---

## 1. Ce que cette précision invalide dans ma conception

Je dois commencer par là. J'ai modélisé E-PILOTE comme **le** système d'inscription. C'est faux, et trois hypothèses en découlent qui sont à corriger :

| Ce que j'ai codé | Réalité | Correction |
|---|---|---|
| `exam_candidates.candidate_number` que **nous attribuons** | La DEC l'attribue | Champ **ENTRANT** : reçu, jamais généré |
| `exam_centers` = notre registre national | La DEC affecte les centres | **Information reçue**, pas gérée |
| `exam_sessions` = la vérité du calendrier | L'arrêté ministériel est la vérité | **Copie de référence**, sourcée et datée |
| Export PDF = un bouton | Le dépôt **engage l'école** | Il manque l'objet métier central (§3) |

**La bonne façon de nommer le rôle** : E-PILOTE est le **système amont** (préparation, contrôle, transmission). La DEC est le **système de référence** (inscription, centres, numéros, résultats). Entre les deux : une **frontière**, avec un flux sortant et un flux entrant.

Ce recadrage est une bonne nouvelle : il réduit le périmètre et clarifie la valeur. Nous ne concurrençons pas la DEC — nous lui livrons un dossier propre, et nous récupérons ses retours.

---

## 2. Le concept manquant : la TRANSMISSION

C'est **le** trou de ma conception, et il est grave.

Aujourd'hui, mon export recalcule le PDF depuis les données vivantes. Conséquence : la liste régénérée en juin **ne correspond plus** à celle déposée en février (un élève parti, un ajout tardif). L'école ne peut pas prouver ce qu'elle a déposé, ni quand.

Or le dépôt **engage l'établissement** : c'est daté, c'est opposable, et un candidat oublié perd une année.

**Décision : la transmission est un objet métier de premier rang, immuable.**

```
transmissions
├── id
├── kind          liste_candidats | liste_stagiaires | pv_resultats | rectificatif
├── recipient     dec_mepsa | dec_metp   (l'autorité destinataire)
├── session_id    → exam_sessions (pour une liste de candidats)
├── school_id / group_id
├── reference     EP-<code_école>-<AAAA>-<seq>   ← imprimé sur le document
├── status        brouillon | transmis | accuse_reception | traite | rejete
├── channel       pdf_depose | csv | api_dec        ← §4
├── snapshot      jsonb IMMUABLE — la liste telle que déposée
├── item_count
├── transmitted_at · transmitted_by
├── acknowledged_at · acknowledgment_ref   (récépissé de la DEC)
└── created_at / updated_at

transmission_items          (le détail figé, requêtable)
├── transmission_id
├── candidate_id            (lien vers la vie courante — peut évoluer)
├── local_ref               ← §5, la clé qui survit
└── payload   jsonb         nom, matricule, date de naissance, classe… GELÉS
```

**Pourquoi un snapshot ET des items ?** Le `snapshot` jsonb garantit l'immuabilité littérale (ce qui a été imprimé). Les `transmission_items` rendent le contenu requêtable (statistiques, réconciliation) sans re-parser du JSON.

**Ce que ça débloque immédiatement**, et qui n'existe pas aujourd'hui :
- « qu'avons-nous déposé, et quand ? » → une réponse opposable ;
- un **rectificatif** est une nouvelle transmission liée à la précédente, pas une modification qui réécrit l'histoire ;
- l'admin de groupe voit **quelles écoles ont transmis** et lesquelles traînent (§7) ;
- le jour où l'API existe, la transmission est **déjà** l'objet à envoyer.

---

## 3. La frontière : ports & adapters (le motif du projet)

Le projet a déjà résolu ce problème une fois : `lib/licensing/` est un **îlot hexagonal** (`domain/ports.dart` + `infrastructure/` avec les implémentations). On réutilise ce motif plutôt que d'en inventer un.

```
lib/examens/
├── domain/
│   ├── transmission.dart          l'objet métier
│   ├── ports.dart                 les INTERFACES (aucune dépendance technique)
│   │     abstract class DecGateway    { Future<Receipt> submit(Transmission t); }
│   │     abstract class DecResultsSource { Future<List<DecResult>> fetch(...); }
│   └── local_ref.dart             §5
├── application/                   cas d'usage : préparer, transmettre, réconcilier
├── infrastructure/
│   ├── manual_export_gateway.dart PDF/CSV -> dépôt physique   ← AUJOURD'HUI
│   ├── dec_api_gateway.dart       REST                        ← DEMAIN (si accès)
│   ├── csv_results_source.dart    fichier de résultats DEC     ← AUJOURD'HUI
│   └── manual_results_source.dart saisie à la main             ← AUJOURD'HUI
└── presentation/                  écrans
```

**La règle** : le domaine et l'UI ignorent **totalement** le canal. Passer du dépôt papier à l'API, c'est **ajouter un adaptateur** — pas réécrire le module. Une ligne change : quel adaptateur est injecté.

C'est exactement ce que vous demandez (« flexibles pour s'intégrer à des systèmes externes à l'avenir ») et c'est ce qui rend le pari sur l'API **gratuit** : on ne code rien pour l'API aujourd'hui, on se contente de ne pas se rendre incapable de l'ajouter.

**Et si l'API n'arrive jamais ?** Rien n'est perdu : l'adaptateur manuel est le chemin nominal, pas un pis-aller. Le coût de la frontière est d'environ une interface et une classe — trivial.

**Anti-corruption layer** : l'adaptateur API traduira le vocabulaire de la DEC vers le nôtre. Le domaine ne connaîtra jamais les champs de la DEC. Sans cette couche, le premier changement de leur schéma contaminerait tout le module.

---

## 4. La clé d'identité — le problème invisible qui coûte cher

Le jour où la DEC nous renvoie des numéros de candidat ou des résultats, **comment retrouver NOTRE élève ?**

La DEC ignore nos UUID. Les candidats reviennent identifiés par nom, date de naissance, éventuellement un numéro qu'elle a créé. Or :
- **nom + prénom** : les homonymes sont fréquents, et les orthographes varient d'un document à l'autre ;
- **date de naissance** : discriminante, mais souvent absente ou erronée dans les retours ;
- **matricule** : le nôtre — la DEC ne le connaît que si on le lui imprime.

**Décision : générer une référence locale stable, et l'imprimer sur la liste.**

```
local_ref = EP-<code_école>-<AAAA>-<séquence>     ex. EP-KIN01-2026-0042
```

Portée : immuable, unique par transmission d'origine, **lisible par un humain** (donc recopiable), imprimée en première colonne de la liste déposée.

- Si la DEC la renvoie (même sur papier) → réconciliation **exacte**, coût nul.
- Si elle ne la renvoie pas → repli sur nom + date de naissance, avec un **écran de réconciliation manuelle** pour les ambigus. Jamais d'appariement automatique silencieux : un résultat attribué au mauvais élève est pire qu'un résultat manquant.

Ça ne coûte rien aujourd'hui. Ne pas le faire coûtera un projet de rapprochement manuel plus tard.

---

## 5. Le flux entrant — récupérer les retours

Symétrique, même motif :

| Retour | Source réelle | Adaptateur |
|---|---|---|
| Numéros de candidat | Liste renvoyée par la DEC | CSV import · saisie · (API) |
| Affectation en centre | Convocation | saisie · (API) |
| Résultats | Publication officielle | CSV import · saisie · (API) |

**Règle d'or** : un retour est une **donnée reçue**, jamais une donnée que nous produisons. Elle porte sa **source** et sa **date de réception**. Si la DEC et nous divergeons, **la DEC a raison** — l'app doit le montrer, pas le masquer.

**Import idempotent** : rejouer deux fois le même fichier ne doit rien casser (clé = `local_ref` ou `candidate_number`). Motif déjà présent dans le projet (ledger idempotent des relances d'abonnement).

---

## 6. Le chaînage entre modules — ce qui « met en mouvement »

Votre remarque précédente reste la plus importante, et elle prend tout son sens ici : **un résultat d'examen doit retomber dans la scolarité.**

```
SCOLARITÉ ──élèves──▶ EXAMENS ──liste──▶ [TRANSMISSION] ──▶ DEC
                          ▲                                   │
STAGES ──attestation──────┘                            résultats
                          │                                   │
                          └──────────◀────────────────────────┘
                          │
                          ▼
        admis    → enrollment_status = 'graduated'   (valeur existante, JAMAIS utilisée)
        ajourné  → orientation / redoublement
```

**Comment faire communiquer les modules — sans sur-ingénierie.** Pas de bus d'événements : ce serait de l'astronautique dans une app offline-first à 5 modules concernés. Le projet a déjà le bon outil : **une fonction SQL de domaine**, appelée à la validation d'un résultat, qui applique la conséquence. C'est ce que fait déjà `resolve_class_exam()` — une règle, un endroit, testable en base.

Contrainte non négociable : **jamais de rejet serveur** dans ce chaînage. Un trigger qui refuse une écriture provoquerait la perte silencieuse à la synchro (le bug qui a déjà détruit une inscription ici). Les conséquences se **propagent**, elles n'**interdisent** pas.

---

## 7. L'espace ministère — recadré

Ma conception précédente était fausse ici aussi : je voulais construire « la gestion des examens nationaux ». **C'est le métier de la DEC, pas le nôtre.**

Mais MEPSA et METP **sont des tenants** de la plateforme (14 et 2 écoles en base). Leur besoin réel n'est pas d'organiser l'examen — c'est de **piloter leurs écoles avant le dépôt** :

- quelles écoles ont préparé leur liste, lesquelles n'ont rien fait ;
- combien de candidats par école / département / filière ;
- quels dossiers sont incomplets **avant** la clôture (le seul moment où c'est réparable) ;
- **consolider** les listes de plusieurs écoles en une transmission de groupe ;
- suivre les accusés de réception.

C'est un espace **admin_groupe** (online, Supabase direct), conforme à votre consigne « espace admin groupe en référence ». Pas un espace « DEC ».

**Statistiques nationales** : elles restent hors de portée tant que nous n'avons que nos tenants — nous ne voyons pas les écoles qui ne sont pas clientes. Prétendre publier un « taux de réussite national » serait un mensonge. On publie un taux **par groupe** et **par école**, ce qui est vrai.

---

## 8. Décisions, en clair

1. **E-PILOTE est le système amont.** `candidate_number`, `center_id`, `result` deviennent des champs **entrants**, marqués comme tels.
2. **La transmission est l'objet central**, immuable, référencée, datée, opposable.
3. **Ports & adapters** (motif `lib/licensing/`) : le canal (PDF/CSV aujourd'hui, API demain) est un détail d'infrastructure.
4. **`local_ref` imprimée** dès maintenant : la seule chose qui rendra une future réconciliation exacte.
5. **Réconciliation jamais silencieuse** : ambiguïté → écran de rapprochement humain.
6. **Chaînage par fonction SQL**, jamais par rejet serveur.
7. **Espace ministère = consolidation avant dépôt**, pas gestion d'examen.
8. **Pas de statistiques « nationales »** tant que le parc n'est pas national.

## 9. Ordre d'exécution

| # | Lot | Pourquoi d'abord |
|---|---|---|
| 1 | `local_ref` + transmissions (snapshot, référence, statut) | Sans elles, tout dépôt est non traçable — et rétroactivement irréparable |
| 2 | Liste des candidats = **génération d'une transmission** (au lieu d'un PDF volatil) | Le livrable devient un acte |
| 3 | Retours : import CSV + saisie + écran de réconciliation | Ferme la boucle |
| 4 | Chaînage résultat → `graduated` / orientation | Le « mise en mouvement » que vous demandez |
| 5 | Espace ministère : consolidation + suivi des dépôts | Valeur pour les 2 plus gros tenants |
| 6 | Convocations · PV de résultats | Les deux autres documents du métier |
| 7 | `DecApiGateway` | Le jour où la DEC ouvre — et pas avant |

## 10. Ce que je n'ai pas établi

- **Le format attendu par la DEC** (colonnes, ordre, format papier ou numérique) : inconnu. Nos exports sont conçus « raisonnables », pas conformes à un modèle officiel. **À obtenir avant industrialisation** — c'est le risque n°1 de ce lot.
- **L'existence d'un récépissé** de dépôt côté DEC : supposée, non vérifiée. Le champ existe, il restera vide si la pratique ne l'est pas.
- **Les stages** : « listes transmises aux ministères » — je ne sais pas si les stagiaires font l'objet d'un dépôt DEC ou si convention/attestation restent internes. Le modèle `transmissions.kind` absorbe les deux, mais la réponse change la priorité.
