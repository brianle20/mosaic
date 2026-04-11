# Mosaic

Mosaic is a native mobile app for running casual mahjong events, starting with standard Hong Kong mahjong.

This repository is intentionally structured around the MVP source of truth:

- Flutter app code lives under `lib/`
- Supabase SQL migrations live under `supabase/migrations/`
- Strongly typed domain models live under `lib/data/models/`
- Authoritative scoring and event finalization logic will live in Postgres functions and RPCs

## Phase 1 Scope

Phase 1 bootstraps the repository and foundation layers only:

- project structure
- Supabase schema migration
- `HK_STANDARD_V1` ruleset seed data
- typed domain models
- Supabase environment bootstrap

Feature flows like guest CRUD, sessions, scoring entry, and prize operations land in later phases.

