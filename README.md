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
- `ui-template/` — a tier 2/3 frontend starting point (Vite + host-shims). Copy this into
  your module's `ui/` directory rather than starting a UI build from scratch — it wires
  up the required `window.__MODULAB_HOST__` aliasing (see GUIDE.md's "UI" section for why
  this is mandatory, not optional).
- `schema/v1/manifest.schema.json` — vendored copy of the manifest JSON Schema
  (source: modulab-manifest-schema). Refresh with `scripts/update-schema.sh`.
- `scripts/validate-manifest.sh` — validates a manifest.yaml locally against the
  vendored schema.
- `scripts/update-schema.sh` — refreshes the vendored schema copy.

## Quick start

1. Copy `manifest.example.yaml` to `manifest.yaml`, set `tier` (currently 2 or 3 — tier
   1 is planned, not yet implemented) and fill in the fields relevant to your module.
2. Copy `handlers/index.ts.example` to `handlers/index.ts` and implement your logic.
3. Write `migrations/001_initial.sql` (runs against your module's own `module_{name}`
   PostgreSQL schema).
4. Copy `ui-template/` to `ui/` and build your UI from `src/App.example.tsx` (rename it
   to `App.tsx`) — no required component library beyond what's already wired up. Keep the
   `vite.config.ts` aliasing as-is; it's what makes your component share Core's own React
   instance instead of shipping a conflicting copy (see GUIDE.md's "UI" section).
5. Vendor external packages with `deno vendor` into `vendor/` — Core runs handlers with
   `--cached-only`.
6. Validate: `./scripts/validate-manifest.sh manifest.yaml`.
7. Package into `module.zip`, generate `module.zip.sha256`, and attach both to a GitHub
   Release (Core always verifies the SHA-256; see GUIDE.md for the Cosign signing step).

See [GUIDE.md](GUIDE.md) for the full explanation of every step above, including the
real security model modules run under and the publishing workflow (official vs.
community).

## License

AGPLv3, see LICENSE. A finished module can be published under its own license (SPDX
`license` field in the manifest); this SDK template itself is AGPLv3.
