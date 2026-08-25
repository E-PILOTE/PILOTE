---
name: metp-dsic-systemes-reels
description: "⚠️ Ce qui EXISTE vraiment au METP — une seule appli réelle (inscriptions examens d'État) ; le reste = vitrines web"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
---

**Établi le 2026-07-17 par l'utilisateur, fonctionnaire à la DSIC** ([[user-fonctionnaire-dsic-metp]]) —
contredit mes recherches web, et c'est LUI qui a raison.

**La seule application réelle du METP = l'inscription aux examens d'État.** C'est tout.

`dsic-metp.net` affiche « Gestion Scolaire » avec 5 modules (Monitoring, Examens, Finances,
Scolarité, RH), un guide d'utilisation complet, un « kit client ». **Ces applications
n'existent que sur le web** — des vitrines. Ne jamais les traiter comme un produit déployé.
Idem pour tout portail ministériel trouvé en ligne (e-MEPPSA, etc.) : à vérifier auprès de
l'utilisateur avant d'en tirer une conclusion stratégique.

**Ce que ça implique pour E-PILOTE :**
- **Aucun concurrent ministériel** sur la vie de l'établissement (scolarité, EDT, notes,
  bulletins, finances, RH, vie scolaire). Le périmètre est vide.
- **Une seule frontière**, avec **un seul système** : l'appli d'inscription aux examens.
  C'est la cible unique et concrète du port `DecGateway` (cf.
  `docs/superpowers/specs/2026-07-17-architecture-transmission-dec.md`).
- La vision « E-PILOTE gère tout » **tient**. « Système amont » ne décrivait que la frontière
  DEC, jamais le périmètre produit — formulation à ne plus employer, elle induit en erreur.

**Faits terrain vérifiés (presse + note officielle METP 2025-2026) :**
- Dépôt **physique** : directions départementales (candidats libres) · établissements
  (candidats officiels). Campagne 8 déc. 2025 → clôture **14 févr. 2026 à 14h00**.
- Pièces : actes de naissance, photos d'identité, diplômes légalisés, **attestations de stage**.
- ⚠️ **La « demande manuscrite » n'est PAS attestée** — absente de la note 2025-2026, le PDF
  qui l'appuyait renvoie 404. J'avais bâti dessus la « fonctionnalité qui gagne la salle ».
  À confirmer auprès de l'utilisateur avant d'y réinvestir quoi que ce soit.

⚠️ Deux documents contiennent des affirmations désormais fausses, à réécrire :
`docs/superpowers/specs/2026-07-17-positionnement-ministeres-25-aout.md` (« aucun incumbent »)
et `...-organisation-modules-metp.md`. Cf. [[examens-nationaux-socle]].
