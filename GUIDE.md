# ModuLab Module Development Guide

This is the single entry point for building a module for ModuLab (https://modulab.app).
It describes the actual current behavior of Core (backend/internal/modules/* in
modulab-core), not an aspirational spec — where something is planned but not yet built,
it is marked as such explicitly. Start here; you should not need to look anywhere else.

## What a module is

A ModuLab module is a plugin that runs inside the Core process and uses Core's own
infrastructure — PostgreSQL, Valkey, file storage, auth — rather than shipping its own.
Core is a single Go backend with a React/Vite frontend; modules extend it without
running as separate services or containers.

## Module tiers

- **Tier 1 — config-driven CRUD.** A `crud` block in `manifest.yaml` declares a table
  and its fields; Core serves a generic REST API and a built-in fallback UI directly —
  no handler code, no `ui/bundle.js`, no Deno worker at all. See "Tier 1: config-driven
  CRUD" below.
- **Tier 2 — custom logic.** A TypeScript handler (`handlers/index.ts`) running inside
  a sandboxed Deno Worker.
- **Tier 3 — external integrations.** Like tier 2, but additionally declares an
  `egress_allowlist` for outbound connections (e.g. UniFi RADIUS, Cloudflare).

## Security model

**Handler code (tier 2/3)** runs in its own Deno Worker process, one per installed
module, communicating with Core over a Unix-domain socket (a JSON object per line).
Deno flags actually enforced:

- `--allow-net` restricted to hosts in `egress_allowlist` (tier 3), plus Core's own DB
  host and DNS resolver (not module-controlled)
- `--allow-read`/`--allow-write` restricted to the module's own storage directory
- `--cached-only` enforced — no runtime fetching of dependencies, vendor everything
  with `deno vendor`

Core calls your handler with an already-verified auth context
(`userId`, `userEmail`, `userName`, `roles`) — trust it, nothing else. Database access
is schema-scoped: your handler can only read/write its own `module_{name}` PostgreSQL
schema, via a dedicated role and `search_path`. This is schema-level isolation, **not**
row-level security — RLS is not currently used for module data.

**Per-call resource limits (memory/timeout) are planned, not yet enforced.** A
`resources` block in `manifest.yaml` has no effect today; a handler can currently run
unbounded.

**The module UI is not sandboxed.** There is no iframe and no postMessage RPC — your
UI bundle (`ui/bundle.js`, a React component) is loaded via `Blob-URL dynamic import()`
into the **same JS realm as the host app** and mounted directly. The actual protection
is a short-lived (20 min), module-scoped bearer token passed as a prop
(`ModuleComponentProps.token`) instead of the caller's real session token — a buggy or
compromised UI bundle can only call its own `/v1/modules/{name}/api/*` routes, nothing
else. Your component calls its own API with plain `fetch()`, no RPC layer.

There is currently no required UI component library (`@modulab/ui` does not exist as a
package) — build your UI with whatever you choose, mounted as a normal React component.

**Every `module.zip` must be signed.** Core always verifies a SHA-256 digest
(`module.zip.sha256`) before install. Official modules additionally require a valid
Cosign signature bundle — Core refuses to install an official-source module with no
`cosign_sig_url`. Community/custom modules verify a Cosign signature best-effort (shown
as a badge) if you publish one at the conventional `module.zip.sig` path, but it is not
required to install. See "Packaging & publishing" below.

## Manifest reference

`manifest.yaml` is validated against a versioned JSON Schema, vendored in this repo at
`schema/v1/manifest.schema.json` (source: modulab-manifest-schema, MIT). Run
`scripts/update-schema.sh` to refresh it against a newer schema release. The schema is
kept in sync with Core's actual manifest parser — fields it accepts are fields Core
reads.

Required fields: `name`, `version`, `author`, `license`, `category`, `min_core`, `tier`.

| Field | Notes |
|---|---|
| `name` | Lowercase with hyphens (e.g. `notes`, `unifi-network`); unique within the module store |
| `version` | SemVer |
| `license` | SPDX identifier; unknown values are rejected by registry CI |
| `category` | One of: productivity, finance, network, media, smart-home |
| `min_core` | Core API version, currently `v1` |
| `tier` | 1, 2, or 3 |
| `description` / `display_name` | Map of language code → text, e.g. `{"en": "...", "de": "..."}`. Shown in the Module Store. |
| `logo` | Filename of a logo shipped at the repo root, e.g. `logo.png` |
| `crud` | Tier 1 only, required: `table`, `fields[]`, optional `owner_scoped`. See "Tier 1: config-driven CRUD" below. |
| `handler` | Tier 2/3 only, required: path to the entry handler, e.g. `handlers/index.ts` |
| `egress_allowlist` | Tier 3 only: list of hostnames (strings), enforced by `--allow-net`. Tier 2 must not declare this. |
| `jobs` | Tier 2/3 only: background cron jobs (`name`, `schedule`, `handler`, optional `catch_up`), minute-granularity cron |
| `tls_skip_verify` | Tier 2/3 only: for modules whose runtime destinations are private IPs with no CA cert. Requires a non-empty `egress_allowlist`. |
| `dynamic_egress` / `egress_hosts_handler` | Tier 2/3 only: for modules whose egress hosts are only known at runtime (e.g. admin-configured gateway IPs) rather than fixed in the manifest |
| `resources`, `storage.quota` | **Planned, not yet enforced by Core.** Declaring them today has no effect. |

There is no Core-provided mechanism for declared/typed credentials, module
dependencies, or a pre-install permission-warning list — each module handles its own
external configuration and dependencies itself (e.g. its own settings table in its own
schema, written through its own admin UI).

`source_repo`, `manifest_path`, `release_url` are only used in modulab-community
discovery entries, not in your module's own manifest.

See `schema/v1/manifest.schema.json` for the exact, authoritative shape of every field.

## Tier 1: config-driven CRUD

A Tier 1 module ships `manifest.yaml` and `migrations/001_initial.sql` — nothing else.
No handler, no `ui/bundle.js`. Core serves a generic REST API directly against your
table and renders a built-in list/form UI from your field declarations.

```yaml
crud:
  table: "notes"
  owner_scoped: true
  fields:
    - name: "title"
      type: "string"
      required: true
    - name: "body"
      type: "text"
      encrypted: true
```

- `owner_scoped: true` restricts every row to the user who created it — list, get,
  update, delete all enforce `created_by = <caller>`, strictly, with no exception for
  any role, not even admins. Leave it `false` (default) for shared data every user of
  the module can see and edit.
- `encrypted: true` (string/text fields only) stores the value AES-256-GCM encrypted at
  rest and transparently decrypts it on read. Encrypted fields cannot be filtered or
  searched server-side.

**The table is not auto-generated.** Your migration must create it with your declared
fields plus the columns Core itself manages:

```sql
CREATE TABLE notes (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by TEXT        NOT NULL, -- only needed when owner_scoped: true
    title      TEXT        NOT NULL,
    body       TEXT        NOT NULL DEFAULT '' -- encrypted: true still stores as text
);
```

At install/update, Core cross-checks this table against your `crud` declaration
(column-by-column, by name and type) and rejects the install with a clear error on any
mismatch — rather than surfacing an opaque SQL error the first time someone calls the
API.

**Generated API**, mounted at `/v1/modules/{name}/api/{table}` (same base path and
module-scoped-token auth as a tier 2/3 module's own API):

- `GET /{table}?page=&page_size=` — list, newest first. `page_size` defaults to 50,
  capped at 200.
- `POST /{table}` — create. `id`/`created_at`/`updated_at`/`created_by` are always
  server-set, never accepted from the request body.
- `PATCH /{table}/{id}` — update. `owner_scoped` modules 403 unless you created the row.
- `DELETE /{table}/{id}` — same ownership check as `PATCH`.

Field values are validated server-side against their declared type — a request that
doesn't match gets a 400, not a raw SQL error.

**Generated UI**: Core's built-in `CrudModuleView` renders a list (one column per
declared field) and an add/edit form (one input per field, mapped by type — text,
textarea, number, checkbox, date/datetime picker). You write none of it.

**Field labels**: by default, column/form labels are the raw field name from
`crud.fields[].name`. To localize them, ship the same `locales/{lng}.json` files
tier 2/3 modules use (see "Handler API" and "Vendoring dependencies" below — not
handler-related here, just the locale files) with one `field_{name}` key per
field, e.g. `{"field_title": "Titel", "field_body": "Text"}` in `locales/de.json`.
Core serves these at `GET /v1/modules/{name}/locales/{lng}.json` regardless of
tier, and `CrudModuleView` looks up `field_{name}` there, falling back to the
raw field name if the key or the whole file is absent.

## Handler API (tier 2/3)

Copy `handlers/index.ts.example` to `handlers/index.ts` and implement your logic there.
Core passes a typed request into your default-exported handler function:

- `ModuleAuthContext` — `userId`, `userEmail`, `userName`, `roles`. Already verified by
  Core; trust it.
- `HandlerRequest` — `method`, `path`, `body`, `auth`, `db` (`ModuleDbClient`, scoped to
  your own `module_{name}` schema).
- `HandlerResponse` — `status`, `body`.

## Database

Write `migrations/001_initial.sql`. On install, Core provisions your schema
(`module_{name}`) and a dedicated role, then runs your migration files in
lexicographic order inside a single transaction. On update, only new migration files
(tracked by filename) are applied.

## UI

Tier 1 modules get a generated UI for free — see "Tier 1: config-driven CRUD" above,
you write nothing.

Tier 2/3 modules ship `ui/bundle.js`, a React component loaded directly into the host
app (no iframe, see "Security model" above). It receives `ModuleComponentProps`
(`moduleName`, `apiBase`, `token`, optional `initialQuery`) and is responsible for its
own data fetching against `apiBase` using `token` as a bearer token.

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

Package everything into `module.zip`, plus a `module.zip.sha256` (a plain SHA-256
digest file, e.g. the output of `sha256sum module.zip`) — Core always verifies this,
regardless of source.

- **Official modules** — open a pull request against modulab-modules. Signing (Cosign)
  is handled by that repo's own release pipeline; Core refuses to install an official
  module without a valid signature.
- **Community modules** — keep your own repository, attach `module.zip` and
  `module.zip.sha256` to a GitHub Release, and submit a discovery entry (with
  `release_url`) via pull request to modulab-community. Signing is optional but
  recommended: generate a key pair with `cosign generate-key-pair`, sign with
  `cosign sign-blob --bundle module.zip.sig module.zip`, and publish the bundle
  alongside the release at that conventional path — Core verifies it best-effort and
  shows a verified badge in the Store.

## Related repositories

- **modulab-core** — the Core backend and frontend that runs modules.
- **modulab-manifest-schema** — versioned source of the JSON Schema vendored here.
- **modulab-modules** — official modules.
- **modulab-community** — community module discovery index.

## License

AGPLv3, see LICENSE. A finished module can be published under its own license (`license`
field in the manifest); this SDK template itself is AGPLv3.
