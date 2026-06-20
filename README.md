# modulab-module-sdk

Starter kit for developing your own ModuLab (https://modulab.app) modules.

ModuLab modules are plugins that run inside the Core process and use Core's own infrastructure (PostgreSQL, Valkey, file storage, auth). See the ModuLab Core specification, chapter 4, for the full architecture.

## Module tiers

Tier 1 modules are config-driven: a crud block in manifest.yaml defines a table and its fields, and Core generates the CRUD endpoints and, optionally, a fallback UI automatically, no backend code required. Tier 2 modules add a TypeScript handler that runs inside a sandboxed Deno Worker for custom logic. Tier 3 modules are like tier 2 but additionally declare an egress_allowlist for external integrations, for example UniFi RADIUS or Cloudflare.

## Contents

manifest.example.yaml is an annotated example manifest.yaml covering all fields across all tiers. handlers/index.ts.example is a tier 2/3 handler template showing the typed request, auth and database client interfaces Core passes into your handler. scripts/validate-manifest.sh validates a manifest.yaml locally against the vendored JSON schema from modulab-manifest-schema.

## Getting started

Copy manifest.example.yaml to manifest.yaml, set tier and fill in the fields relevant to your tier. Tier 1 modules only need a crud block, no code. Tier 2/3 modules should copy handlers/index.ts.example to handlers/index.ts and implement their logic there. Write migrations/001_initial.sql, which runs against your module's own PostgreSQL schema (module_{name}). Build your UI as a React bundle using only @modulab/ui components, no custom CSS and no other UI libraries (specification chapter 6.7), or skip the UI entirely for tier 1 to use Core's generated CRUD view. If your handler or jobs use external packages, vendor them with deno vendor into a vendor/ directory: Core runs handlers with --cached-only, so anything not vendored fails instead of being fetched at runtime. Validate locally with ./scripts/validate-manifest.sh manifest.yaml, then package everything into module.zip and attach it to a GitHub Release.

## Security requirements for modules

Modules do not implement their own authentication: Core calls the handler with an already-verified, typed auth context that should simply be trusted. Each handler runs in its own Deno Worker, with --allow-net restricted to hosts in egress_allowlist, --allow-read/write restricted to the module's own storage directory, and --cached-only enforced so there is no runtime fetching of dependencies. Every handler call has a timeout and memory cap (resources.timeout and resources.memory in manifest.yaml, defaulting to 10s and 128m), and exceeding either terminates only that call without affecting Core or other modules. The module UI renders inside a sandboxed iframe with an opaque origin, with no access to the parent page, sessionStorage, or other modules; all API calls go through a postMessage RPC that Core exposes. Database access is schema-scoped: a module can only read and write its own module_{name} schema, enforced by a dedicated PostgreSQL role rather than by convention alone.

## Publishing

Official modules are published by opening a pull request against modulab-modules. Community modules keep their own repository, attach module.zip to a GitHub Release, and submit a discovery entry (with release_url) via pull request to modulab-community.

Full specification: ModuLab Core specification (modulab-docs), chapter 4.

## License

AGPLv3, see LICENSE. A finished module can be published under its own license (SPDX license field in the manifest); this SDK template itself is AGPLv3.
