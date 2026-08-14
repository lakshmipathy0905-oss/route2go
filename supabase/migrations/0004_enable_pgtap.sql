-- Route2Go — Enable pgTAP for database tests
-- Migration: 0004_enable_pgtap.sql
--
-- Installs the pgTAP extension into the `extensions` schema (matching the
-- schema Supabase's bootstrap uses) so `supabase test db` / pg_prove can run
-- RLS and unit tests against the database. The extension is created only if
-- not present; it is safe to apply in any environment.

create extension if not exists pgtap with schema extensions;
