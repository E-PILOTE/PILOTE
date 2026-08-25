---
name: design-gouvernance-anti-redondance
description: "Principe UI E-PILOTE — pas de redondance de KPI entre écrans ; un écran de détail FAIT le travail de son rôle, ne réaffiche pas des stats vues ailleurs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b797fb41-8337-48f0-932b-03b0f50da9f1
---

**Ne PAS redupliquer les KPI/stats d'un écran à l'autre. Chaque donnée a UN seul foyer : usage/adoption/volumes = Dashboard & Rapports ; gouvernance d'accès = écran du module. Un écran de détail doit FAIRE l'action de son rôle, pas réafficher des chiffres déjà visibles ailleurs. Préférer 1 action utile à 4 cartes décoratives.**

**Why:** l'utilisateur a explicitement rejeté un cockpit par-module (`AdminModuleScreen`, 2026-06-04) parce que « personnel habilité / écoles / volume métier » étaient **déjà** au Dashboard et dans Rapports → « je sens une redondance » + « pourquoi surcharger l'espace de l'admin groupe inutilement ? ». Rappel métier : l'`admin_groupe` **pilote** les modules (il attribue les accès) mais ne les **opère** pas (ça c'est le personnel scolaire). C'est une **plateforme gouvernementale** → clarté, sobriété et intégrité priment sur le « joli mais bavard ». Modèle de référence cité : consoles Microsoft 365 / Google Workspace / Okta — **par-application = gouvernance d'accès + config ; analytics d'usage = centralisés, jamais répétés par app.**

**How to apply:**
- Avant d'ajouter des KPI sur un nouvel écran, vérifier qu'ils n'existent pas déjà ailleurs (Dashboard, Rapports). Si oui → ne pas les remettre ; au mieux un lien.
- Un écran de détail (module, école, profil…) = la/les action(s) propres à son rôle + le strict contexte nécessaire. Pas de tableau de bord miniature.
- Décider l'architecture comme un·e senior : poser le modèle « entitlement (plan) / gouvernance (qui peut) / supervision (usage) » et ranger chaque info dans le bon tiroir.

**Style de collaboration de l'utilisateur (récurrent) :** il **délègue les décisions de design** (« je te prie de choisir », « choisis selon ton expertise, c'est une plateforme du gouvernement ») MAIS attend de la **rigueur justifiée** — pas un choix au hasard. Bonne réponse = **trancher fermement + expliquer le pourquoi par les meilleures pratiques**, pas multiplier les questions. Il valorise l'honnêteté technique (« ton honneur est en jeu ») et la sobriété professionnelle.

Voir [[role-admin-groupe]], [[modules-acces-hierarchie]], [[admin-groupe-espace]].
