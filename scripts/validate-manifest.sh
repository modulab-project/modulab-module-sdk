#!/usr/bin/env bash
# Validates manifest.yaml against the vendored JSON schema from modulab-manifest-schema.
# Prerequisite: schema/v1/manifest.schema.json is present (vendored, see README).
# Requires npx (Node.js); the ajv-cli and js-yaml packages are fetched on demand via npx.

set -euo pipefail

MANIFEST="${1:-manifest.yaml}"
SCHEMA_VERSION="${2:-v1}"
SCHEMA_FILE="schema/${SCHEMA_VERSION}/manifest.schema.json"

if [ ! -f "$MANIFEST" ]; then
echo "Manifest not found: $MANIFEST" >&2
exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
echo "Schema not found: $SCHEMA_FILE (is modulab-manifest-schema vendored?)" >&2
exit 1
fi

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

npx --yes js-yaml "$MANIFEST" > "$TMP_JSON"
npx --yes ajv-cli validate -s "$SCHEMA_FILE" -d "$TMP_JSON" --strict=false

echo "Valid: $MANIFEST conforms to $SCHEMA_FILE"
