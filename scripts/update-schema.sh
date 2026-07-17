#!/usr/bin/env bash
# Updates the vendored copy of manifest.schema.json from modulab-manifest-schema.
# The schema is vendored (not fetched at runtime) per modulab-manifest-schema's
# offline-first policy. Re-run this after a schema release to pick up changes.

set -euo pipefail

SCHEMA_VERSION="${1:-v1}"
RAW_URL="https://raw.githubusercontent.com/modulab-project/modulab-manifest-schema/main/${SCHEMA_VERSION}/manifest.schema.json"
DEST="schema/${SCHEMA_VERSION}/manifest.schema.json"

mkdir -p "schema/${SCHEMA_VERSION}"
curl -fsSL "$RAW_URL" -o "$DEST"

echo "Updated: $DEST"
