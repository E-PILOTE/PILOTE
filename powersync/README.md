# PowerSync Auto-hébergé — E-PILOTE CONGO

Stack : Supabase (source) ↔ PowerSync (self-hosted, Docker) ↔ SQLite (Flutter)

---

## 📋 Prérequis

- Docker + Docker Compose installés
- Accès au dashboard Supabase : https://supabase.com/dashboard/project/wqpdamlnrwgozfvzjjpo
- IPv6 activé dans Docker (requis pour la connexion directe à Supabase)

---

## 🚀 Installation étape par étape

### Étape 1 — Activer IPv6 dans Docker (Linux)

```bash
sudo nano /etc/docker/daemon.json
```

Ajouter ou fusionner avec ce contenu :
```json
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
```

Redémarrer Docker :
```bash
sudo systemctl restart docker
```

### Étape 2 — Configurer Supabase (une seule fois)

1. Aller dans **Supabase Dashboard → SQL Editor**
2. Exécuter le fichier `supabase-setup.sql` (créer le rôle + publication)
3. ⚠️ Mémoriser le mot de passe choisi pour `powersync_role`

### Étape 3 — Récupérer les secrets Supabase

| Secret | Où le trouver |
|--------|---------------|
| Mot de passe DB (`powersync_role`) | Défini à l'étape 2 |
| JWT Secret | Dashboard → Settings → API → JWT Settings |
| Mot de passe base Supabase (postgres user) | Dashboard → Settings → Database |

### Étape 4 — Créer le fichier .env

```bash
cd /home/melack/E-PILOTE/powersync
cp .env.example .env
nano .env
```

Remplir les 3 valeurs :
```env
SUPABASE_DB_PASSWORD=MOT_DE_PASSE_ICI    # Mot de passe du rôle powersync_role
SUPABASE_JWT_SECRET=VOTRE_JWT_SECRET     # Depuis Supabase Dashboard
STORAGE_DB_PASSWORD=epilote_storage_2026  # Garder tel quel ou choisir autre
```

### Étape 5 — Lancer PowerSync

```bash
cd /home/melack/E-PILOTE/powersync
docker compose up -d
```

Vérifier que tout tourne :
```bash
docker compose ps
docker compose logs -f powersync
```

Le service PowerSync est disponible sur **http://localhost:8080**

### Étape 6 — Vérifier la santé du service

```bash
curl http://localhost:8080/api/v1/health
# Réponse attendue : {"status":"ok"}
```

---

## 🔧 Configuration Flutter

L'URL PowerSync est déjà configurée dans l'app :
`lib/services/powersync/powersync_connector.dart`

```dart
const String _powerSyncUrl = 'http://localhost:8080';
```

Pour la production, remplacer par l'URL de votre serveur déployé.

---

## 📊 Architecture de données

```
Supabase PostgreSQL (eu-central-2)
    │
    │ Réplication logique (publication "powersync")
    │ Connexion directe IPv6 → rôle powersync_role
    ▼
PowerSync Service (Docker, localhost:8080)
    │
    │ Sync state stocké dans PostgreSQL local (storage-db)
    │ Règles de sync : config/sync-rules.yaml
    │ Auth JWT : tokens Supabase
    ▼
Flutter App (SQLite local via powersync package)
    │ Chaque utilisateur sync uniquement SES données
    │ (group_id / school_id)
    ▼
Interface utilisateur (offline-first)
```

---

## 🛠️ Commandes utiles

```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Voir les logs
docker compose logs -f powersync

# Redémarrer si config modifiée
docker compose restart powersync

# Réinitialiser complètement (⚠️ perd le sync state)
docker compose down -v
docker compose up -d
```

---

## 🚨 Dépannage

### "Connection refused" sur Supabase
→ IPv6 non activé dans Docker. Refaire l'étape 1.

### "Authentication failed" pour powersync_role
→ Vérifier le mot de passe dans `.env` et `supabase-setup.sql`

### "Publication not found"
→ Exécuter `supabase-setup.sql` dans Supabase SQL Editor

### Sync ne démarre pas
→ Vérifier `docker compose logs powersync` pour le message d'erreur précis
