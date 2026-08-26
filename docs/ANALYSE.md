# 📋 ANALYSE — E-PILOTE CONGO v3.0
## Plateforme Nationale de Gestion Scolaire Intelligente

> Stack retenu : **Flutter** (mobile/desktop) · **PowerSync** (sync offline-first) · **Supabase** (auth + PostgreSQL)

---

## 1. VISION & CONTEXTE

| Élément | Détail |
|---|---|
| **Commanditaires** | MEPSA + METP (République du Congo) |
| **Objectif** | SaaS national de gestion scolaire, public + privé |
| **Périmètre** | 8 catégories · 38 modules · 4 plans d'abonnement |
| **Définition Groupe Scolaire** | Tout opérateur gérant plusieurs écoles : ministère (MEPSA, METP), réseau privé, congrégation religieuse, promoteur individuel. Dès qu'il y a plusieurs écoles à gérer → c'est un Groupe Scolaire (public ou privé). |
| **Phase actuelle** | Phase 1 (70% terminé) → démarrage Phase 2 |
| **Devise** | Franc CFA — XAF |
| **Calendrier** | Année scolaire : Septembre → Juillet · 3 trimestres |

---

## 2. HIÉRARCHIE DES ACTEURS (3 niveaux)

```
SUPER_ADMIN E-PILOTE (Plateforme globale)
│  ✅ Crée les Groupes Scolaires
│  ✅ Crée les Catégories & Modules (38 modules)
│  ✅ Définit les Plans d'abonnement
   ✅ crée les factures quand un groupe scolaire a payé son abonnement,sachant ce n'est qu'après payement que les modules seront disponible dans le dashbord de l'admin groupe
│  ✅ Assigne modules → Plans (plan_modules)
│  ❌ NE gère PAS les profils d'accès utilisateurs
│
└─► ADMIN_GROUPE (Réseau d'écoles - tenant)
    │  Peut être : Ministère (MEPSA/METP) · Réseau privé · Congrégation · Promoteur
    │  ⚠️  Un GROUPE SCOLAIRE = tout opérateur gérant ≥ 1 école (public ou privé)
    │     Ex : MEPSA gère 1 247 écoles publiques → c'est un Groupe Scolaire Institutionnel
    │  ✅ Voit modules selon son PLAN (Institutionnel gratuit pour les groupes publics)
    │  ✅ Dispose des KPIs nationaux/régionaux selon la taille du groupe
    │  ✅ Crée ses Écoles
    │  ✅ Crée ses Utilisateurs
    │  ✅ Crée les PROFILS D'ACCÈS (permissions par module)
    │  ✅ Assigne profils aux utilisateurs
    │
    └─► UTILISATEURS (Personnel d'école)
           • directeur · proviseur · enseignant · cpe
           • comptable · secrétaire · surveillant
           • parent · élève · infirmier · responsable_cantine
           ✅ Accèdent UNIQUEMENT aux modules de leur profil
           ✅ Données isolées à leur école (TenantGuard)
```

---

## 3. FLUX D'AUTHENTIFICATION (Supabase Auth)

```
Connexion email/password → Supabase Auth
        │
        ▼
Récupérer : role + access_profile_id + school_id
        │
   ┌────┴─────────────┐
   │ super_admin /    │─────────► /dashboard (accès global)
   │ admin_groupe     │
   └──────────────────┘
        │
   ┌────┴─────────────┐
   │ Utilisateur école │──► A un profil? ──OUI──► /user (modules du profil)
   └──────────────────┘                  └─NON──► /profile-pending
```

---

## 4. PLANS D'ABONNEMENT

| Plan | XAF/mois | Max Écoles | Max Élèves | Max Staff | Modules |
|---|---|---|---|---|---|
| **Gratuit** | 0 | 1 | 100 | 10 | 9 |
| **Premium** | 150 000 | 5 | 2 000 | 200 | 25 |
| **Pro** | 350 000 | 20 | 10 000 | 1 000 | 37 |
| **Institutionnel** | 900 000 | ∞ | 50 000 | 5 000 | 41 |

