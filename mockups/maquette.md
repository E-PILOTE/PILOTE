# 🎓 E-PILOTE CONGO — Maquette Fonctionnelle v3.0
> Stack : Flutter · PowerSync · Supabase | Mai 2026

---

## 🎨 DESIGN SYSTEM

### Palette de Couleurs
| Token | Hex | Usage |
|---|---|---|
| `primary` | `#1E3A5F` | Navy — Éléments institutionnels, sidebar |
| `primary-dark` | `#0F2340` | Fond sidebar |
| `secondary` | `#009A44` | Vert Congo — Succès, validation |
| `accent` | `#FBBC04` | Or — Alertes, highlights |
| `danger` | `#DC2626` | Rouge — Erreurs, suppressions |
| `surface` | `#F0F4F8` | Fond général |
| `card` | `#FFFFFF` | Cartes |
| `text-primary` | `#0F172A` | Texte principal |
| `text-muted` | `#64748B` | Texte secondaire |

### Typographie
- **Police** : Inter (Google Fonts)
- **Titre page** : 24px / 700
- **Titre card** : 16px / 600
- **Corps** : 14px / 400
- **Badge/Label** : 12px / 500

### Composants Réutilisables
```
[BTN-PRIMARY]   Fond #1E3A5F · Texte blanc · radius 8px
[BTN-SECONDARY] Fond transparent · Bordure #1E3A5F · Texte #1E3A5F
[BTN-DANGER]    Fond #DC2626 · Texte blanc
[BADGE-SUCCESS] Fond #DCFCE7 · Texte #166534 · "● Actif"
[BADGE-WARNING] Fond #FEF9C3 · Texte #854D0E · "● En attente"
[BADGE-DANGER]  Fond #FEE2E2 · Texte #991B1B · "● Suspendu"
[BADGE-INFO]    Fond #DBEAFE · Texte #1E40AF · "● Premium"
[AVATAR]        Cercle 36px · Initiales · Fond coloré par rôle
[STAT-CARD]     Icône + Chiffre grand + Label + Tendance ↑↓
```

---

## 🗺️ FLUX DE NAVIGATION GLOBAL

```
┌─────────────────────────────────────────────────────────┐
│                  epilote.cg/login                       │
│            [Email] [Mot de passe] [Se connecter]        │
└──────────────────────┬──────────────────────────────────┘
                       │ Supabase Auth
         ┌─────────────┼──────────────────┐
         ▼             ▼                  ▼
  [super_admin]  [admin_groupe]      [user (école)]
         │             │                  │
         ▼             ▼            [A un profil?]
   /super/dash   /groupe/dash       ┌─────┴─────┐
                                   OUI         NON
                                    │           │
                                    ▼           ▼
                               /user/dash  /profile-pending
```

---

## 📱 LAYOUT GÉNÉRAL (Après connexion)

```
-La sidebar avec la possibilité de plier et déplier (icône ☰ en haut)
-En mode plié : icônes seules (48px) | En mode déplié : icône + libellé (268px)
-L'avatar et les raccourcis profil/paramètres sont dans le HEADER en haut à droite

┌──────────────────────────────────────────────────────────────────────────────────┐
│  SIDEBAR (268px · fond #0F2340 · pliable)  │  HEADER (68px fixe · fond blanc)   │
│  ┌────────────────────────────────────┐    │  [☰]  [Titre de la Page Courante]   │
│  │  🎓 E-PILOTE  CONGO          [☰]  │    │          [🔔 Notif.] [Avatar ▾]      │
│  ├────────────────────────────────────┤    │          ↑ Profil · Paramètres ·    │
│  │  📊 Tableau de bord               │    │            Déconnexion               │
│  │  🏫 Groupes Scolaires             │    ├─────────────────────────────────────┤
│  │  🧩 Catégories & Modules          │    │                                     │
│  │  📦 Plans d'abonnement            │    │   CONTENU PRINCIPAL                 │
│  │  📑 Abonnements                   │    │   (scrollable)                      │
│  │  🧾 Factures                      │    │                                     │
│  │  🪪 Reçus de paiement             │    │                                     │
│  ├────────────────────────────────────┤    │                                     │
│  │  💳 Modes de paiement             │    │                                     │
│  ├────────────────────────────────────┤    │                                     │
│  │  📨 Messagerie                    │    │                                     │
│  │     ├ 🎫 Tickets support          │    │                                     │
│  │     ├ ✉️  Messages (indiv./groupe) │    │                                     │
│  │     └ 📣 Annonces générales       │    │                                     │
│  │  🔔 Notifications                 │    │                                     │
│  ├────────────────────────────────────┤    │                                     │
│  │  🤖 Intelligence Artificielle     │    │                                     │
│  ├────────────────────────────────────┤    │                                     │
│  │  📋 Journal d'audit               │    │                                     │
│  │  📈 Rapports & Statistiques       │    │                                     │
│  ├────────────────────────────────────┤    │                                     │
│  │  ⚙️  Paramètres plateforme        │    │                                     │
│  └────────────────────────────────────┘    │                                     │
└──────────────────────────────────────────────────────────────────────────────────┘

Comportements sidebar :
• Plier/Déplier : clic sur ☰ → animation slide 300ms → icônes seules ou icône + texte
• Item actif    : fond #1E3A5F · barre gauche verte #009A44 · texte blanc
• Hover         : fond rgba(255,255,255,0.05)
• Sous-menus    : accordéon (▶/▼) — ex. Messagerie
• Badge rouge   : sur 🔔 Notifications et ✉️ Messagerie si non lus
```

---

## 1️⃣ PAGE DE CONNEXION

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│         Fond : dégradé #0F2340 → #1E3A5F (diagonale)               │
│                                                                     │
│    ╔═══════════════════════════════════════════════════════╗        │
│    ║                                                       ║        │
│    ║   🎓  E-PILOTE CONGO                                  ║        │
│    ║   Plateforme Nationale de Gestion Scolaire            ║        │
│    ║   ─────────────────────────────────────────           ║        │
│    ║                                                       ║        │
│    ║   Adresse email                                       ║        │
│    ║   ┌─────────────────────────────────────────────┐    ║        │
│    ║   │  mbemba.serge@primaire-sp.cg                │    ║        │
│    ║   └─────────────────────────────────────────────┘    ║        │
│    ║                                                       ║        │
│    ║   Mot de passe                                        ║        │
│    ║   ┌─────────────────────────────────────────────┐    ║        │
│    ║   │  ••••••••••••                          [👁] │    ║        │
│    ║   └─────────────────────────────────────────────┘    ║        │
│    ║                                                       ║        │
│    ║   ┌─────────────────────────────────────────────┐    ║        │
│    ║   │          SE CONNECTER →                     │    ║        │
│    ║   └── Fond #1E3A5F · Texte blanc · radius 8px ──┘    ║        │
│    ║                                                       ║        │
│    ║   Mot de passe oublié ?                               ║        │
│    ║                                                       ║        │
│    ║   ─────────────────────────────────────────────       ║        │
│    ║   Comptes de démonstration :                          ║        │
│    ║   [🔑 Super Admin]  [🏫 Admin Groupe]  [👨‍🏫 Directeur] ║        │
│    ║                                                       ║        │
│    ╚═══════════════════════════════════════════════════════╝        │
│                                                                     │
│         République du Congo · MEPSA · METP · v3.0                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Comportements :**
- Erreur credentials → Message rouge sous le champ mot de passe
- Succès → Loader → Redirection selon `role` (voir flux navigation)
- Bouton démo → Pré-remplit email/password + connecte directement

---

## 2️⃣ PAGE D'ATTENTE — PROFILE PENDING

