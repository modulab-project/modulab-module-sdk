#!/usr/bin/env bash
# Validates manifest.yaml against the vendored JSON schema (schema/v1/manifest.schema.json,
# vendored from modulab-manifest-schema, see scripts/update-schema.sh).
# Requires npm (Node.js); ajv and js-yaml are installed on demand into a scratch dir.
# Uses Ajv's 2020-12 draft support, since the schema declares
# "$schema": "https://json-schema.org/draft/2020-12/schema" (ajv-cli only supports
# draft-07/draft-2019-09, so it cannot validate this schema directly).

set -euo pipefail

MANIFEST="${1:-manifest.yaml}"
SCHEMA_VERSION="${2:-v1}"
SCHEMA_FILE="schema/${SCHEMA_VERSION}/manifest.schema.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Schema not found: $SCHEMA_FILE (run scripts/update-schema.sh, or is modulab-manifest-schema vendored?)" >&2
  exit 1
fi

TOOL_DIR="$(mktemp -d)"
trap 'rm -rf "$TOOL_DIR"' EXIT

npm install --silent --no-audit --no-fund --prefix "$TOOL_DIR" ajv@8 js-yaml >/dev/null

node -e "
const fs = require('fs');
const path = require('path');
const yaml = require(path.join('$TOOL_DIR', 'node_modules', 'js-yaml'));
const Ajv2020 = require(path.join('$TOOL_DIR', 'node_modules', 'ajv', 'dist', '2020')).default;

const schema = JSON.parse(fs.readFileSync('$SCHEMA_FILE', 'utf8'));
const manifest = yaml.load(fs.readFileSync('$MANIFEST', 'utf8'));

const ajv = new Ajv2020({ strict: false });
const validate = ajv.compile(schema);

if (!validate(manifest)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  process.exit(1);
}

console.log('Valid: $MANIFEST conforms to $SCHEMA_FILE');
"
