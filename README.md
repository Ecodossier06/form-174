# BAR-TH-174 · Formulaire CEE

Formulaire de dépôt de dossiers de rénovation d'ampleur (BAR-TH-174) avec backoffice sécurisé.

---

## Structure des fichiers

```
bar174/
├── index.html          → Formulaire public
├── backoffice.html     → Interface d'administration
├── supabase_setup.sql  → Script SQL complet (tables + RLS)
├── favicon.ico         → Icône navigateur
├── favicon.png         → Icône PNG
├── og-image.png        → Miniature WhatsApp / réseaux sociaux (1200×630)
└── README.md
```

---

## Mise en place Supabase

### 1. Exécuter le SQL
Dans Supabase → **SQL Editor** → coller et exécuter `supabase_setup.sql`

### 2. Créer les comptes utilisateurs
Dashboard → **Authentication → Users → Add user**

Créer un compte pour chaque membre de l'équipe.

### 3. Assigner les rôles
Copier l'UUID de chaque utilisateur (colonne UID dans la liste) et exécuter :

```sql
INSERT INTO public.user_roles (user_id, role) VALUES
  ('UUID-ADMIN',        'admin'),
  ('UUID-RESPONSABLE',  'responsable'),
  ('UUID-SECRETAIRE',   'secretaire');
```

**Rôles disponibles :**
| Rôle | Droits |
|------|--------|
| `admin` | Tout (y compris supprimer) |
| `responsable` | Dossiers + apporteurs (créer/modifier) |
| `secretaire` | Dossiers (voir + changer statut) + PJ |

### 4. Ajouter des apporteurs
Dans le backoffice → **Apporteurs** → Ajouter nom + code.

Ou directement en SQL :
```sql
INSERT INTO public.apporteurs (nom, code) VALUES
  ('Jean Martin',   'JM01'),
  ('Sophie Durand', 'SD02');
```

---

## Déploiement GitHub Pages

1. Créer un repo GitHub (public ou privé)
2. Uploader tous les fichiers à la racine
3. Aller dans **Settings → Pages**
4. Source : `Deploy from a branch` → branche `main` → dossier `/` (root)
5. Sauvegarder → URL générée automatiquement

> ⚠️ GitHub Pages est public par défaut. Le `backoffice.html` est protégé par Supabase Auth mais reste accessible en URL. Pour plus de sécurité, héberger sur Netlify avec mot de passe de site, ou séparer les deux fichiers.

---

## Déploiement Netlify (recommandé)

1. [netlify.com](https://netlify.com) → New site → Import from GitHub
2. Build command : *(laisser vide)*
3. Publish directory : `.` (racine)
4. Deploy

**Protéger le backoffice :**
Netlify → Site settings → **Access control → Password protection**

---

## Sécurité Supabase

- **anon** : INSERT formulaire + upload PJ uniquement
- **Aucun SELECT** possible pour anon → les données ne sont pas lisibles publiquement
- **Storage** : bucket privé, URLs signées 60s pour les téléchargements
- **RLS** activé sur toutes les tables

---

## Miniature WhatsApp / réseaux

Le fichier `og-image.png` (1200×630) est référencé dans `index.html` via les balises `og:image`.  
Quand le lien est partagé sur WhatsApp, iMessage ou Facebook, cette image s'affiche automatiquement.