```
┌──────────────────────────────────────────────────────────────┐
│  Sidebar : navigation masquée (sauf Se déconnecter)          │
│                                                              │
│                    ╔══════════════════════╗                  │
│                    ║                      ║                  │
│                    ║   ⏳                  ║                  │
│                    ║                      ║                  │
│                    ║  Compte en attente   ║                  │
│                    ║  de configuration    ║                  │
│                    ║                      ║                  │
│                    ║  Bonjour,            ║                  │
│                    ║  BAYONNE Jacques     ║                  │
│                    ║                      ║                  │
│                    ║  Votre administrateur║                  │
│                    ║  de groupe n'a pas   ║                  │
│                    ║  encore assigné de   ║                  │
│                    ║  profil d'accès à    ║                  │
│                    ║  votre compte.       ║                  │
│                    ║                      ║                  │
│                    ║  Contactez :         ║                  │
│                    ║  rose@saintpierre.cg ║                  │
│                    ║                      ║                  │
│                    ║  [📧 Envoyer un      ║                  │
│                    ║      message]        ║                  │
│                    ║                      ║                  │
│                    ║  [🔄 Actualiser]     ║                  │
│                    ║  [🚪 Déconnexion]    ║                  │
│                    ║                      ║                  │
│                    ╚══════════════════════╝                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 3️⃣ SUPER ADMIN — TABLEAU DE BORD

**URL** : `/super/dashboard` | **Utilisateur** : Jean-Marie NKOUNKOU

> 💡 **Rappel** : Un Groupe Scolaire peut être un Ministère (MEPSA, METP), un réseau privé, une congrégation ou tout promoteur gérant plusieurs écoles. Les KPIs s'adaptent à la taille du groupe (régionaux/nationaux pour les groupes publics institutionnels).

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ SIDEBAR (voir Layout Général)  │  HEADER : [☰] 📊 Tableau de bord   [🔔2] [👤▾]│
│ ─────────────────────────────  ├──────────────────────────────────────────────── │
│ 📊 Dashboard  ◀──actif        │  📊 Tableau de bord Plateforme                  │
│ 🏫 Groupes Scolaires          │  Bonjour Jean-Marie · Lundi 25 mai 2026         │
│ 🧩 Catégories & Modules       │                                                  │
│ 📦 Plans d'abonnement         │  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│ 📑 Abonnements                │  │ 🏫       │ │ 👨‍🎓       │ │ 👤       │        │
│ 🧾 Factures                   │  │  247     │ │  48 320  │ │  3 941   │        │
│ 🪪 Reçus de paiement          │  │ Groupes  │ │  Élèves  │ │Personnel │        │
│ ─────────────────────────────  │  │ actifs   │ │  total   │ │  total   │        │
│ 💳 Modes de paiement          │  │ ↑ +12/mois│ │ ↑ +2.4% │ │ ↑ +8%   │        │
│ ─────────────────────────────  │  └──────────┘ └──────────┘ └──────────┘        │
│ 📨 Messagerie          ▼      │  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│    🎫 Tickets support         │  │ 💰       │ │ 📶       │ │ 🟢       │        │
│    ✉️  Messages               │  │ 36.9M    │ │  99.7%   │ │ 99.5%    │        │
│    📣 Annonces générales      │  │  XAF/mois│ │  Sync    │ │ Dispo.   │        │
│ 🔔 Notifications        [2]   │  │ Revenus  │ │  réussie │ │ SLA      │        │
│ ─────────────────────────────  │  │ ↑ +18%   │ │ ✅ OK    │ │ ✅ OK    │        │
│ 🤖 Intelligence Artificielle  │  └──────────┘ └──────────┘ └──────────┘        │
│ ─────────────────────────────  │                                                  │
│ 📋 Journal d'audit            │  ┌──────────────────────┐ ┌────────────────┐    │
│ 📈 Rapports & Statistiques    │  │ 📊 Groupes par Plan   │ │ 🗺️ Par Dept.   │    │
│ ─────────────────────────────  │  │                      │ │                │    │
│ ⚙️  Paramètres plateforme     │  │ Institutionnel ████  │ │ Brazzaville    │    │
│                                │  │    72 (public+privé) │ │   ████ 124     │    │
│                                │  │ Pro ██████           │ │ Pte-Noire      │    │
│                                │  │    54 groupes        │ │   ██  67       │    │
│                                │  │ Premium ████████     │ │ Pool           │    │
│                                │  │    89 groupes        │ │   █  32        │    │
│                                │  │ Gratuit ███          │ │ Autres         │    │
│                                │  │    32 groupes        │ │   █  24        │    │
│                                │  └──────────────────────┘ └────────────────┘    │
│                                │                                                  │
│                                │  ┌────────────────────────────────────────────┐ │
│                                │  │ 🕐 Activité récente                        │ │
│                                │  │                                            │ │
│                                │  │ 14:23 · Nouveau groupe créé                │ │
│                                │  │        "École Évangélique de Dolisie"      │ │
│                                │  │ 13:47 · Plan Premium → Pro                 │ │
│                                │  │        "Réseau Scolaire Horizon"           │ │
│                                │  │ 12:15 · Reçu validé · Abonnement activé   │ │
│                                │  │        "Groupe Scolaire EDEC" · INST.      │ │
│                                │  │ 11:30 · Nouveau ADMIN_GROUPE créé          │ │
│                                │  │        marien@epilote.cg                   │ │
│                                │  └────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────┘

RÈGLES MÉTIER SIDEBAR SUPER ADMIN :
• "Abonnements" : créés automatiquement à la création d'un groupe (statut 'trial').
  L'abonnement passe à 'active' UNIQUEMENT après validation d'un Reçu de paiement.
  Groupes publics (MEPSA/METP…) : abonnement Institutionnel activé directement (gratuit État).
  L'abonnement est lié au groupe scolaire, pas à son admin.
• "Modes de paiement" : configuration des passerelles MTN Money, Airtel Money, VISA,
  Espèces (CASH disponible dès la Phase 1). Génération automatique des factures.
• "Intelligence Artificielle" : module complet (rapport-ia + suggestions-ia) avec
  ses propres paramètres de configuration (clé API, modèle, seuils).
• "Reçus" : après validation d'un reçu → subscription_status passe à 'active' →
  les modules du plan deviennent disponibles dans le dashboard Admin Groupe.
```
---

