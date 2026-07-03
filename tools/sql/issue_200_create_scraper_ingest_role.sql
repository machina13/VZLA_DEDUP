-- Issue #200: Rol dedicado scraper_ingest + grants mínimos.
--
-- Requisitos previos en dataVenezuela (backend):
--   - Migración que agregue las columnas trust_tier, fetched_at,
--     confidence_score a public.aportes (para el consolidation job)
--
-- Este script crea:
--   1. El rol scraper_ingest (NOLOGIN, el SET ROLE lo hace PostgREST)
--   2. La membresía a authenticator (obligatorio para SET ROLE)
--   3. Grants mínimos sobre aportes, source_watermarks y sources
--   4. UNIQUE(source_id, external_id), requerido por on_conflict
--   5. Policies RLS mínimas para el rol scraper_ingest
--
-- Generar el JWT (una sola vez, offline):
--   import jwt, os
--   from datetime import datetime, timedelta, timezone
--   token = jwt.encode(
--       {"role": "scraper_ingest",
--        "iat": datetime.now(timezone.utc),
--        "exp": datetime.now(timezone.utc) + timedelta(days=365)},
--       os.environ["SUPABASE_JWT_SECRET"],
--       algorithm="HS256"
--   )
--   print(token)
--
-- Guardar como SUPABASE_INGEST_JWT en GitHub Secrets.
-- Guardar SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY también.
--
-- Ejecutar en el SQL Editor de Supabase ANTES del primer deploy del PR.

-- 1. Rol dedicado
CREATE ROLE scraper_ingest WITH NOLOGIN NOINHERIT NOBYPASSRLS;

-- PostgREST autentica como authenticator y hace SET ROLE al claim del JWT.
GRANT scraper_ingest TO authenticator;

GRANT USAGE ON SCHEMA public TO scraper_ingest;
GRANT INSERT, UPDATE ON public.aportes TO scraper_ingest;
GRANT INSERT, UPDATE ON public.source_watermarks TO scraper_ingest;
GRANT SELECT ON public.source_watermarks TO scraper_ingest;
GRANT SELECT ON public.sources TO scraper_ingest;

-- 2. Conflict target real para PostgREST:
--    /rest/v1/aportes?on_conflict=source_id,external_id
CREATE UNIQUE INDEX IF NOT EXISTS aportes_source_id_external_id_key
ON public.aportes (source_id, external_id);

-- 3. RLS policies mínimas para el rol dedicado.
--    Usar DO blocks hace que el script sea idempotente si se re-ejecuta.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'sources'
      AND policyname = 'sources_select_scraper_ingest'
  ) THEN
    CREATE POLICY sources_select_scraper_ingest
    ON public.sources
    FOR SELECT
    TO scraper_ingest
    USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'aportes'
      AND policyname = 'aportes_insert_scraper_ingest'
  ) THEN
    CREATE POLICY aportes_insert_scraper_ingest
    ON public.aportes
    FOR INSERT
    TO scraper_ingest
    WITH CHECK (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'aportes'
      AND policyname = 'aportes_update_scraper_ingest'
  ) THEN
    CREATE POLICY aportes_update_scraper_ingest
    ON public.aportes
    FOR UPDATE
    TO scraper_ingest
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'source_watermarks'
      AND policyname = 'source_watermarks_select_scraper_ingest'
  ) THEN
    CREATE POLICY source_watermarks_select_scraper_ingest
    ON public.source_watermarks
    FOR SELECT
    TO scraper_ingest
    USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'source_watermarks'
      AND policyname = 'source_watermarks_insert_scraper_ingest'
  ) THEN
    CREATE POLICY source_watermarks_insert_scraper_ingest
    ON public.source_watermarks
    FOR INSERT
    TO scraper_ingest
    WITH CHECK (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'source_watermarks'
      AND policyname = 'source_watermarks_update_scraper_ingest'
  ) THEN
    CREATE POLICY source_watermarks_update_scraper_ingest
    ON public.source_watermarks
    FOR UPDATE
    TO scraper_ingest
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;