> **Groupes publics (MEPSA, METP, académies régionales…)** : Plan Institutionnel **gratuit** (financé par l'État — 5 Mds XAF/an)
> Un groupe public = `group_type = 'public'` + `is_public_plan = TRUE` sur le plan Institutionnel → abonnement activé sans facture de paiement.

---

## 5. LES 38 MODULES PAR CATÉGORIE

### 🎓 SCOLARISATION (8)
`eleves` · `inscriptions` · `classes` · `matieres` · `transferts` · `documents` · `annuaire` · `niveaux`

### 📚 PÉDAGOGIE (10)
`notes` · `presences-eleves` · `bulletins` · `emploi-du-temps` · `cahier-textes` · `evaluations` · `conseils` · `programmes` + 2 autres

### 🏫 VIE SCOLAIRE (4)
`discipline` · `orientation` · `infirmerie` · `cantine`

### 💰 FINANCE (7)
`frais-scolarite` · `paiements-eleves` · `facturation-ecole` · `depenses` · `budget` · `comptabilite` · `mobile-money`

### 👥 RESSOURCES HUMAINES (4)
`personnel` · `presences-personnel` · `conges` · `paie`

### 📢 COMMUNICATION (5)
`annonces` · `notifications` · `messagerie` · `evenements` · `espace-parent`

### 📖 RESSOURCES (1)
`bibliotheque`

### 🤖 INTELLIGENCE ARTIFICIELLE (2)
`rapport-ia` · `suggestions-ia`

---

## 6. NIVEAUX SCOLAIRES & SYSTÈMES DE NOTATION

| Ordre | Code | Niveau | Classes/Diplômes | Notation | Commanditaire |
|---|---|---|---|---|---|
| 0 | GARD | **Maternelle/Garderie** | PS, MS, GS (2-5 ans) | Compétences (Acquis/En cours/Non acquis) | MEPSA |
| 1 | PRIM | **Primaire** | CP→CM2 (6-11 ans) | /20 sans coefficient | MEPSA |
| 2 | COLL | **Collège** | 6e→3e (11-15 ans) | /20 avec coefficient | MEPSA |
| 3 | LYCE | **Lycée** | 2nde→Tle A,C,D,STI (15-18 ans) | /20 avec coefficient + filière | MEPSA |
| 5 | TECH | **Enseignement Technique** | CAP, BEP, Bac Technique | /20 avec coefficient + spécialité | **METP** |
| 6 | PROF | **École Professionnelle** | Certificats professionnels | /20 ou compétences | **METP** |
| 7 | UNIV | **Université/Supérieur** | Licence, Master, Doctorat | Crédits ECTS + /20 | MESRS |

> ✅ Les niveaux TECH et PROF sont **critiques pour le METP** (2ème commanditaire).
> Les niveaux scolaires sont **personnalisables** par l'admin groupe (ajout, renommage, création).
> L'admin groupe peut aussi créer ses propres niveaux personnalisés (ex : formation continue, cours du soir).

---

## 7.  TECHNIQUE (Flutter/PowerSync/Supabase)

| CDC Original | Notre Stack |
|---|---|
| Supabase Edge Functions + RLS |
| Supabase PostgreSQL |
| | **PowerSync** (SQLite local offline-first) |
|  **PowerSync** Sync Service |
| **Supabase Auth** (JWT intégré) |
|  **Flutter Desktop** |
| **Flutter Mobile** |

### PowerSync — Données synchronisées offline
-Il faut bien reflechir car tous les modules et catégories selon les plans d'abonnement doivent etre disponible.
- Notes et absences (enseignant → sync auto)
- Emploi du temps (sync initiale + MAJ)
- Liste des élèves par classe (sync initiale + MAJ)
- Bulletins passés (cache PDF)
- Historique paiements (sync auto)

---

## 7b. CHAMPS ENRICHIS — TABLE SCHOOLS (v3.1)

> Intégrés depuis l'ancienne version du projet :

| Champ | Type | Description |
|---|---|---|
| `school_code` | VARCHAR(50) UNIQUE | Code officiel MEPSA/METP attribué à l'établissement |
| `province` | VARCHAR(100) | Province administrative (Congo : Brazzaville, Pool, Niari…) |
| `founded_year` | SMALLINT | Année de fondation de l'école |
| `motto` | VARCHAR(300) | Devise de l'école |
| `website` | VARCHAR(255) | Site web de l'école |
| `school_type` | ENUM | `public` · `privé` · `mixte` (gestion partagée public/privé) |

## 8. RÈGLES MÉTIER CRITIQUES

1. **TenantGuard** : Chaque utilisateur n'accède qu'aux données de son `school_id` + `group_id`
2. **QuotaGuard** : Vérification des limites du plan avant création d'école/élève
3. **Validation notes** : Directeur valide avant publication → notification push FCM
4. **Bulletins** : Conservés 10 ans · Données financières : 5 ans
5. **Conflits sync** : Last-write-wins (timestamp `updated_at`)
6. **Mode séquentiel** : 6 séquences/an (2 par trimestre) — optionnel
7. **Mentions** : Excellent ≥18 · Très Bien ≥16 · Bien ≥14 · Assez Bien ≥12 · Passable ≥10 · Insuffisant <10
   > ⚠️ **Corrigé le 2026-08-25.** Ce point donnait auparavant un barème décalé
   > de deux points, qui plaçait « Passable » entre 8 et 10 — c'est-à-dire
   > **sous la barre de réussite**, une note d'échec présentée comme une
   > réussite. Le barème ci-dessus est celui du METP, et le seul en vigueur :
   > `epilote/lib/core/utils/mention.dart`, source unique côté application
   > (migration `0059_get_mention_bareme_officiel.sql`). Le code n'a jamais
   > suivi le barème erroné ; c'est ce document qui avait dérivé.
8. **Paiements** : MTN Money + Airtel Money + Espèces (Phase 1) · Intégration API Mobile Money (Phase 2)

---

## 9. SÉCURITÉ (Supabase RLS)

- **Row Level Security (RLS)** sur toutes les tables sensibles
- Politiques basées sur `auth.uid()` + `group_id` + `school_id`
- **Audit logs** : toutes les actions sensibles (CREATE, UPDATE, DELETE)
- **PowerSync** : token offline 30 jours renouvelable automatiquement
- **MFA** optionnel pour super_admin et admin_groupe

---
✅ GESTION DES ANNÉES ACADÉMIQUES — IMPLÉMENTÉE dans le schéma SQL (Bloc 4) :
   • `academic_years`  → Année scolaire 2026-2027 (start_date / end_date / is_current / is_locked)
   • `trimesters`      → 3 trimestres par année avec verrouillage en fin de période
   • `sequences`       → Mode séquentiel optionnel (6 séquences/an, 2 par trimestre)
   Toutes les entités clés (classes, inscriptions, notes, bulletins, paiements…) sont rattachées à academic_year_id.

*Analyse complète — Mai 2026 — E-PILOTE CONGO v3.0*