## 3.2 SUPER ADMIN — GROUPES SCOLAIRES

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🏫 Groupes Scolaires                    [+ Nouveau Groupe] [📤Export]│
│ 247 groupes au total                                                │
│                                                                     │
│ [🔍 Rechercher un groupe...]  [Plan ▾] [Type ▾] [Département ▾]    │
│                                                                     │
│ ┌────┬─────────────────────────┬───────┬──────┬───────┬──────────┐  │
│ │ # │ Groupe Scolaire         │ Plan  │Écoles│Élèves │ Statut   │  │
│ ├────┼─────────────────────────┼───────┼──────┼───────┼──────────┤  │
│ │ 1  │ 🏫 Réseau Sc. St-Pierre │[PREM] │  3   │ 1 247 │[● Actif] │  │
│ │    │ rose@saintpierre.cg     │       │      │       │[⋮ Actions]│ │
│ ├────┼─────────────────────────┼───────┼──────┼───────┼──────────┤  │
│ │ 2  │ 🏫 Groupe Scolaire EDEC │[INST] │  12  │ 8 430 │[● Actif] │  │
│ │    │ admin@edec.cg           │Public │      │       │[⋮ Actions]│ │
│ ├────┼─────────────────────────┼───────┼──────┼───────┼──────────┤  │
│ │ 3  │ 🏫 École Horizon        │[PRO]  │  7   │ 3 218 │[● Actif] │  │
│ │    │ admin@horizon.cg        │       │      │       │[⋮ Actions]│ │
│ ├────┼─────────────────────────┼───────┼──────┼───────┼──────────┤  │
│ │ 4  │ 🏫 Institut Savorgnan   │[INST] │  5   │ 2 890 │[⏸ Suspendu]│ │
│ │    │ admin@savorgnan.cg      │Public │      │       │[⋮ Actions]│ │
│ └────┴─────────────────────────┴───────┴──────┴───────┴──────────┘  │
│ [← Précédent]  Page 1 sur 25  [Suivant →]                           │
└─────────────────────────────────────────────────────────────────────┘
```

### Modal — Créer un Groupe Scolaire
```
╔══════════════════════════════════════════════════════════╗
║  ➕ Nouveau Groupe Scolaire                        [✕]  ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Nom du groupe *                                         ║
║  ┌────────────────────────────────────────────────┐     ║
║  │ Réseau Scolaire Saint-Michel                   │     ║
║  └────────────────────────────────────────────────┘     ║
║                                                          ║
║  Type d'établissement *    Département *                 ║
║  ┌─────────────────┐       ┌──────────────────────┐     ║
║  │ Privé        ▾  │       │ Brazzaville        ▾ │     ║
║  └─────────────────┘       └──────────────────────┘     ║
║                                                          ║
║  Email Admin Groupe *                                    ║
║  ┌────────────────────────────────────────────────┐     ║
║  │ admin@saint-michel.cg                          │     ║
║  └────────────────────────────────────────────────┘     ║
║                                                          ║
║  Plan d'abonnement *                                     ║
║  ○ Gratuit (0 XAF)   ● Premium (150 000 XAF/mois)       ║
║  ○ Pro (350 000 XAF) ○ Institutionnel (900 000 XAF)     ║
║                                                          ║
║  ⚠️  Un email sera envoyé à l'admin avec ses accès.     ║
║                                                          ║
║  [Annuler]                    [✅ Créer le Groupe]       ║
╚══════════════════════════════════════════════════════════╝
```

---

## 3.3 SUPER ADMIN — PLANS & MODULES

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📦 Plans d'Abonnement & Modules                                     │
│                                                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │
│  │  🆓 GRATUIT  │ │ ⭐ PREMIUM   │ │  💎 PRO      │ │ 🏛️ INSTIT. │ │
│  │              │ │              │ │              │ │            │ │
│  │  0 XAF/mois  │ │150 000/mois  │ │350 000/mois  │ │900 000/mois│ │
│  │              │ │              │ │              │ │            │ │
│  │  1 École     │ │  5 Écoles    │ │  20 Écoles   │ │  Illimité  │ │
│  │  100 élèves  │ │  2 000 élèves│ │ 10 000 élèves│ │ 50 000 él. │ │
│  │  10 staff    │ │  200 staff   │ │  1 000 staff │ │  5 000 st. │ │
│  │  8 modules   │ │  26 modules  │ │  36 modules  │ │  38 modules│ │
│  │              │ │              │ │              │ │            │ │
│  │ [32 groupes] │ │ [89 groupes] │ │ [54 groupes] │ │[72 groupes]│ │
│  │ [✏️ Modifier] │ │ [✏️ Modifier] │ │ [✏️ Modifier] │ │[✏️ Modifier]│ │
│  └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘ │
│                                                                     │
│  ─────────────────────────────────────────────────────────          │
│  🧩 Configuration Modules par Plan                                  │
│                                                                     │
│  Catégorie            │ Module           │Gratuit│Premium│Pro│Inst. │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  🎓 SCOLARISATION     │ eleves           │  ✅   │  ✅   │✅ │  ✅  │
│                       │ inscriptions     │  ✅   │  ✅   │✅ │  ✅  │
│                       │ classes          │  ✅   │  ✅   │✅ │  ✅  │
│                       │ matieres         │  ✅   │  ✅   │✅ │  ✅  │
│                       │ niveaux          │  ✅   │  ✅   │✅ │  ✅  │
│                       │ transferts       │  ❌   │  ✅   │✅ │  ✅  │
│                       │ documents        │  ❌   │  ✅   │✅ │  ✅  │
│                       │ annuaire         │  ❌   │  ❌   │✅ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  📚 PÉDAGOGIE         │ notes            │  ✅   │  ✅   │✅ │  ✅  │
│                       │ presences-eleves │  ✅   │  ✅   │✅ │  ✅  │
│                       │ bulletins        │  ❌   │  ✅   │✅ │  ✅  │
│                       │ emploi-du-temps  │  ❌   │  ✅   │✅ │  ✅  │
│                       │ cahier-textes    │  ❌   │  ✅   │✅ │  ✅  │
│                       │ evaluations      │  ❌   │  ✅   │✅ │  ✅  │
│                       │ conseils         │  ❌   │  ❌   │✅ │  ✅  │
│                       │ programmes       │  ❌   │  ❌   │✅ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  🏫 VIE SCOLAIRE      │ discipline       │  ❌   │  ✅   │✅ │  ✅  │
│                       │ orientation      │  ❌   │  ❌   │✅ │  ✅  │
│                       │ infirmerie       │  ❌   │  ❌   │❌ │  ✅  │
│                       │ cantine          │  ❌   │  ❌   │❌ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  💰 FINANCE           │ frais-scolarite  │  ❌   │  ✅   │✅ │  ✅  │
│                       │ paiements-eleves │  ❌   │  ✅   │✅ │  ✅  │
│                       │ facturation-ecole│  ❌   │  ✅   │✅ │  ✅  │
│                       │ mobile-money     │  ❌   │  ✅   │✅ │  ✅  │
│                       │ depenses         │  ❌   │  ❌   │✅ │  ✅  │
│                       │ budget           │  ❌   │  ❌   │✅ │  ✅  │
│                       │ comptabilite     │  ❌   │  ❌   │✅ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  👥 RH                │ personnel        │  ❌   │  ❌   │✅ │  ✅  │
│                       │ presences-perso. │  ❌   │  ❌   │✅ │  ✅  │
│                       │ conges           │  ❌   │  ❌   │✅ │  ✅  │
│                       │ paie             │  ❌   │  ❌   │✅ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  📢 COMMUNICATION     │ annonces         │  ✅   │  ✅   │✅ │  ✅  │
│                       │ notifications    │  ✅   │  ✅   │✅ │  ✅  │
│                       │ messagerie       │  ❌   │  ✅   │✅ │  ✅  │
│                       │ evenements       │  ❌   │  ✅   │✅ │  ✅  │
│                       │ espace-parent    │  ❌   │  ✅   │✅ │  ✅  │
│  ─────────────────────┼──────────────────┼───────┼───────┼───┼───── │
│  📖 RESSOURCES        │ bibliotheque     │  ❌   │  ❌   │✅ │  ✅  │
│  🤖 IA                │ rapport-ia       │  ❌   │  ❌   │❌ │  ✅  │
│                       │ suggestions-ia   │  ❌   │  ❌   │❌ │  ✅  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4️⃣ ADMIN GROUPE — TABLEAU DE BORD

**URL** : `/groupe/dashboard` | **Utilisateur** : Rose NKOUNKOU | **Plan** : Premium

```
┌─────────────────────────────────────────────────────────────────────┐
│ SIDEBAR ADMIN GROUPE   │  📊 Tableau de bord — Réseau St-Pierre     │
│ ───────────────────    │  Lundi 25 mai 2026 · 1er Trimestre 2026-27 │
│ 📊 Dashboard  ◀─actif  │                                             │
│ 🏫 Mes Écoles          │  [● PREMIUM · 3/5 écoles · 1247/2000 él.]  │
│ 👤 Utilisateurs        │                                             │
│ 🔐 Profils d'accès     │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│ 📊 Rapports            │  │ 🏫       │ │ 👨‍🎓       │ │ 👤       │   │
│ 💳 Abonnement          │  │    3     │ │  1 247   │ │   89     │   │
│ ⚙️  Paramètres         │  │  Écoles  │ │  Élèves  │ │Personnel │   │
│                        │  │  actives │ │  inscrits│ │  actif   │   │
│ [Avatar RN]            │  └──────────┘ └──────────┘ └──────────┘   │
│ Rose NKOUNKOU          │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│ ADMIN GROUPE           │  │ 💰       │ │ 📋       │ │ ⚠️        │   │
│ [🔴 Déconnexion]       │  │ 8.74M    │ │   94%    │ │    23    │   │
│                        │  │  XAF     │ │  Paiemts │ │ Impayés  │   │
│                        │  │  collectés│ │  à jour  │ │  ce mois │   │
│                        │  └──────────┘ └──────────┘ └──────────┘   │
│                        │                                             │
│                        │  ┌─────────────────────────────────────┐   │
│                        │  │ 🏫 Mes Écoles                        │   │
│                        │  │                                      │   │
│                        │  │ École Primaire St-Pierre (Bacongo)   │   │
│                        │  │ 487 élèves · 24 enseignants · Primaire│  │
│                        │  │ [████████████████░░░] 487/800 élèves │   │
│                        │  │                                      │   │
│                        │  │ Collège St-Pierre (Poto-Poto)        │   │
│                        │  │ 523 élèves · 31 enseignants · Collège│   │
│                        │  │ [████████████████████░] 523/800      │   │
│                        │  │                                      │   │
│                        │  │ Lycée Technique Savorgnan            │   │
│                        │  │ 237 élèves · 18 enseignants · Lycée  │   │
│                        │  │ [████████░░░░░░░░░░░░] 237/800       │   │
│                        │  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
NB : Les catégories et modules apparaissent dans la sidebar dynamiquement selon le plan d'abonnement(
SIDEBAR ADMIN GROUPE:
- Dashboard
- Mes Écoles
- Utilisateurs
- Profils d'accès : configurable par l'admin groupe et flexible et dynamique
- Rapports
- Abonnement : Tous les types d'abonnements disponible de la plate-forme et son plan selectionner déjà etc... et a la possibilité de lancer une demande de changement de plan d'abonnement avec des modals ,actions requises.
- [
    Catégorie A{
                Modules(modules de cette catégorie A)
            }
    Catégorie B{
                Modules(modules de cette catégorie B)
            }
    Etc...
  ]
