#!/usr/bin/env bash
# Install the Genesis migration agents into the user's global Kiro agent dir.
#
# Idempotent: copies ONLY the four genesis-migration-* agent configs and their
# prompts into ~/.kiro/agents (and ~/.kiro/agents/prompts). Running it twice is a
# no-op. It never touches any other agent in that directory (e.g. kirocrew-*),
# and it installs the repo copy of genesis-migration-reviewer.json verbatim (the
# installed copy must stay identical to the repo copy).
#
# Usage:  genesis/agents/install.sh            # installs to ~/.kiro/agents
#         KIRO_AGENTS_DIR=/path install.sh     # override target (tests)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${KIRO_AGENTS_DIR:-$HOME/.kiro/agents}"
PROMPTS="$DEST/prompts"

AGENTS=(
  genesis-migration-extractor
  genesis-migration-writer
  genesis-migration-examiner
  genesis-migration-reviewer
)

mkdir -p "$DEST" "$PROMPTS"

installed=0
for name in "${AGENTS[@]}"; do
  json="$SRC_DIR/$name.json"
  prompt="$SRC_DIR/prompts/$name.md"
  if [[ ! -f "$json" ]]; then
    echo "ERROR: missing agent config: $json" >&2
    exit 1
  fi
  if [[ ! -f "$prompt" ]]; then
    echo "ERROR: missing prompt: $prompt" >&2
    exit 1
  fi
  # cp -f is idempotent (identical bytes on re-run); only the named files are touched.
  cp -f "$json" "$DEST/$name.json"
  cp -f "$prompt" "$PROMPTS/$name.md"
  installed=$((installed + 1))
  echo "installed $name  ->  $DEST/$name.json"
done

echo "done: $installed agent(s) installed into $DEST (other agents untouched)"
