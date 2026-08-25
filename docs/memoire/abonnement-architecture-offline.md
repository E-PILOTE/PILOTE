---
name: abonnement-architecture-offline
description: "Architecture métier/fonctionnelle validée du système d'abonnement offline-first (phase design, pas encore codée)"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

Design fonctionnel du système d'abonnement E-PILOTE, validé en session 2026-07-04 (phase règles métier + architecture, AUCUN code écrit encore). Le tenant facturé = le **groupe scolaire** (pas l'école).

**Deux concepts séparés (clé de voûte)** :
- **Abonnement (Subscription)** = vérité contractuelle, serveur-only, mutable, porte états + facturation.
- **Licence (License/Entitlement)** = projection signée, immuable, versionnée de l'abonnement, taillée pour l'offline. Jetable : à chaque changement on ÉMET une nouvelle licence (jamais d'édition). ⚠️ NE PAS modéliser la licence comme table PowerSync éditable — c'est un artefact signé poussé en sens unique.

**Source de vérité unique** : serveur seul émet/modifie ; client = pur applicateur (vérifie signature + applique droits, ne crée jamais de droit). Le client remonte des faits (usage/quota) = preuves, pas autorité.

**Deux horloges INDÉPENDANTES** :
1. Expiration métier = date de fin, calculée EN LOCAL, pilote cascade grâce→lecture seule→restriction (jamais de purge, jamais blocage sec, fenêtre examens prime).
2. Fenêtre de confiance (Trust Window, champ `max_offline_duration`, ~30-45j) = temps hors ligne sans revalidation ; comble l'angle mort de la RÉVOCATION (suspension/impayé imprévisibles). Dégrade en douceur, pas un couperet.

**Sécurité** : signature ASYMÉTRIQUE (jamais HMAC) ; version monotone anti-rejeu (ancre réelle = serveur, pas le local → 1ʳᵉ activation online obligatoire re-sème ; restore doit revalider online) ; repère temporel haute-eau anti-recul-horloge (anomalie ≠ fraude auto, piles CMOS mortes fréquentes au Congo).

**Punch-list conditionnant l'approbation (traiter comme 1ʳᵉ classe)** :
- **A. Quotas SOUPLES** (le plus important) : consommation offline multi-appareils inbornable en dur → autoriser dépassement + réconcilier à la synchro (upsell). NE JAMAIS bloquer une inscription hors ligne.
- **B. Noyau irréductible** : appareil hors-ligne+horloge figée = inenforçable par crypto ; le vrai backstop = dépendance opérationnelle à la synchro (l'école DOIT se reconnecter). Trust window = fil-piège, pas rempart.
- **C. Fail-soft / rayon de souffle** : licence illisible → état utilisable-mais-alerté, jamais écran noir ; feature-flag serveur d'assouplissement + rollout progressif (sinon on brique le parc national pendant les examens).
- **D. Clé de signature** = secret n°1 (service isolé, clé publique épinglée+versionnée).
- **E. Révocation urgente** = best-effort jusqu'à reconnexion (fenêtre paramétrable par risque).
- **F. Downgrade offline** : retirer l'accès module, jamais détruire les données créées sous ce module.

**Stress-test adversarial (2026-07-04, note 7/10 → 9/10 si corrigé). 5 trous BLOQUANTS avant dev** :
- 🔴 **C4 paiement refusé après émission** (mortel sur mobile money) : NE JAMAIS émettre licence pleine sur paiement non confirmé → 2 étages = licence PROVISOIRE courte (3-7j) sur paiement en attente, licence plein terme sur règlement confirmé.
- 🔴 **F2/F3 clé de signature** : rotation mal orchestrée OU clé privée volée = brique/gratuité fleet-wide → key-id multi-clés dans l'en-tête + chevauchement + ordre (distribuer vérificateur AVANT basculer signataire) ; clé privée en HSM/service isolé ; licences courtes limitent le rayon d'une clé volée.
- ❌ **N8 première activation en zone déjà hors ligne** (cœur de cible rural) : activation online obligatoire = onboarding impossible → prévoir canal d'activation OFFLINE (pré-activation avant expédition, ou paquet d'activation signé USB/QR ingéré une fois).
- ❌ **G3 + G2-avance verrouillage d'écoles HONNÊTES** (risque réputationnel n°1) : fenêtre rigide OU horloge réglée en avance → école payante bloquée → fenêtre GÉNÉREUSE + adaptative par zone, dégradation douce réversible, fail-soft sur anomalie d'horloge, biais assumé vers la DISPONIBILITÉ, temps avancé via minuterie monotone (pas horloge murale absolue).
- ⚠️ **E1/E2 cycle de vie du tenant** (fusion/scission d'établissements) : purement non conçu → processus de supersession de licence + migration données inter-tenant à spécifier.

Autres trouvailles : liaison licence au TENANT pas au matériel (device-bind dur = cauchemar support sur matériel Congo) ; vérifier `licence.group_id == identité authentifiée` à l'application (anti-échange entre écoles) ; horodatage serveur-autoritaire (l'horloge falsifiable corrompt aussi présences/notes) ; N12 toujours autoriser export dossiers élèves même en état restreint (poids légal) ; application ATOMIQUE de la licence.

**Tension centrale (arbitrage gouvernant)** : longueur fenêtre de confiance — COURTE limite fraude/clé-volée/révocation lente mais brique l'offline honnête ; LONGUE respecte le terrain mais allonge l'exposition → réponse = fenêtre ADAPTATIVE (généreuse par défaut/zone, raccourcie pour comptes à risque/paiement provisoire/post-incident). Backstop réel de l'enforcement = dépendance opérationnelle à la synchro, PAS la crypto (appareil hors-ligne+horloge figée = inenforçable, assumé).

📄 **Design consolidé (spec prête à implémenter, découpage en vagues) → `docs/ABONNEMENT_LICENCE_ARCHITECTURE.md`** (reconstruit 2026-07-04 depuis cette mémoire + [[abonnement-technique-powersync]], session d'origine perdue).

Lié à [[modules-acces-hierarchie]] (l'abonnement = verrou le plus haut de la cascade rôle→plan→profil→périmètre), [[role-admin-groupe]] (décideur/payeur = admin_groupe, seul notifié des échéances), [[sync-config-divergence]], [[abonnement-technique-powersync]] (audit technique d'implémentation).
