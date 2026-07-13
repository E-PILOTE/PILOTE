-- 0038 — Storage : policy SELECT manquante sur le bucket `group-logos`
--
-- Symptôme : l'upload d'un logo d'école échouait avec
--   403 { "message": "new row violates row-level security policy" }
--
-- Cause : `uploadBinary(..., upsert: true)` fait exécuter à storage-api un
-- `INSERT ... ON CONFLICT DO UPDATE`. Postgres exige un droit **SELECT** sur la
-- table cible pour la branche DO UPDATE (il doit lire la ligne en conflit).
-- Le bucket n'avait que INSERT / UPDATE / DELETE → l'INSERT était rejeté avant
-- même d'atteindre le conflit, avec un message trompeur.
--
-- Le bucket est PUBLIC (les logos sont servis en clair) : autoriser la lecture
-- aux utilisateurs authentifiés n'expose rien de plus et débloque aussi les
-- flux « lister / remplacer » côté client.

DROP POLICY IF EXISTS group_logos_auth_select ON storage.objects;

CREATE POLICY group_logos_auth_select
  ON storage.objects FOR SELECT
  USING (bucket_id = 'group-logos' AND auth.role() = 'authenticated');