- Journal et audits
- Paramettres
```
----------------------------------------------------------------
Les avatars doivent etre dans le header en haut à droite(profil,parametre du compte etc...)
----------------------------------------------------------------
---

## 4.2 ADMIN GROUPE — GESTION DES ÉCOLES

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🏫 Mes Écoles (3/5 écoles · Plan Premium)    [+ Ajouter une École]  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 🏫 École Primaire Saint-Pierre de Bacongo           [● Actif] │  │
│  │ Bacongo, Brazzaville · Niveaux : Maternelle + Primaire         │  │
│  │ 📧 primaire@saintpierre.cg · 📞 +242 06 234 56 78            │  │
│  │ Directeur : M. MBEMBA Serge                                   │  │
│  │                                                               │  │
│  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │  │
│  │ │ 487      │ │ 28       │ │ 14       │ │ 94%              │  │  │
│  │ │ Élèves   │ │ Classes  │ │Personnel │ │ Paiements OK     │  │  │
│  │ └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │  │
│  │                                                               │  │
│  │ [👁️ Voir détails] [✏️ Modifier] [📊 Rapport] [⋮ Plus]         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 🏫 Collège Saint-Pierre de Poto-Poto                [● Actif] │  │
│  │ Poto-Poto, Brazzaville · Niveaux : Collège                    │  │
│  │ 📧 college@saintpierre.cg · 📞 +242 06 123 45 67             │  │
│  │ Directeur : M. MOUNGALI Hervé                                 │  │
│  │                                                               │  │
│  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │  │
│  │ │ 523      │ │ 16       │ │ 31       │ │ 89%              │  │  │
│  │ │ Élèves   │ │ Classes  │ │Personnel │ │ Paiements OK     │  │  │
│  │ └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │  │
│  │                                                               │  │
│  │ [👁️ Voir détails] [✏️ Modifier] [📊 Rapport] [⋮ Plus]         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ + Ajouter la 4ème école     (2 créations restantes / plan)    │  │
│  │ [+ Créer une nouvelle école]                                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4.3 ADMIN GROUPE — GESTION DES UTILISATEURS

```
┌─────────────────────────────────────────────────────────────────────┐
│ 👥 Utilisateurs (89 au total)            [+ Nouvel Utilisateur]     │
│                                                                     │
│ [🔍 Rechercher...]  [École ▾] [Rôle ▾] [Profil ▾] [Statut ▾]      │
│                                                                     │
│ Tabs: [Tous (89)] [Directeurs (3)] [Enseignants (52)] [Comptables (3)]│
│       [Secrétaires (6)] [CPE (4)] [Surveillants (9)] [Autres (12)]  │
│                                                                     │
│ ┌────┬────────────────────┬───────────┬──────────────────┬────────┐ │
│ │    │ Utilisateur        │ Rôle      │ École · Profil   │ Statut │ │
│ ├────┼────────────────────┼───────────┼──────────────────┼────────┤ │
│ │[MS]│ MBEMBA Serge       │ directeur │ Primaire St-Pierre│[● OK] │ │
│ │    │ mbemba@primaire.cg │           │ Prof. Directeur  │[✏️][🗑️]│ │
│ ├────┼────────────────────┼───────────┼──────────────────┼────────┤ │
│ │[JB]│ BAYONNE Jacques    │ enseignant│ Primaire St-Pierre│[● OK] │ │
│ │    │ bayonne@primaire.cg│           │ Prof. Enseignant │[✏️][🗑️]│ │
│ ├────┼────────────────────┼───────────┼──────────────────┼────────┤ │
│ │[NC]│ NTOMBO Cécile      │ secretaire│ Primaire St-Pierre│[● OK] │ │
│ │    │ ntombo@primaire.cg │           │ Prof. Secrétaire │[✏️][🗑️]│ │
│ ├────┼────────────────────┼───────────┼──────────────────┼────────┤ │
│ │[LG]│ LEKOUNDOU Gaston   │ comptable │ Primaire St-Pierre│[● OK] │ │
│ │    │ lekoundou@prim.cg  │           │ Prof. Comptable  │[✏️][🗑️]│ │
│ ├────┼────────────────────┼───────────┼──────────────────┼────────┤ │
│ │[AK]│ KOMBO Angèle       │ enseignant│ Primaire St-Pierre│[⏳ En │ │
│ │    │ kombo@primaire.cg  │           │ ⚠️ Sans profil   │attente]│ │
│ │    │                    │           │                  │[✏️][🗑️]│ │
│ └────┴────────────────────┴───────────┴──────────────────┴────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Modal — Créer/Modifier un Utilisateur
```
╔══════════════════════════════════════════════════════════════╗
║  ➕ Nouvel Utilisateur                                  [✕]  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Prénom *              Nom *                                 ║
║  ┌──────────────────┐  ┌──────────────────────────────────┐  ║
║  │ Jacques          │  │ BAYONNE                          │  ║
║  └──────────────────┘  └──────────────────────────────────┘  ║
║                                                              ║
║  Email *                                                     ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ bayonne.jacques@primaire-saintpierre.cg              │   ║
║  └──────────────────────────────────────────────────────┘   ║
║                                                              ║
║  Téléphone                                                   ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ +242 06 789 01 23                                    │   ║
║  └──────────────────────────────────────────────────────┘   ║
║                                                              ║
║  École *                         Rôle métier *               ║
║  ┌──────────────────────────┐    ┌─────────────────────────┐ ║
║  │ École Primaire St-Pierre ▾│   │ enseignant            ▾ │ ║
║  └──────────────────────────┘    └─────────────────────────┘ ║
║                                                              ║
║  Profil d'accès *                                            ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ Profil Enseignant (notes, presences, cahier-textes) ▾│   ║
║  └──────────────────────────────────────────────────────┘   ║
║                                                              ║
║  ℹ️  Un email avec les accès sera envoyé automatiquement     ║
║                                                              ║
║  [Annuler]                        [✅ Créer l'utilisateur]   ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 4.4 ADMIN GROUPE — PROFILS D'ACCÈS

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🔐 Profils d'Accès (12 profils)              [+ Nouveau Profil]     │
│ Configurez les permissions par module pour chaque rôle             │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ 📋 Profil Directeur               [7 utilisateurs] [✏️] [🗑️]  │ │
│  │ Modules : notes(R+W) · bulletins(R+W+Export) · presences(R+W) │ │
│  │           frais-scolarite(R+W) · paiements(R+W+Export)        │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ 📋 Profil Enseignant              [52 utilisateurs] [✏️] [🗑️] │ │
│  │ Modules : notes(R+W) · presences-eleves(R+W)                  │ │
│  │           cahier-textes(R+W) · evaluations(R+W)               │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ 📋 Profil Comptable               [3 utilisateurs] [✏️] [🗑️]  │ │
│  │ Modules : frais-scolarite(R+W) · paiements-eleves(R+W+Export) │ │
│  │           facturation-ecole(R+W) · depenses(R+W) · budget(R)  │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ 📋 Profil Secrétaire              [6 utilisateurs] [✏️] [🗑️]  │ │
│  │ Modules : eleves(R+W) · inscriptions(R+W+Export)              │ │
│  │           classes(R) · transferts(R+W) · annonces(R+W)        │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Modal — Configurer un Profil d'Accès
```
╔══════════════════════════════════════════════════════════════════╗
║  🔐 Configurer : Profil Enseignant                        [✕]   ║
╠══════════════════════════════════════════════════════════════════╣
║  Modules disponibles selon Plan PREMIUM                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  SCOLARISATION                                                   ║
║  ─────────────────────────────────────────────────────────────   ║
║  Module          Lecture   Écriture  Suppression  Export         ║
║  eleves          [✅]       [ ]        [ ]          [ ]          ║
║  inscriptions    [✅]       [ ]        [ ]          [ ]          ║
║  classes         [✅]       [ ]        [ ]          [ ]          ║
║  matieres        [✅]       [✅]       [ ]          [ ]          ║
║                                                                  ║
║  PÉDAGOGIE                                                       ║
║  ─────────────────────────────────────────────────────────────   ║
║  notes           [✅]       [✅]       [ ]          [✅]         ║
║  presences-eleves[✅]       [✅]       [ ]          [ ]          ║
║  bulletins       [✅]       [ ]        [ ]          [✅]         ║
║  emploi-du-temps [✅]       [ ]        [ ]          [ ]          ║
║  cahier-textes   [✅]       [✅]       [ ]          [ ]          ║
║  evaluations     [✅]       [✅]       [ ]          [ ]          ║
║                                                                  ║
║  COMMUNICATION                                                   ║
║  annonces        [✅]       [✅]       [ ]          [ ]          ║
║  messagerie      [✅]       [✅]       [ ]          [ ]          ║
║                                                                  ║
║  Portée des données :  ○ École entière  ● Ses classes seulement  ║
║                                                                  ║
║  [Annuler]                         [💾 Sauvegarder le profil]   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 5️⃣ DIRECTEUR — TABLEAU DE BORD

