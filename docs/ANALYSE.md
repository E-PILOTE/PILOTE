# 📋 ANALYSE — E-PILOTE CONGO v3.0
## Plateforme Nationale de Gestion Scolaire Intelligente

> Stack retenu : **Flutter** (mobile/desktop) · **PowerSync** (sync offline-first) · **Supabase** (auth + PostgreSQL)

---

## 1. VISION & CONTEXTE

| Élément | Détail |
|---|---|
| **Commanditaires** | MEPSA + METP (République du Congo) |
| **Objectif** | SaaS national de gestion scolaire, public + privé |
| **Périmètre** | 8 catégories · **30 modules** · 4 plans d'abonnement (mesuré en base le 2026-08-27 — cf. §5) |
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
| **Gratuit** | 0 | 1 | 100 | 10 | 7 |
| **Premium** | 25 000 | 5 | 2 000 | 200 | 16 |
| **Pro** | 220 000 | 20 | 10 000 | 1 000 | 28 |
| **Institutionnel** | 2 500 000 | ∞ | 50 000 | 5 000 | 30 |

> ⚠️ **Corrigé le 2026-08-27 — tarifs et compteurs relevés dans
> `subscription_plans` (base live).** Ce tableau annonçait auparavant
> 0/150 000/350 000/900 000 XAF et 9/25/37/41 modules : **aucun des huit
> nombres ne correspondait plus au produit.** Le colonne « Modules » est
> vérifiée : `subscription_plans.module_count` est égal, pour les quatre plans,
> au nombre réel de lignes `plan_modules` (écart 0 partout).
>
> La note ci-dessous sur les groupes publics reste vraie dans son mécanisme
> (`group_type = 'public'` + `is_public_plan`) ; **son arithmétique, elle,
> repose sur l'ancien tarif** — l'enveloppe annoncée est à réexaminer avec
> 2 500 000 XAF/mois.

