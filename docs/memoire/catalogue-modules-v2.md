---
name: catalogue-modules-v2
description: "Catalogue refondu : 6 catégories / 28 modules, rôles nets, aligné système éducatif Congo"
metadata: 
  node_type: memory
  type: project
  originSessionId: fbfd7c02-473f-415b-b6e1-a21454a8de92
---

REFONTE CATALOGUE (2026-06-06). Suppression des modules fantômes/redondants + réorganisation par rôle clair, aligné MEPSA/METP. Catalogue passé de 36→**28 modules**, 7→**6 catégories**.

**Catégories (slug) + modules :**
1. **SCOLARITÉ** (`scolarite`) : Élèves · Inscriptions · Transferts · Documents · Annuaire
2. **ENSEIGNEMENT** (`enseignement`) : Classes · Niveaux · Matières · Programmes · Emploi du Temps · Cahier de Textes
3. **ÉVALUATION** (`evaluation`, NOUVELLE) : Évaluations & Notes · Bulletins · Conseils de Classe
4. **VIE SCOLAIRE** (`vie-scolaire`) : Présences Élèves · Discipline · Orientation · Infirmerie · Cantine · Bibliothèque
5. **FINANCE** (`finance`) : Frais de Scolarité · Paiements Élèves · Dépenses · Budget
6. **RESSOURCES HUMAINES** (`rh`) : Personnel · Présences Personnel · Congés · Paie

**Supprimés (8)** : `evaluations` (fusionné dans `notes` → renommé « Évaluations & Notes »), `resultats` & `comptabilite` (dérivés/agrégats → iront dans Rapports), `mobile-money` (canal de paiement, pas module), `facturation-ecole` (= billing SaaS, couche admin), `devoirs-en-ligne` + `rapport-ia` + `suggestions-ia` (online, contredisent offline-first ; décision user : retirés du catalogue école). Catégories `ressources` (Bibliothèque déplacée en Vie scolaire) et `ia` supprimées.

**Renommages slug catégorie** : `scolarisation`→`scolarite`, `pedagogie`→`enseignement` (+ split → nouvelle `evaluation`).

**⚠️ COUPLAGE CODE** : les presets de profils d'accès (`admin_access_screen.dart`, `_kPresets`) référencent les slugs de catégorie EN DUR (`grantFor(catSlug, modSlug)`). Mis à jour vers les nouveaux slugs (pedagogie scindé → enseignement+evaluation, ressources/ia retirés). **Tout changement futur de slug catégorie DOIT être répercuté dans ce fichier** sinon presets incomplets (pas de crash, juste grants manquants). C'est le SEUL fichier qui hardcode les slugs catégorie.

Plans recalculés (`module_count`). analyze 0 issue, app relancée ✓. Lié : [[modules-natifs-communication]], [[modules-acces-hierarchie]].