**URL** : `/user/dashboard` | **École** : Primaire Saint-Pierre

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
POUR LES UTILISATEURS DES ÉCOLES : PROVISEUR POUR LES LYCÉES,DIRECTEUR POUR COLLEGE,SECRETAIRE,COMPTABLE ETC... :  LA SIDEBAR EST DYNAMIQUE ET RECOIT TOUT SELON LA CONFIG DE L'ADMIN GROUPE
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
C'EST L'ADMIN GROUPE QUI DECIDE QUEL MODULES ET CATÉGORIES ATTRIBUÉS PEU IMPORTE LE PROFIL D'ACCÈS C'EST AINSI QUE LES KPI APPARAISSENT AUSSI SELON LES RESPONSABILITÉS ATTRIBUÉES
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
PROPOSITION : CHAQUE MODULES DOIT AVOIR CES KPI DEJÀ PRÉ-CONCU POUR TOUT FACILITÉS. CECI S'APPLIQUE À TOUT LES UTILISATEURS DES ÉCOLES.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

```
┌─────────────────────────────────────────────────────────────────────┐
│ SIDEBAR DIRECTEUR      │  📊 Mon École — École Primaire St-Pierre   │
│ ──────────────────     │  25 mai 2026 · Trimestre 1 · 2026-2027     │
│ 📊 Dashboard ◀─actif  │                                             │
│ 👨‍🎓 Élèves              │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│ 🏛️  Classes             │  │ 👨‍🎓       │ │ 🏛️        │ │ 👤       │   │
│ 📋 Notes & Bulletins   │  │  487     │ │   28     │ │   42     │   │
│ 📅 Emploi du Temps     │  │  Élèves  │ │  Classes │ │Personnel │   │
│ 💰 Finance             │  └──────────┘ └──────────┘ └──────────┘   │
│ 📢 Annonces            │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│ 📊 Rapports            │  │ 💰       │ │ 🎓       │ │ ⚠️        │   │
│ ⚙️  Paramètres         │  │  94%     │ │  13.2/20 │ │   12     │   │
│                        │  │Paiements │ │ Moy.     │ │ Absences │   │
│ [Avatar MS]            │  │  à jour  │ │ générale │ │ ce mois  │   │
│ MBEMBA Serge           │  └──────────┘ └──────────┘ └──────────┘   │
│ DIRECTEUR              │                                             │
│ Primaire St-Pierre     │  ┌──────────────────────────────────────┐  │
│ [🔴 Déconnexion]       │  │ 📋 Alertes & Actions Requises         │  │
│                        │  │                                      │  │
│                        │  │ ⚠️  14 bulletins T1 non validés       │  │
│                        │  │    [Valider maintenant →]            │  │
│                        │  │                                      │  │
│                        │  │ ⚠️  MOUKOUKOU J-B : 8 absences/mois  │  │
│                        │  │    [Voir dossier →]                  │  │
│                        │  │                                      │  │
│                        │  │ ⚠️  23 paiements en retard           │  │
│                        │  │    [Voir liste →]                   │  │
│                        │  │                                      │  │
│                        │  │ ✅  Notes T1 saisies à 87%           │  │
│                        │  └──────────────────────────────────────┘  │
│                        │                                             │
│                        │  ┌──────────────────────────────────────┐  │
│                        │  │ 📊 Classement Classes (Moy. générale) │  │
│                        │  │                                      │  │
│                        │  │ 1. CE2-A  ████████████ 14.8/20      │  │
│                        │  │ 2. CM1-A  ███████████░ 14.1/20      │  │
│                        │  │ 3. CE1-A  ██████████░░ 13.7/20      │  │
│                        │  │ 4. CM2-A  █████████░░░ 13.2/20      │  │
│                        │  │ 5. CE2-B  ████████░░░░ 12.9/20      │  │
│                        │  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5.2 DIRECTEUR — GESTION DES ÉLÈVES

```
┌─────────────────────────────────────────────────────────────────────┐
│ 👨‍🎓 Élèves (487)    [+ Inscrire un Élève] [📤 Exporter] [📥 Importer]│
│                                                                     │
│ [🔍 Nom, matricule...]  [Classe ▾] [Niveau ▾] [Statut ▾]           │
│                                                                     │
│ ┌────┬──────────────────────┬──────────┬────────┬─────┬──────────┐  │
│ │    │ Élève                │ Matricule│ Classe │ Moy │ Statut   │  │
│ ├────┼──────────────────────┼──────────┼────────┼─────┼──────────┤  │
│ │[JM]│ MOUKOUKOU Jean-Bapt. │2026-001  │ CE1-A  │13.7 │[● Actif] │  │
│ │    │ Né 15/03/2018 · M    │          │        │     │[👁️][✏️]   │  │
│ ├────┼──────────────────────┼──────────┼────────┼─────┼──────────┤  │
│ │[BC]│ BOUANGA Christelle   │2026-002  │ CM2-A  │15.2 │[● Actif] │  │
│ │    │ Née 03/05/2013 · F   │          │        │     │[👁️][✏️]   │  │
│ ├────┼──────────────────────┼──────────┼────────┼─────┼──────────┤  │
│ │[AT]│ TSIENO Angélique     │2026-003  │ CE2-B  │11.4 │[● Actif] │  │
│ │    │ Née 30/01/2017 · F   │          │        │     │[👁️][✏️]   │  │
│ ├────┼──────────────────────┼──────────┼────────┼─────┼──────────┤  │
│ │[KP]│ KIBANGOU Paul        │2026-004  │ CP-A   │ —   │[⏸ Transf.]│ │
│ │    │ Né 22/08/2019 · M    │          │        │     │[👁️][✏️]   │  │
│ └────┴──────────────────────┴──────────┴────────┴─────┴──────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Dossier Élève (vue détail)
```
┌─────────────────────────────────────────────────────────────────────┐
│ ← Retour  |  👨‍🎓 MOUKOUKOU Jean-Baptiste  |  Matricule 2026-001     │
│                                                                     │
│ Tabs: [📋 Infos] [📚 Scolarité] [📊 Notes] [💰 Paiements] [📄 Docs]│
│                                                                     │
│ TAB INFOS ───────────────────────────────────────────────────────   │
│ ┌────────────────────────────────────────────────────────────────┐  │
│ │  [📷 PHOTO]    Nom : MOUKOUKOU Jean-Baptiste                   │  │
│ │  Initiales JB  DDN : 15/03/2018 (8 ans)  Sexe : M             │  │
│ │                Nationalité : Congolaise                        │  │
│ │                Adresse : Rue Mvoumvou, Bacongo, Brazzaville    │  │
│ │                Groupe sanguin : O+  Allergies : Aucune         │  │
│ │                                                                │  │
│ │  TUTEURS                                                       │  │
│ │  ┌───────────────────────────┬────────────────────────────┐   │  │
│ │  │ 👨 MOUKOUKOU Pierre (Père) │ 👩 MOUKOUKOU Agnès (Mère) │   │  │
│ │  │ +242 06 111 22 33         │ +242 05 444 55 66          │   │  │
│ │  │ Comptable · Contact prim. │ Infirmière                 │   │  │
│ │  └───────────────────────────┴────────────────────────────┘   │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ TAB SCOLARITÉ ────────────────────────────────────────────────────  │
│ ┌────────────────────────────────────────────────────────────────┐  │
│ │  Année scolaire : 2026-2027  Classe : CE1-A  Statut : Actif   │  │
│ │  Date inscription : 16/09/2026  Réinscription : Non           │  │
│ │  École précédente : —                                          │  │
│ │                                                                │  │
│ │  Historique :                                                  │  │
│ │  • 2025-2026 : CP-A · Admis · Moy. 14.2/20                   │  │
│ └────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6️⃣ ENSEIGNANT — SAISIE DES NOTES

**URL** : `/user/notes` | **Utilisateur** : BAYONNE Jacques | **Rôle** : Enseignant

```
┌─────────────────────────────────────────────────────────────────────┐
│ SIDEBAR ENSEIGNANT     │  📝 Saisie des Notes                        │
│ ─────────────────      │  1er Trimestre 2026-2027                   │
│ 📊 Dashboard           │                                             │
│ 📝 Mes Notes  ◀─actif  │  Classe : [CE1-A ▾]  Matière : [Mathém. ▾] │
│ 📅 Présences           │  Évaluation : [Composition T1 - 15/12 ▾]   │
│ 📓 Cahier de textes    │                                             │
│ 📋 Mes Classes         │  ┌─────────────────────────────────────┐   │
│ 📢 Annonces            │  │ 📊 Composition T1 Mathématiques     │   │
│ ✉️  Messagerie          │  │ CE1-A · 15 décembre 2026 · /20     │   │
│                        │  │ Note max : 20 · Coeff : 4           │   │
│ [Avatar JB]            │  │ 38 élèves · 36 notes saisies        │   │
│ BAYONNE Jacques        │  └─────────────────────────────────────┘   │
│ Enseignant             │                                             │
│ Primaire St-Pierre     │  ┌──┬────────────────────┬──────┬────────┐  │
│ [🔴 Déconnexion]       │  │N°│ Élève              │ Note │ Apprec.│  │
│                        │  ├──┼────────────────────┼──────┼────────┤  │
│                        │  │1 │ BOUANGA Christelle │16.0  │ Très B │  │
│                        │  │2 │ MOUKOUKOU Jean-B.  │13.5  │ Bien   │  │
│                        │  │3 │ TSIENO Angélique   │ 9.5  │Passable│  │
│                        │  │4 │ MILANDOU Serge     │11.0  │ AB     │  │
│                        │  │5 │ KIMBOUELA Rose     │18.0  │ Excel. │  │
│                        │  │6 │ NGOUABI Patrick    │[ABS] │ —      │  │
│                        │  │7 │ LOUBAKI Marie      │14.5  │ TB     │  │
│                        │  │8 │ MOUNGALI David     │ 7.5  │Insuffi.│  │
│                        │  │  │ ← Bas: rouge <8    │      │        │  │
│                        │  ├──┴────────────────────┴──────┴────────┤  │
│                        │  │ Moy. classe : 12.8/20 · Meilleure: 18 │  │
│                        │  │ [💾 Enregistrer brouillon]             │  │
│                        │  │ [📤 Soumettre au Directeur]            │  │
│                        │  └────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

