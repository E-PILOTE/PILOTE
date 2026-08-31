---
name: tarif-par-ecole-et-couts-reels
description: "Le prix suit le NOMBRE D'ÉCOLES (mig 0159) ; la falaise Pro→Institutionnel valait ×11,4 ; infra réelle ≈ 45 140 XAF/mois ; ⚠️ REVOKE FROM PUBLIC, pas des rôles"
metadata: 
  node_type: memory
  type: project
---

**2026-08-31 — appliqué et vérifié en production.** Ancrage donné par
l'utilisateur : 1 école = 30 000 XAF/mois, 2 écoles = 40 000.

## Le défaut qu'on a supprimé

Ancienne grille : Pro 220 000/mois jusqu'à **10 écoles**, puis Institutionnel
2 500 000/mois. **La 11ᵉ école coûtait ×11,4.** Un groupe à 11 écoles n'avait que
trois issues : refuser, partir, ou déclarer dix écoles. Les DEUX ministères
étaient exactement dans ce trou (MEPSA 14 écoles, METP 12) et payaient un prix
sans rapport avec ce qu'ils consommaient.

## Le modèle

**Le PLAN vend des MODULES. Le NOMBRE D'ÉCOLES fait le PRIX.**
`prix = base + Σ (écoles de la tranche × tarif de tranche)`, tranches
**2-5 · 6-10 · 11-20 · 21+**, dégressives.

| plan | 1 école | 2-5 | 6-10 | 11-20 | 21+ | modules |
|---|---|---|---|---|---|---|
| Découverte | 0 | — | — | — | — | 7 (1 école, 100 élèves) |
| Standard | 30 000 | 10 000 | 8 000 | 6 000 | 4 000 | 17 |
| Pro | 50 000 | 16 000 | 13 000 | 10 000 | 7 000 | 30 |
| Institutionnel | 40 000 | 12 000 | 10 000 | 8 000 | 5 000 | 32 — **secteur public** |

⚠️ Institutionnel est moins cher par école que Pro **avec plus de modules** :
c'est le plan du secteur public (budget d'État, aucun hard-lock). Un déclencheur
(`fn_plan_coherent_avec_secteur`) refuse désormais qu'un groupe `prive` s'y pose
— sinon il échappait au hard-lock **en silence, pour toujours**, et aucun écran
ne l'aurait montré.

⚠️ **Quotas écoles/élèves/personnel à -1 sur les plans payants.** Bloquer la
croissance d'un client qui paie À L'ÉCOLE est absurde : le prix est la limite.

## Les pièges de cette migration

- **Quatre fonctions lisaient `price_xaf` en direct** : `fn_auto_create_invoice`,
  `create_renewal_invoice`, `fn_regularize_plan_change` et — celle qu'on a
  failli manquer — `backfill_missing_invoices`. Toutes réécrites. En oublier une
  aurait facturé la base seule pour un réseau de huit écoles, **facture marquée
  « payée »** si le groupe était actif.
- **Miroir Dart obligatoire** : `lib/core/utils/tarif_ecoles.dart` ↔
  `plan_price_xaf()`. `test/tarif_ecoles_test.dart` relit la migration et exige
  les mêmes ancrages. Divergence = l'écran annonce un prix que la facture
  contredit, découvert par le client un mois plus tard.
- **Le MRR ne peut plus s'écrire `tarif × abonnés`** : deux groupes du même plan
  ne paient plus pareil. Calculé groupe par groupe dans `plans_provider`. L'ancienne
  formule ne plantait pas — elle **sous-estimait** d'autant que les réseaux sont grands.
- `school_groups.billed_schools` = l'assiette de la dernière facture. Répond à
  « sur combien d'écoles m'avez-vous facturé ? », que le client POSERA.
- `school_groups.price_override_xaf` = tarif négocié qui remplace la grille.
  Sert au maintien de prix d'un client antérieur comme à un accord particulier.

## Ce que l'infrastructure coûte VRAIMENT (relevé 2026-08-31)

| poste | tarif | inclus |
|---|---|---|
| Supabase Pro | 25 $/mois | compute/disque/egress **facturés en plus** |
| PowerSync Cloud Pro | 49 $/mois | 30 Go synchro · **1 000 clients simultanés** ; puis 1 $/Go et 30 $/1 000 clients |

Soit ≈ **45 140 XAF/mois** : **deux groupes mono-école** couvrent le plancher.
Le coût marginal d'une école (~0,2 à 0,5 $/mois) est sans commune mesure avec
30 000 XAF — **le prix par école est économiquement sûr**.

⚠️ **Le poste qui décroche en premier n'est pas le nombre d'élèves, c'est le
nombre d'APPAREILS.** Chaque poste avec l'application ouverte = 1 client
simultané. À ~8 postes par école, **125 écoles saturent les 1 000 inclus**.

⚠️ **Le plan gratuit n'est pas gratuit POUR NOUS** : un groupe Découverte
consomme clients simultanés et Go synchronisés sans rien rapporter. C'est le
client le plus cher par franc encaissé — d'où le quota serré (1 école, 100 élèves).

Saisi dans `platform_costs` (RLS : **super_admin seul**), écran
`/super/economie`. ⚠️ `montant_xaf` = ce que la banque débite, fait foi ; la
devise n'est là que pour mémoire. **Aucun taux de change n'est stocké** : figé
en base, il devient faux le mois suivant et personne ne le voit.

Voir [[abonnement-licence-de-tutelle]] · [[abonnement-referentiel-tarifaire]]
