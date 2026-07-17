# modulab-module-sdk

Starter kit for developing your own ModuLab (https://modulab.app) modules — the single
place to find everything you need: architecture, security model, manifest reference,
handler API, and the publishing workflow.

**Start with [GUIDE.md](GUIDE.md).**

## Contents

- `GUIDE.md` — the full module development guide (start here).
- `manifest.example.yaml` — an annotated example manifest.yaml covering all fields
  across all tiers.
- `handlers/index.ts.example` — a tier 2/3 handler template showing the typed request,
  auth and database client interfaces Core passes into your handler.
- `schema/v1/manifest.schema.json` — vendored copy of the manifest JSON Schema
  (source: modulab-manifest-schema). Refresh with `scripts/update-schema.sh`.
- `scripts/validate-manifest.sh` — validates a manifest.yaml locally against the
  vendored schema.
- `scripts/update-schema.sh` — refreshes the vendored schema copy.

## Quick start

1. Copy `manifest.example.yaml` to `manifest.yaml`, set `tier` and fill in the fields
   relevant to your tier.
2. Tier 1: add a `crud` block, no code needed. Tier 2/3: copy
   `handlers/index.ts.example` to `handlers/index.ts` and implement your logic.
3. Write `migrations/001_initial.sql` (runs against your module's own `module_{name}`
   PostgreSQL schema).
4. Build your UI with `@modulab/ui` only, or skip it for tier 1 to use Core's generated
   CRUD view.
5. Vendor external packages with `deno vendor` into `vendor/` — Core runs handlers with
   `--cached-only`.
6. Validate: `./scripts/validate-manifest.sh manifest.yaml`.
7. Package into `module.zip` and attach it to a GitHub Release.

See [GUIDE.md](GUIDE.md) for the full explanation of every step above, including the
security model modules run under and the publishing workflow (official vs. community).

## License

AGPLv3, see LICENSE. A finished module can be published under its own license (SPDX
`license` field in the manifest); this SDK template itself is AGPLv3.