**Règles métier :**
- Note < 8 → Cellule fond rouge clair
- Note ≥ 16 → Cellule fond vert clair
- `[ABS]` = Absent non noté
- Statut `brouillon` → visible enseignant seulement
- Statut `soumis` → directeur reçoit notification pour validation
- Sync offline : notes saisies hors ligne → sync automatique

---

## 6.2 ENSEIGNANT — GESTION DES PRÉSENCES

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 Présences Élèves · CE1-A                                        │
│ Lundi 25 mai 2026 · Cours Mathématiques (08h00 - 10h00)            │
│                                                                     │
│  [← Jour préc.]  25/05/2026 · Lundi  [Jour suiv. →]               │
│                                                                     │
│  [✅ Tout Présent] [❌ Marquer Absent] [Rafraîchir]                  │
│                                                                     │
│  ┌──┬────────────────────┬────────────┬──────────┬───────────────┐  │
│  │N°│ Élève              │ Matin (AM) │ Aprem(PM)│ Remarque      │  │
│  ├──┼────────────────────┼────────────┼──────────┼───────────────┤  │
│  │1 │ BOUANGA Christelle │ [● Présent]│[● Présent│               │  │
│  │2 │ MOUKOUKOU Jean-B.  │ [● Présent]│[⏰ Retard│ Arrivé 8h22   │  │
│  │3 │ TSIENO Angélique   │ [❌ Absent] │[❌ Absent │ Maladie (cert)│  │
│  │4 │ MILANDOU Serge     │ [● Présent]│[● Présent│               │  │
│  │5 │ KIMBOUELA Rose     │ [❌ Absent] │[● Présent│ Non justifié  │  │
│  │6 │ NGOUABI Patrick    │ [● Présent]│[● Présent│               │  │
│  └──┴────────────────────┴────────────┴──────────┴───────────────┘  │
│                                                                     │
│  Résumé : 34 Présents · 2 Absents · 1 Retard (/ 38 élèves)        │
│                                                                     │
│  [💾 Enregistrer les présences]  [📨 Notifier parents (2 absences)] │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7️⃣ COMPTABLE — PAIEMENTS SCOLARITÉ

```
┌─────────────────────────────────────────────────────────────────────┐
│ SIDEBAR COMPTABLE      │  💰 Paiements Scolarité                     │
│ ─────────────────      │  École Primaire Saint-Pierre · Mai 2026     │
│ 📊 Dashboard           │                                             │
│ 💰 Paiements  ◀─actif  │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│ 📋 Frais Scolaire      │  │ ✅       │ │ ⏰       │ │ ❌       │   │
│ 📄 Facturation         │  │  458     │ │   29     │ │   —      │   │
│ 📊 Budget              │  │ À jour   │ │ En retard│ │  Suspend.│   │
│ 📉 Dépenses            │  │ (94.1%)  │ │ (5.9%)   │ │          │   │
│ 📈 Comptabilité        │  └──────────┘ └──────────┘ └──────────┘   │
│ 💳 Mobile Money        │                                             │
│                        │  ┌──────────────────────────────────────┐  │
│ [Avatar LG]            │  │ 💵 Recettes du mois · Mai 2026       │  │
│ LEKOUNDOU Gaston       │  │                                      │  │
│ Comptable              │  │ Mensualités     : 4 386 000 XAF      │  │
│ Primaire St-Pierre     │  │ Inscriptions    :   125 000 XAF      │  │
│ [🔴 Déconnexion]       │  │ Autres          :    45 000 XAF      │  │
│                        │  │ ─────────────────────────────        │  │
│                        │  │ TOTAL COLLECTÉ  : 4 556 000 XAF      │  │
│                        │  │ ATTENDU         : 4 870 000 XAF      │  │
│                        │  │ ÉCART           :   314 000 XAF ⚠️   │  │
│                        │  └──────────────────────────────────────┘  │
│                        │                                             │
│                        │  [🔍 Rechercher élève...]  [Classe ▾] [Statut ▾] │
│                        │  [+ Enregistrer Paiement] [📤 Exporter PDF] │
│                        │                                             │
│                        │  ┌───┬────────────────┬──────┬──────┬────┐ │
│                        │  │   │ Élève          │Montant│ Mode│Stat│ │
│                        │  ├───┼────────────────┼───────┼─────┼────┤ │
│                        │  │JB │MOUKOUKOU J-B.  │12 000 │MTN  │ ✅ │ │
│                        │  │   │CE1-A · Mai 2026│  XAF  │Money│    │ │
│                        │  │   │Réf:MTN-2026-0847│      │     │[🧾]│ │
│                        │  ├───┼────────────────┼───────┼─────┼────┤ │
│                        │  │BC │BOUANGA Christ. │12 000 │Esp. │ ✅ │ │
│                        │  │   │CM2-A · Mai 2026│  XAF  │     │[🧾]│ │
│                        │  ├───┼────────────────┼───────┼─────┼────┤ │
│                        │  │AT │TSIENO Angélique│   —   │  —  │⏰  │ │
│                        │  │   │CE2-B · RETARD  │12 000 │     │[📧]│ │
│                        │  │   │(J+23 ce mois)  │ dû    │     │    │ │
│                        │  └───┴────────────────┴───────┴─────┴────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Modal — Enregistrer un Paiement
```
╔═══════════════════════════════════════════════════════════╗
║  💰 Enregistrer un Paiement                         [✕]  ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  Élève *                                                  ║
║  ┌───────────────────────────────────────────────────┐   ║
║  │ 🔍 TSIENO Angélique · CE2-B · Matricule 2026-003 │   ║
║  └───────────────────────────────────────────────────┘   ║
║                                                           ║
║  Type de paiement *       Période *                       ║
║  ┌──────────────────┐     ┌────────────────────────────┐  ║
║  │ Mensualité     ▾ │     │ Mai 2026                 ▾ │  ║
║  └──────────────────┘     └────────────────────────────┘  ║
║                                                           ║
║  Montant *                Mode de paiement *              ║
║  ┌──────────────────┐     ┌────────────────────────────┐  ║
║  │ 12 000  XAF      │     │ MTN Money                ▾ │  ║
║  └──────────────────┘     │ ○ MTN Money                │  ║
║                           │ ○ Airtel Money             │  ║
║                           │ ○ VISA                     │  ║
║                           │ ● Espèces (Cash)           │  ║
║                           └────────────────────────────┘  ║
║                                                           ║
║  Référence transaction (Mobile Money)                     ║
║  ┌───────────────────────────────────────────────────┐   ║
║  │ MTN-2026-05-25-XXXX                               │   ║
║  └───────────────────────────────────────────────────┘   ║
║                                                           ║
║  Date de paiement *                                       ║
║  ┌───────────────────────────────────────────────────┐   ║
║  │ 25/05/2026                                        │   ║
║  └───────────────────────────────────────────────────┘   ║
║                                                           ║
║  ℹ️  Un reçu électronique sera généré automatiquement    ║
║     et envoyé aux parents via notification push          ║
║                                                           ║
║  [Annuler]                  [✅ Valider le Paiement]     ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 8️⃣ CPE — GESTION DES PRÉSENCES & DISCIPLINE

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 Présences Globales · École Primaire St-Pierre                    │
│ Semaine du 22 au 26 mai 2026                                        │
│                                                                     │
│  Tabs: [📅 Présences Jour] [📊 Stats Semaine] [⚠️ Incidents] [📋Rapport]│
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Lundi 25 mai · Vue par classe                                │   │
│  │                                                              │   │
│  │ Classe  │ Effectif │ Présents │ Absents │ Retards │ Taux     │   │
│  │ ─────── │ ──────── │ ──────── │ ─────── │ ─────── │ ─────── │   │
│  │ CP-A    │   35     │   33     │    1    │    1    │  94.3%  │   │
│  │ CE1-A   │   38     │   36     │    2    │    0    │  94.7%  │   │
│  │ CE1-B   │   37     │   35     │    1    │    1    │  94.6%  │   │
│  │ CE2-A   │   40     │   39     │    1    │    0    │  97.5%  │   │
│  │ CE2-B   │   36     │   33     │    3    │    0    │  91.7%  │   │
│  │ CM1-A   │   42     │   40     │    2    │    0    │  95.2%  │   │
│  │ CM2-A   │   41     │   38     │    2    │    1    │  92.7%  │   │
│  │ TOTAL   │  487     │  462     │   21    │    7    │  94.9%  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ⚠️  MODULE DISCIPLINE                                              │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ [+ Signaler un Incident]                                     │   │
│  │                                                              │   │
│  │ Date      │ Élève          │ Type        │ Sanction │ Notif. │   │
│  │ 25/05/26  │ NGOUABI Patrick│ Perturbation│ Avert.   │ ✅     │   │
│  │ 24/05/26  │ MILANDOU Serge │ Retard répété│ Avert. E│ ✅     │   │
│  │ 20/05/26  │ LOUBAKI Marie  │ Abs. non just│ Avert. O│ ✅     │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9️⃣ SECRÉTAIRE — INSCRIPTIONS

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📋 Inscriptions 2026-2027                  [+ Nouvelle Inscription] │
│ 487 inscrits · 13 dossiers en cours                                 │
│                                                                     │
│  Tabs: [Tous (487)] [Complets (474)] [Incomplets (13)] [Transferts] │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ 🗂️ Inscription en cours — KAFUTA Emmanuel · CP-A            │   │
│  │ Date: 20/05/2026 · Réinscription: Non                       │   │
│  │                                                              │   │
│  │ ✅ Identité       ✅ Coordonnées    ✅ Tuteurs               │   │
│  │ ✅ Infos scolaires ❌ Frais payés   ❌ Pièces justificatives │   │
│  │                                                              │   │
│  │ Pièces manquantes :                                          │   │
│  │ • ❌ Acte de naissance                                       │   │
│  │ • ❌ Carnet de vaccination                                    │   │
│  │ • ✅ Photo d'identité (fournie)                              │   │
│  │                                                              │   │
│  │ [📋 Compléter le dossier] [📤 Imprimer fiche] [❌ Annuler]  │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔟 ESPACE PARENT — VUE MOBILE (Flutter Android)

```
┌──────────────────────────────────────┐
│  ●●● Réseau MTN  9:41     🔋 84%    │
├──────────────────────────────────────┤
│  ☰  E-PILOTE              🔔 (3)    │
├──────────────────────────────────────┤
│                                      │
│  Bonjour, M. MOUKOUKOU Pierre 👋     │
│  Lundi 25 mai 2026                   │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │  👶 MOUKOUKOU Jean-Baptiste     │ │
│  │  CE1-A · École Primaire St-P.   │ │
│  │                                 │ │
│  │  Moy. générale T1 : 13.7/20    │ │
│  │  Mention : Bien                 │ │
│  │  Rang : 12ème / 38              │ │
│  │                                 │ │
│  │  Absences ce mois :  2          │ │
│  │  Paiement Mai :    ✅ Payé     │ │
│  └─────────────────────────────────┘ │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │  🔔 Alertes                     │ │
│  │                                 │ │
│  │  ⚠️  Bulletin T1 disponible !   │ │
│  │      Télécharger le PDF →       │ │
│  │                                 │ │
│  │  ℹ️  Évaluation Français        │ │
│  │      Jeudi 28 mai 2026          │ │
│  │                                 │ │
│  │  💰 Mensualité Juin due le 05/06│ │
│  │      12 000 XAF · [Payer MTN →]│ │
│  └─────────────────────────────────┘ │
│                                      │
│  ┌──────────────────────────────┐    │
│  │  📚 Notes par Matière · T1   │    │
│  │                              │    │
│  │  Français      ████████ 14.5│    │
│  │  Mathématiques █████████16.0│    │
│  │  Sciences      ████████ 15.0│    │
│  │  Hist-Géo      ███████  13.5│    │
│  │  Éd. Physique  █████████18.0│    │
│  │                              │    │
│  │  [Voir toutes les notes →]   │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │  📅 Absences · Mai 2026      │    │
│  │                              │    │
│  │  12/05 AM · Absence · Retard │    │
│  │  08/05 PM · Absence · Non    │    │
│  │            justifiée         │    │
│  └──────────────────────────────┘    │
│                                      │
├──────────────────────────────────────┤
│  [🏠 Accueil][📚 Notes][💰 Finance][✉️]│
└──────────────────────────────────────┘
```

---

## 1️⃣1️⃣ BULLETIN TRIMESTRIEL — VUE DIRECTEUR (Validation)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📋 Bulletins T1 2026-2027 · CE1-A · En attente de validation       │
│ 14 bulletins à valider · [✅ Valider tous] [❌ Rejeter]             │
│                                                                     │
│ ╔═══════════════════════════════════════════════════════════════╗   │
│ ║          BULLETIN TRIMESTRIEL — 1er TRIMESTRE 2026-2027       ║   │
│ ║  ÉCOLE PRIMAIRE SAINT-PIERRE DE BACONGO                       ║   │
│ ║                                                               ║   │
│ ║  ÉLÈVE : MOUKOUKOU Jean-Baptiste    Matricule : 2026-001      ║   │
│ ║  CLASSE : CE1-A    Effectif : 38    DDN : 15/03/2018          ║   │
│ ╠═══════════════════════════════════════════════════════════════╣   │
│ ║  Matière         Coef │ Note/20 │Moy Cl.│ Rang │ Appréciation  ║   │
│ ║  ─────────────── ─── │ ─────── │────── │ ──── │ ───────────── ║   │
│ ║  Français          4  │  14.5   │ 12.4  │  5   │ Bon travail   ║   │
│ ║  Mathématiques     4  │  16.0   │ 11.8  │  2   │ Excellent     ║   │
│ ║  Sciences Nat.     3  │  15.0   │ 13.2  │  4   │ Très bien     ║   │
│ ║  Hist-Géo-EMC      2  │  13.5   │ 12.0  │  7   │ Bien          ║   │
│ ║  Éducation Phys.   1  │  18.0   │ 15.5  │  1   │ Félicitations ║   │
│ ╠═══════════════════════════════════════════════════════════════╣   │
│ ║  SYNTHÈSE                                                      ║   │
│ ║  Moyenne générale : 15.05/20  │  Moyenne classe : 12.18/20    ║   │
│ ║  Rang : 3ème / 38              │  Mention : TRÈS BIEN          ║   │
│ ╠═══════════════════════════════════════════════════════════════╣   │
│ ║  Appréciation enseignant : "Élève sérieux et appliqué."       ║   │
│ ║  Appréciation directeur :  [_________________________________] ║   │
│ ║  Décision du conseil :  ● ADMIS  ○ REDOUBLANT  ○ ORIENTÉ     ║   │
│ ╠═══════════════════════════════════════════════════════════════╣   │
│ ║  [❌ Rejeter]   [💾 Sauvegarder]   [✅ Valider & Publier]      ║   │
│ ╚═══════════════════════════════════════════════════════════════╝   │
│                                                                     │
│  [← Bulletin précédent]    3/38    [Bulletin suivant →]            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1️⃣2️⃣ NOTIFICATIONS PUSH (Vue Mobile — tous rôles)

```
┌──────────────────────────────────────┐
│  🔔 Notifications (3 non lues)       │
│  ─────────────────────────────────── │
│                                      │
│  ● [BULLETIN] il y a 5 min           │
│    Le bulletin T1 de MOUKOUKOU       │
│    Jean-Baptiste est disponible.     │
│    [Télécharger PDF]                 │
│                                      │
│  ● [ABSENCE] il y a 2h              │
│    Votre enfant a été absent         │
│    ce matin (25/05/2026 · AM)        │
│    Classe : CE1-A                    │
│                                      │
│  ● [PAIEMENT] hier                  │
│    La mensualité de Juin 2026        │
│    est due le 05/06/2026.            │
│    Montant : 12 000 XAF             │
│    [Payer via MTN Money]             │
│                                      │
│  ─────────────────────────────────── │
│  ✓ [PAIEMENT] 24/05/2026            │
│    Paiement Mai confirmé.            │
│    Reçu N° REC-2026-001-0847        │
│                                      │
└──────────────────────────────────────┘
```

---

## 1️⃣3️⃣ TABLEAU DE BORD — ADMIN GROUPE INSTITUTIONNEL (ex : MEPSA, METP)

> 💡 Le MEPSA **n'est pas un rôle spécial** — c'est un **Groupe Scolaire** de type `public` avec le Plan **Institutionnel** (gratuit, financé par l'État).
> Son `admin_groupe` voit les KPIs de **toutes ses écoles** (nationales/régionales) exactement comme tout autre Admin Groupe, mais à une échelle plus grande.
> Pas de rôle supplémentaire dans le schéma — la distinction se fait via `group_type = 'public'`.

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🏛️  ADMIN GROUPE — Ministère MEPSA (Plan Institutionnel · Public)  │
│ 1 247 écoles · Vue nationale · Toutes les écoles du groupe MEPSA   │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ 🏫       │ │ 👨‍🎓       │ │ 💰       │ │ 📊       │              │
│  │ 1 247    │ │ 248 430  │ │  94.2%   │ │  13.4/20 │              │
│  │ Écoles   │ │  Élèves  │ │ Paiemts  │ │ Moy. nat.│              │
│  │ publiques│ │ publiques│ │  à jour  │ │          │              │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
│                                                                     │
│  KPI par Département                                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Département    │ Écoles │  Élèves │ Taux Scol │ Moy. Nat.    │  │
│  │ Brazzaville    │   487  │  89 234 │   87.4%   │  13.8/20    │  │
│  │ Pointe-Noire   │   312  │  67 891 │   84.1%   │  13.2/20    │  │
│  │ Pool           │   183  │  34 567 │   79.3%   │  12.7/20    │  │
│  │ Plateaux       │   127  │  21 432 │   72.1%   │  12.1/20    │  │
│  │ ...            │  ...   │    ...  │    ...    │    ...      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  [📤 Exporter rapport national PDF]  [📊 Voir rapports IA]         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📱 RÉSUMÉ DES ÉCRANS PAR RÔLE

| Rôle | Écrans Principaux | Plateforme |
|---|---|---|
| **SUPER_ADMIN** | Dashboard · Groupes · Plans · Modules · Admins | Desktop |
| **ADMIN_GROUPE** | Dashboard · Écoles · Utilisateurs · Profils · Abonnement | Desktop |
| **DIRECTEUR** | Dashboard · sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre| Desktop + Mobile |
| **PROVISEUR** | Dashboard · sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre| Desktop + Mobile |
| **ENSEIGNANT** | Notes · Présences · Cahier textes · Emploi du temps | Desktop + Mobile |
| **CPE** | Présences · sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre | Mobile |
| **COMPTABLE** | sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre | Desktop |
| **SECRÉTAIRE** | sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre| Desktop + Mobile |
| **SURVEILLANT** | sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre| Mobile |
| **PARENT** | Dashboard enfant · Notes · Absences · Paiements · Messagerie | Mobile |
| **ÉLÈVE** | Notes · Bulletins · Emploi du temps · Cahier textes | Mobile |
| **INFIRMIER** | sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre | Desktop + Mobile |
| **RESP. CANTINE** |sera attribué par admin groupe selon le sens de responsabilité,les modules apparaitront dynamiquement dans la sidebarre | Desktop + Mobile |

---
✅ GESTION DES ANNÉES ACADÉMIQUES — IMPLÉMENTÉE (voir schéma SQL Bloc 4)
   Les années académiques (2026-2027), trimestres et séquences sont bien gérés.
   Chaque rentrée crée une nouvelle academic_year avec is_current = TRUE.
   Toutes les données (classes, notes, bulletins, paiements…) sont liées à academic_year_id.

*E-PILOTE CONGO — Maquette Fonctionnelle v3.0 | Mai 2026 | Flutter · PowerSync · Supabase*
