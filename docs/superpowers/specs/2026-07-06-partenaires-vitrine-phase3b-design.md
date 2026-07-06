# Phase 3b — Placements partenaires sur la vitrine des postes

**Date** : 2026-07-06
**Statut** : à valider (⚠️ décision de politique requise — voir §Gouvernance)
**Dépend de** : Phase 1 (`VitrineShell.showPartner` déjà câblé) + Phase 3a (canal éditorial en place).
**Sensibilité** : ⚠️⚠️ migration + sync-rules + **Storage** + **politique de curation** en contexte public/scolaire.

## Pourquoi cette spec est différente des autres

La vitrine s'affiche sur chaque poste de 1000+ écoles publiques, commande MEPSA+METP, dans des établissements accueillant des enfants. Y placer des encarts partenaires est un **actif de visibilité national**, mais aussi un **risque réputationnel et contractuel** réel. Cette spec n'est pas qu'un travail technique : elle encode une **politique**. Elle est écrite pour que le responsable l'active **en conscience**, avec des garde-fous non contournables.

**Ce que cette spec autorise** : des encarts **institutionnels / éducatifs curatés** (ex. partenaire ministériel, ONG éducative, éditeur scolaire), validés un par un par le super_admin, activés volontairement par chaque groupe, clairement étiquetés « Partenaire », discrets, en bas de vitrine, **jamais** en travers du bouton « Ouvrir une session ».

**Ce que cette spec interdit par construction** :
- pas de régie publicitaire tierce / enchères / réseau d'annonceurs ;
- pas de tracking ni de télémétrie de clics vers un tiers (le poste est souvent hors-ligne de toute façon) ;
- pas d'affichage sans opt-in explicite du groupe ;
- pas de placement qui masque ou retarde l'ouverture de session.

## Gouvernance (double garde-fou, non contournable)

1. **Curation super_admin** — seul le super_admin crée un partenaire (liste blanche). Champ `category` restreint à un enum éducatif/institutionnel ; un partenaire inactif ou hors fenêtre de dates ne descend pas.
2. **Opt-in par groupe** — un partenaire ne s'affiche sur les postes d'un groupe que si l'**admin_groupe** a explicitement activé l'affichage partenaires pour son groupe (`school_groups.partner_display_enabled`, défaut **false**). Silence = rien.

Décision produit à trancher avant implémentation (§Questions ouvertes).

## Changements

### 1. Base — migration `0035_platform_partners.sql`
```sql
CREATE TABLE IF NOT EXISTS platform_partners (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  logo_url    text,                 -- Storage public (bucket `partner-logos`)
  website_url text,                 -- informatif ; non cliquable hors-ligne
  category    text NOT NULL DEFAULT 'institutionnel',  -- enum applicatif
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  integer NOT NULL DEFAULT 0,
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE platform_partners ENABLE ROW LEVEL SECURITY;
CREATE POLICY pp_super_all ON platform_partners
  FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY pp_read_active ON platform_partners
  FOR SELECT USING (is_active = true);

-- Opt-in par groupe (contrôlé par admin_groupe).
ALTER TABLE school_groups
  ADD COLUMN IF NOT EXISTS partner_display_enabled boolean NOT NULL DEFAULT false;
```
- **RLS** : la table `platform_partners` suit exactement le modèle de `platform_service_messages` (0034). Pour `school_groups.partner_display_enabled`, **vérifier live** que la policy UPDATE d'admin_groupe sur `school_groups` existe et couvre la colonne (admin_groupe édite déjà son groupe → attendu OK, sinon restreindre l'écriture à cette colonne).
- Enum `category` **applicatif** (pas de type PG) : `{institutionnel, educatif, ong, editeur}`. Volontairement fermé.

### 2. Storage — bucket `partner-logos`
Nouveau bucket **public en lecture** (les logos ne sont pas sensibles), écriture super_admin. Upload via `client.storage.from('partner-logos')` (pattern `group-logos`). ⚠️ Création du bucket + policy = action manuelle console/CLI Supabase.

### 3. Sync-rules (`config/sync-rules.yaml`)
- Partenaires → bucket **global** `global_catalog` (comme les messages) :
```yaml
      - SELECT id, name, logo_url, website_url, category, is_active,
          sort_order, starts_at, ends_at
        FROM platform_partners WHERE is_active = true
```
- `school_groups.partner_display_enabled` : **aucune modification** — `by_group` fait déjà `SELECT * FROM school_groups`, la colonne descend automatiquement.
⚠️ Redéploiement dashboard PowerSync (uniquement pour le SELECT partenaires).

