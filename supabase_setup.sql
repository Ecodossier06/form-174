-- ============================================================
-- BAR-TH-174 · SQL COMPLET
-- À exécuter dans Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. TABLE USER_ROLES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_roles (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('admin', 'responsable', 'secretaire')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_read_own_role" ON public.user_roles;
CREATE POLICY "auth_read_own_role"
  ON public.user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Admin peut tout gérer les rôles
DROP POLICY IF EXISTS "admin_manage_roles" ON public.user_roles;
CREATE POLICY "admin_manage_roles"
  ON public.user_roles FOR ALL TO authenticated
  USING (public.get_my_role() = 'admin')
  WITH CHECK (public.get_my_role() = 'admin');

-- ============================================================
-- 2. FONCTION HELPER ROLE
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.user_roles WHERE user_id = auth.uid();
$$;

-- ============================================================
-- 3. TABLE APPORTEURS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.apporteurs (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nom        text NOT NULL,
  code       text NOT NULL UNIQUE,
  actif      boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);
ALTER TABLE public.apporteurs ENABLE ROW LEVEL SECURITY;

-- SELECT : tous les rôles staff + anon (pour charger la liste dans le formulaire)
DROP POLICY IF EXISTS "anon_select_apporteurs" ON public.apporteurs;
CREATE POLICY "anon_select_apporteurs"
  ON public.apporteurs FOR SELECT TO anon
  USING (actif = true);

DROP POLICY IF EXISTS "staff_select_apporteurs" ON public.apporteurs;
CREATE POLICY "staff_select_apporteurs"
  ON public.apporteurs FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('admin', 'responsable', 'secretaire'));

-- INSERT/UPDATE/DELETE : admin et responsable uniquement
DROP POLICY IF EXISTS "responsable_insert_apporteurs" ON public.apporteurs;
CREATE POLICY "responsable_insert_apporteurs"
  ON public.apporteurs FOR INSERT TO authenticated
  WITH CHECK (public.get_my_role() IN ('admin', 'responsable'));

DROP POLICY IF EXISTS "responsable_update_apporteurs" ON public.apporteurs;
CREATE POLICY "responsable_update_apporteurs"
  ON public.apporteurs FOR UPDATE TO authenticated
  USING (public.get_my_role() IN ('admin', 'responsable'))
  WITH CHECK (public.get_my_role() IN ('admin', 'responsable'));

DROP POLICY IF EXISTS "admin_delete_apporteurs" ON public.apporteurs;
CREATE POLICY "admin_delete_apporteurs"
  ON public.apporteurs FOR DELETE TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- 4. TABLE FORMULAIRE_174 (mise à jour)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.formulaire_174 (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      timestamptz DEFAULT now() NOT NULL,
  nom             text NOT NULL,
  prenom          text NOT NULL,
  statut          text NOT NULL CHECK (statut IN ('grand_precaire', 'sci')),
  tel             text NOT NULL,
  email           text NOT NULL,
  adresse_client  text NOT NULL,
  surface_m2      integer NOT NULL CHECK (surface_m2 > 0),
  type_logement   text,
  type_chauffage  text NOT NULL,
  geste_1         text CHECK (geste_1 IN ('comble','plancher_bas','mur_interieur_25')),
  geste_2         text CHECK (geste_2 IN ('comble','plancher_bas','mur_interieur_25')),
  pj_urls         text[] DEFAULT '{}',
  code_apporteur  text REFERENCES public.apporteurs(code),
  statut_dossier  text DEFAULT 'nouveau' CHECK (statut_dossier IN ('nouveau','en_cours','valide','refuse'))
);
ALTER TABLE public.formulaire_174 ENABLE ROW LEVEL SECURITY;

-- Supprimer toutes les policies existantes
DROP POLICY IF EXISTS "anon_insert_only"      ON public.formulaire_174;
DROP POLICY IF EXISTS "staff_select"          ON public.formulaire_174;
DROP POLICY IF EXISTS "staff_update_statut"   ON public.formulaire_174;
DROP POLICY IF EXISTS "admin_delete"          ON public.formulaire_174;

-- anon : INSERT uniquement
CREATE POLICY "anon_insert_only"
  ON public.formulaire_174 FOR INSERT TO anon
  WITH CHECK (true);

-- staff : SELECT
CREATE POLICY "staff_select"
  ON public.formulaire_174 FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('admin','responsable','secretaire'));

-- responsable + secrétaire + admin : UPDATE statut
CREATE POLICY "staff_update_statut"
  ON public.formulaire_174 FOR UPDATE TO authenticated
  USING (public.get_my_role() IN ('admin','responsable','secretaire'))
  WITH CHECK (public.get_my_role() IN ('admin','responsable','secretaire'));

-- admin uniquement : DELETE
CREATE POLICY "admin_delete"
  ON public.formulaire_174 FOR DELETE TO authenticated
  USING (public.get_my_role() = 'admin');

-- Sécurité supplémentaire
REVOKE SELECT, UPDATE, DELETE ON public.formulaire_174 FROM anon;
REVOKE SELECT, UPDATE, DELETE ON public.apporteurs FROM anon;

-- ============================================================
-- 5. STORAGE BUCKET
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'storage','storage', false, 10485760,
  ARRAY['application/pdf','image/jpeg','image/png','image/webp',
        'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO UPDATE SET public=false, file_size_limit=10485760;

DROP POLICY IF EXISTS "anon_upload_only"   ON storage.objects;
DROP POLICY IF EXISTS "staff_read_storage" ON storage.objects;

CREATE POLICY "anon_upload_only"
  ON storage.objects FOR INSERT TO anon
  WITH CHECK (bucket_id='storage');

CREATE POLICY "staff_read_storage"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id='storage' AND public.get_my_role() IN ('admin','responsable','secretaire'));

-- ============================================================
-- 6. INDEX
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_f174_created  ON public.formulaire_174(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_f174_statut   ON public.formulaire_174(statut_dossier);
CREATE INDEX IF NOT EXISTS idx_f174_apport   ON public.formulaire_174(code_apporteur);
CREATE INDEX IF NOT EXISTS idx_apport_code   ON public.apporteurs(code);

-- ============================================================
-- 7. ASSIGNER LES ROLES (après création des comptes Auth)
-- Remplace les UUIDs par ceux de tes utilisateurs
-- Dashboard → Authentication → Users → copier UUID
-- ============================================================
-- INSERT INTO public.user_roles (user_id, role) VALUES
--   ('UUID-ADMIN',       'admin'),
--   ('UUID-RESPONSABLE', 'responsable'),
--   ('UUID-SECRETAIRE',  'secretaire');

-- ============================================================
-- 8. EXEMPLE APPORTEURS
-- ============================================================
-- INSERT INTO public.apporteurs (nom, code) VALUES
--   ('Jean Martin',    'JM01'),
--   ('Sophie Durand',  'SD02'),
--   ('Pierre Lemaire', 'PL03');
