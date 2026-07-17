# ModuLab Module Development Guide

This is the single entry point for building a module for ModuLab (https://modulab.app).
It covers everything a module needs: the tier model, the security model Core enforces
around your module, the manifest.yaml field reference, the handler API, and the
publishing workflow. Start here; you should not need to look anywhere else.

## What a module is

A ModuLab module is a plugin that runs inside the Core process and uses Core's own
infrastructure — PostgreSQL, Valkey, file storage, auth — rather than shipping its own.
Core is a single Go backend with a React/Vite frontend; modules extend it without
running as separate services or containers.

## Module tiers

- **Tier 1 — config-driven.** A `crud` block in `manifest.yaml` defines a table and its
  fields. Core generates the CRUD endpoints and, optionally, a fallback UI automatically.
  No backend code required.
- **Tier 2 — custom logic.** Adds a TypeScript handler (`handlers/index.ts`) that runs
  inside a sandboxed Deno Worker.
- **Tier 3 — external integrations.** Like tier 2, but additionally declares an
  `egress_allowlist` for outbound connections (e.g. UniFi RADIUS, Cloudflare).

## Security model

Modules do not implement their own authentication. Core calls the handler with an
already-verified, typed auth context (`ModuleAuthContext`) that should simply be
trusted.

Each handler runs in its own Deno Worker, with:

- `--allow-net` restricted to hosts listed in `egress_allowlist`
- `--allow-read`/`--allow-write` restricted to the module's own storage directory
- `--cached-only` enforced, so there is no runtime fetching of dependencies — vendor
  everything with `deno vendor` (see "Vendoring dependencies" below)
- a timeout and memory cap per call (`resources.timeout` / `resources.memory` in
  `manifest.yaml`, defaulting to 10s / 128m); exceeding either terminates only that
  call, not Core or other modules

The module UI renders inside a sandboxed iframe with an opaque origin: no access to the
parent page, `sessionStorage`, or other modules. All API calls go through a `postMessage`
RPC that Core exposes.

Database access is schema-scoped: a module can only read and write its own
`module_{name}` PostgreSQL schema, enforced by a dedicated PostgreSQL role — not just by
convention.

Tier 3 `credentials` are encrypted at rest and are never exposed to the frontend bundle;
your handler receives them pre-decrypted in `HandlerRequest.credentials`.

## Manifest reference

`manifest.yaml` is validated against a versioned JSON Schema, vendored in this repo at
`schema/v1/manifest.schema.json` (source: modulab-manifest-schema, MIT). Run
`scripts/update-schema.sh` to refresh it against a newer schema release.

Required fields: `name`, `version`, `author`, `license`, `category`, `min_core_api`,
`min_core_ui`, `tier`, `scope`.

| Field | Notes |
|---|---|
| `name` | Must match `modulab-mod-{name}` |
| `version` | SemVer |
| `license` | SPDX identifier; unknown values are rejected by registry CI |
| `category` | One of: productivity, finance, network, media, smart-home |
| `scope` | `per-location` (RLS-isolated per Standort) or `cross-location` (needs a `LocationSelector` in the UI, per-request location selection) |
| `tier` | 1, 2, or 3 (see above) |
| `startup` | `eager` or `lazy` (default `lazy`) |
| `resources.memory` / `resources.timeout` | Deno Worker caps, defaults `128m` / `10s` |
| `handler` | Tier 2/3 only: path to the entry handler, e.g. `handlers/index.ts` |
| `crud.table` / `crud.fields` | Tier 1 only: config-driven CRUD definition |
| `depends_on` | Dependencies on other modules, optionally with a SemVer range |
| `storage.quota` | Persistent file storage soft quota, e.g. `1g` |
| `credentials` | Tier 3 only: typed config values, encrypted at rest |
| `egress_allowlist` | Tier 3 only: `{host, port}` entries, enforced by `--allow-net` |
| `requested_scopes` | Shown to the admin as a plain-text warning before install |
| `jobs` | Background cron jobs (`name`, `schedule`, `handler`, optional `catch_up`), registered in the Valkey scheduler |

`source_repo`, `manifest_path`, `release_url` are only used in modulab-community
discovery entries, not in your module's own manifest.

See `schema/v1/manifest.schema.json` for the exact, authoritative shape of every field.

## Handler API (tier 2/3)

Copy `handlers/index.ts.example` to `handlers/index.ts` and implement your logic there.
Core passes a typed request into your default-exported handler function:

- `ModuleAuthContext` — `userId`, `userEmail`, `userName`, `roles`, `scopes`,
  `locationId`. Already verified by Core; trust it.
- `HandlerRequest` — `method`, `path`, `body`, `auth`, `credentials` (tier 3, pre-decrypted),
  `db` (`ModuleDbClient`, scoped to your own `module_{name}` schema).
- `HandlerResponse` — `status`, `body`.

Never log or echo `credentials` back in a response.

## Database

Write `migrations/001_initial.sql`. It runs against your module's own PostgreSQL schema
(`module_{name}`) — you cannot read or write outside it.

## UI

Build your UI as a React bundle using only `@modulab/ui` components — no custom CSS and
no other UI libraries. Tier 1 modules can skip the UI entirely and use Core's generated
CRUD view instead.

## Vendoring dependencies

Core runs handlers with `--cached-only`: anything not vendored fails at runtime instead
of being fetched. If your handler or jobs use external packages, vendor them with
`deno vendor` into a `vendor/` directory before packaging.

## Validating locally

```
./scripts/validate-manifest.sh manifest.yaml
```

Validates your `manifest.yaml` against the vendored schema in `schema/v1/manifest.schema.json`.

## Packaging & publishing

Package everything into `module.zip`.

- **Official modules** — open a pull request against modulab-modules.
- **Community modules** — keep your own repository, attach `module.zip` to a GitHub
  Release, and submit a discovery entry (with `release_url`) via pull request to
  modulab-community.

## Related repositories

- **modulab-core** — the Core backend and frontend that runs modules.
- **modulab-manifest-schema** — versioned source of the JSON Schema vendored here.
- **modulab-modules** — official modules.
- **modulab-community** — community module discovery index.

## License

AGPLv3, see LICENSE. A finished module can be published under its own license (`license`
field in the manifest); this SDK template itself is AGPLv3.