### 4. Schéma local (`powersync_schema.dart`)
- Nouvelle table `platform_partners` (name, logo_url, website_url, category, is_active, sort_order, starts_at, ends_at).
- `school_groups` : + `Column.integer('partner_display_enabled')`.

### 5. Staff — provider offline (`vitrine_partners_provider.dart`)
- **Fonction pure** `isPartnerLive(now, starts, ends, active)` (réutilise la logique de `isMessageLive`).
- **Fonction pure** `showPartnerStrip(bool groupOptedIn, bool hasLivePartners)` = `groupOptedIn && hasLivePartners`.
- `vitrinePartnersProvider` : `db.watch` sur `platform_partners`, filtré actif+fenêtre, trié `sort_order`, plafonné à 2–3 → `List<PartnerVitrineItem>{name, logoUrl}`.
- `groupPartnerOptInProvider` : `db.watch` sur `school_groups` (la ligne du groupe de l'appareil) → bool.
- `AgentLockScreen` : `showPartner = showPartnerStrip(optIn, partners.isNotEmpty)` ; passe la liste + le drapeau à `VitrineShell`.

### 6. `VitrineShell` — rendu réel de `_PartnerStrip`
Remplacer les rectangles maquette par : label « EN PARTENARIAT AVEC · PARTENAIRE », puis logos réels (`CachedNetworkImage`), **repli sur le nom en texte** si le logo n'est pas encore en cache.
⚠️ **Limite offline connue** : `CachedNetworkImage` ne met en cache qu'après un 1ᵉʳ chargement en ligne. Sur un poste durablement hors-ligne qui n'a jamais vu le logo → repli texte. Acceptable (le nom reste lisible) ; à documenter.

### 7. super_admin — CRUD (`platform_partners_screen.dart` + provider)
Calqué sur Phase 3a : liste + formulaire (nom, upload logo, site, catégorie, ordre, fenêtre de dates, actif) + toggle + suppression. Route `superPartenaires = '/super/messagerie/partenaires'` + nav section COMMUNICATION.

### 8. admin_groupe — interrupteur d'opt-in
Un `SwitchListTile` « Afficher les partenaires E-PILOTE sur les postes » dans **Paramètres admin_groupe** (ou l'écran Abonnement/Modules), écrivant `school_groups.partner_display_enabled` via `supabase.from('school_groups').update(...)`. Texte explicite : opt-in, désactivable à tout moment, encart discret non commercial agressif.

### 9. Tests
- `isPartnerLive` : matrice (identique à `isMessageLive`).
- `showPartnerStrip` : (optIn × hasPartners) → seul `true×true` affiche.
- Provider staff : mapping/tri/plafond.
- Golden vitrine avec bande partenaire (repli texte, pas de réseau en test).

## Ordre de déploiement (rétro-compatible)
1. Migration 0035. 2. Bucket `partner-logos`. 3. sync-rules dashboard. 4. release app. 5. super_admin crée des partenaires. 6. chaque admin_groupe opte in.
Défauts sûrs à chaque étape : table vide + opt-in false = **aucun encart** (vitrine Phase 1/3a inchangée).

## Questions ouvertes (à trancher avant implémentation)
1. **Granularité de l'opt-in** : par **groupe** (retenu, simple) ou par **école** ? Le poste est au niveau école mais admin_groupe pilote le groupe → groupe cohérent avec la gouvernance. Recommandation : groupe.
2. **Ciblage** : un partenaire est-il **global** (tous les groupes opt-in) — retenu pour v1 — ou **ciblable** par groupe (table de jointure `partner_group_targets`) ? Recommandation : global v1, ciblage plus tard si besoin commercial réel.
3. **Rémunération** : cette spec ne modélise **aucun** flux financier/contrat. Si des partenariats payants existent, la traçabilité (contrat, période, facturation) est un chantier séparé — la vitrine n'est que l'affichage.
4. **Validation éditoriale** : faut-il un état `pending → approved` (double validation) ou la création super_admin vaut-elle approbation ? Recommandation v1 : création super_admin = approbation (le super_admin EST l'autorité de curation).

## Hors périmètre
Facturation partenaires, statistiques d'affichage/clic, ciblage fin, A/B, rotation pondérée.
