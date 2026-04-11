# Mosaic MVP Foundation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the Mosaic Flutter + Supabase codebase and deliver the Phase 1 foundation for schema, typed models, and environment wiring.

**Architecture:** Use Flutter for the native client with a feature-first folder layout, Supabase Postgres as the source of truth, and SQL migrations for authoritative schema and seed data. Keep domain rules explicit in typed Dart models and reserve scoring/finalization authority for server-side SQL and RPC functions in later phases.

**Tech Stack:** Flutter, Dart, Supabase, Postgres SQL migrations, Flutter test

---

## File Map

- Create: `/.gitignore`
- Create: `/README.md`
- Create: `/analysis_options.yaml`
- Create: `/pubspec.yaml`
- Create: `/.env.example`
- Create: `/lib/main.dart`
- Create: `/lib/app/app.dart`
- Create: `/lib/core/config/app_environment.dart`
- Create: `/lib/core/config/supabase_config.dart`
- Create: `/lib/core/theme/app_theme.dart`
- Create: `/lib/data/models/event_models.dart`
- Create: `/lib/data/models/guest_models.dart`
- Create: `/lib/data/models/ruleset_models.dart`
- Create: `/lib/data/models/session_models.dart`
- Create: `/lib/data/models/tag_models.dart`
- Create: `/lib/data/models/prize_models.dart`
- Create: `/lib/data/repositories/repository_interfaces.dart`
- Create: `/lib/data/supabase/supabase_bootstrap.dart`
- Create: `/supabase/config.toml`
- Create: `/supabase/migrations/20260410230000_core_schema.sql`
- Create: `/test/data/models/domain_model_serialization_test.dart`

## Chunk 1: Repository Bootstrap

### Task 1: Root project files

**Files:**
- Create: `/.gitignore`
- Create: `/README.md`
- Create: `/analysis_options.yaml`
- Create: `/pubspec.yaml`
- Create: `/.env.example`

- [ ] **Step 1: Write the bootstrap expectations**

Document the initial repo responsibilities in `README.md`, including Flutter app ownership, Supabase migration ownership, and Phase 1 scope boundaries.

- [ ] **Step 2: Add the minimal Flutter package manifest**

Declare the app package, SDK constraints, and only the dependencies needed for Phase 1 (`flutter`, `supabase_flutter`, `flutter_dotenv`, `meta`, `collection`, `test` support).

- [ ] **Step 3: Add repository hygiene files**

Add `.gitignore`, `analysis_options.yaml`, and `.env.example` with placeholders for the Supabase URL and publishable key.

- [ ] **Step 4: Verify the file set**

Run: `find . -maxdepth 2 -type f | sort`
Expected: root bootstrap files plus docs and supabase directories are present.

## Chunk 2: Flutter Shell and Configuration

### Task 2: App shell and environment wiring

**Files:**
- Create: `/lib/main.dart`
- Create: `/lib/app/app.dart`
- Create: `/lib/core/config/app_environment.dart`
- Create: `/lib/core/config/supabase_config.dart`
- Create: `/lib/core/theme/app_theme.dart`
- Create: `/lib/data/supabase/supabase_bootstrap.dart`

- [ ] **Step 1: Write the failing environment test**

Add a focused Flutter or Dart unit test that proves Supabase config parsing rejects incomplete configuration.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL because config and models do not exist yet.

- [ ] **Step 3: Add the app bootstrap**

Create a thin `main.dart` that loads environment configuration, initializes Supabase, and launches a minimal `MaterialApp`.

- [ ] **Step 4: Re-run the focused test**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS for the configuration scenario covered so far.

## Chunk 3: Core Schema and Seed Data

### Task 3: MVP relational schema

**Files:**
- Create: `/supabase/config.toml`
- Create: `/supabase/migrations/20260410230000_core_schema.sql`

- [ ] **Step 1: Write a schema checklist in comments**

Capture every required MVP table, key enum/check domain, index, and the `HK_STANDARD_V1` seed inside the migration header.

- [ ] **Step 2: Implement the initial migration**

Create the full Phase 1 schema with tables, constraints, timestamps, row-version defaults, useful indexes, and `updated_at` trigger support.

- [ ] **Step 3: Add seed rows**

Insert the `HK_STANDARD_V1` ruleset and a clearly marked dev-only demo event seed that can be removed later if it becomes noisy.

- [ ] **Step 4: Verify the migration file shape**

Run: `sed -n '1,260p' supabase/migrations/20260410230000_core_schema.sql`
Expected: migration includes all Phase 1 tables and the ruleset seed.

## Chunk 4: Typed Domain Models

### Task 4: Strongly typed Dart domain layer

**Files:**
- Create: `/lib/data/models/event_models.dart`
- Create: `/lib/data/models/guest_models.dart`
- Create: `/lib/data/models/ruleset_models.dart`
- Create: `/lib/data/models/session_models.dart`
- Create: `/lib/data/models/tag_models.dart`
- Create: `/lib/data/models/prize_models.dart`
- Create: `/lib/data/repositories/repository_interfaces.dart`
- Create: `/test/data/models/domain_model_serialization_test.dart`

- [ ] **Step 1: Write failing tests for domain serialization and enums**

Cover event lifecycle parsing, guest eligibility for tag assignment, explicit session ruleset storage, and prize distributable-budget math.

- [ ] **Step 2: Run the focused test file and verify failure**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL because model classes are missing.

- [ ] **Step 3: Implement the minimal typed models**

Add immutable domain classes and enums with explicit JSON conversion and small helper methods for MVP rules.

- [ ] **Step 4: Re-run the focused test file**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS.

## Chunk 5: Verification and Handoff

### Task 5: Phase 1 verification

**Files:**
- Verify: all files created in previous chunks

- [ ] **Step 1: Run the best available verification commands**

Preferred:
`flutter test`
`flutter analyze`

Fallback if Flutter is unavailable:
`find . -maxdepth 3 -type f | sort`

- [ ] **Step 2: Summarize Phase 1 outputs**

Report what shipped, any environment gaps, and the recommended Phase 2 start point: event + guest CRUD flows.