> **Groupes publics (MEPSA, METP, académies régionales…)** : Plan Institutionnel **gratuit** (financé par l'État — 5 Mds XAF/an)
> Un groupe public = `group_type = 'public'` + `is_public_plan = TRUE` sur le plan Institutionnel → abonnement activé sans facture de paiement.

---

## 5. LES 30 MODULES PAR CATÉGORIE

> ⚠️ **Relevé en base le 2026-08-27** (`module_categories` → `modules`).
> La version précédente de cette section décrivait un catalogue qui n'existe
> plus : elle annonçait 38 modules dans des catégories renommées ou disparues
> (PÉDAGOGIE, SCOLARISATION, RESSOURCES, INTELLIGENCE ARTIFICIELLE), et des
> slugs jamais créés (`evaluations`, `facturation-ecole`, `comptabilite`,
> `mobile-money`, `espace-parent`, `rapport-ia`, `suggestions-ia`). C'est ce
> document qui avait dérivé, pas la base.

### 🎓 SCOLARITÉ (6)
`eleves` · `inscriptions` · `transferts` · `documents` · `annuaire` · `orientation`

### 📚 ENSEIGNEMENT (6)
`classes` · `matieres` · `niveaux` · `programmes` · `emploi-du-temps` · `cahier-textes`

### 📝 ÉVALUATION (3)
`notes` · `bulletins` · `conseils`

### 🎓 EXAMENS & CERTIFICATION (1)
`examens`

### 🏫 VIE SCOLAIRE (5)
`presences-eleves` · `discipline` · `infirmerie` · `cantine` · `bibliotheque`

### 💰 FINANCE (4)
`frais-scolarite` · `paiements-eleves` · `depenses` · `budget`

### 👥 RESSOURCES HUMAINES (4)
`personnel` · `presences-personnel` · `conges` · `paie`

### 🔧 FORMATION PROFESSIONNELLE (1)
`stages`

### 📢 Et la communication ?

**Elle n'est pas au catalogue, et c'est délibéré.** Annonces, messagerie,
notifications et événements sont **natifs** : la section COMMUNICATION de la
barre latérale est épinglée hors du verrou 2 (`nav_config.dart`), donc livrée à
tous les plans, y compris Gratuit. Ce n'est **pas** un levier d'abonnement.
(Sauvegarde mineurs conservée : les élèves n'ont pas la messagerie privée.)

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
   > 🟡 **Moitié faite, mesuré le 2026-08-27.** La validation EST appliquée
   > depuis le 2026-08-27 : le bouton « Publier » exige le droit `validate`
   > (que l'enseignant n'a pas), et la base le refuse aussi — RLS `bulletins`,
   > `WITH CHECK` sur `status = 'published'` (migrations `0118`/`0119`).
   > Avant cela, un enseignant publiait lui-même, et rien ne l'en empêchait.
   > **La notification push FCM, elle, n'existe pas** : `firebase_core` et
   > `firebase_messaging` sont commentés dans `pubspec.yaml`, et la colonne
   > `profiles.fcm_token` n'est jamais écrite. Les familles ne sont donc
   > prévenues de rien — elles doivent ouvrir l'application.
4. **Bulletins** : Conservés 10 ans · Données financières : 5 ans
   > 🟢 **Tenu depuis le 2026-08-28 — par le sceau, pas par une purge**
   > (migration `0145`). « Conservés 10 ans » est un PLANCHER : l'obligation
   > est de NE PAS PERDRE, pas d'effacer. Mais interdire toute suppression
   > pendant dix ans serait faux dans l'autre sens — une comptable qui saisit
   > une dépense de travers doit pouvoir la retirer le jour même.
   >
   > D'où la règle de toute comptabilité : **on corrige dans l'exercice ouvert,
   > la clôture scelle.** `academic_years.is_locked` scelle désormais les
   > bulletins, les dépenses et les encaissements de son année ; le plancher
   > est tenu par une propriété plus sûre qu'une purge — rien, nulle part, ne
   > supprime en masse (`epilote/test/retention_test.dart`).
   >
   > ⚠️ `payroll` n'est pas scellée : elle ne porte pas d'`academic_year_id`,
   > et son écran ne lit pas l'année. Un sceau y produirait une suppression qui
   > ne supprime rien, sans message. À traiter quand la paie sera rattachée à
   > l'exercice.
   >
   > ⚠️ **Aucune purge automatique n'existe, et c'est délibéré.** L'écran
   > « Conservation des données » de l'admin groupe proposait quatre réglages
   > (rétention dossiers 60 mois, journaux 24 mois, archivage auto, seuil) que
   > **rien ne lisait** : un administrateur croyait la plateforme tenue par son
   > choix. La section énonce maintenant ce qui est réellement tenu. Effacer
   > les données d'un enfant reste une décision juridique, pas un réglage.
5. **Conflits sync** : Last-write-wins (timestamp `updated_at`)
6. **Mode séquentiel** : 6 séquences/an (2 par trimestre) — optionnel
   > 🟡 **Configurable mais inerte (2026-08-27).** L'admin groupe crée bien les
   > séquences et désigne la séquence courante (`set_current_sequence`), et la
   > colonne `evaluations.sequence_id` existe jusque dans le schéma PowerSync.
   > Mais **aucun écran du personnel n'y rattache quoi que ce soit** : le
   > formulaire d'évaluation n'offre pas la séquence, et `sequence_id` n'est
   > écrit nulle part. Une école qui active le mode séquentiel ne verra donc
   > aucune différence. Rattacher l'évaluation à la séquence à la saisie
   > suffirait — c'est la seule pièce manquante.
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
     ⚠️ la TABLE est implémentée et alimentée par l'admin groupe ; le mode, lui,
     n'a aucun effet sur la saisie des notes — cf. la note du §8.6.
   Toutes les entités clés (classes, inscriptions, notes, bulletins, paiements…) sont rattachées à academic_year_id.

*Analyse complète — Mai 2026 — E-PILOTE CONGO v3.0*
