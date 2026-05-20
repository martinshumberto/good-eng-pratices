#!/bin/bash
# Sincroniza docs locais com Outline self-hosted.
# Cada arquivo .md (exceto README.md) vira um doc filho da doc-pasta correspondente.
set -eo pipefail

OUTLINE_URL="https://wiki.carewebs.com/api"
OUTLINE_KEY="${OUTLINE_API_KEY:?defina OUTLINE_API_KEY no env}"
COLLECTION_ID="1036b8a9-8627-45b8-a222-e54732c495fc"
DOCS_ROOT="$(cd "$(dirname "$0")/.." && pwd)/docs"

# Pares "pasta_local|outline_parent_id" (arrays paralelos para compatibilidade Bash 3.x)
PAIRS=(
  "architecture|bf65ed9e-6af6-4039-bc46-bd6a8ccbf3e6"
  "design-patterns|7fde19f2-7919-42b0-8310-3f776de4e3a7"
  "backend|799c0319-f11a-44c5-bbb7-ec30a47b9d9a"
  "data|974cfd12-a6d5-433b-b014-061289d17919"
  "frontend|b653b360-e8f1-437c-ae6d-c17add01571f"
  "testing|7b2a0a25-c01c-44b6-aedb-451f9e7d0e73"
  "observability|323518fc-b66e-4b35-b421-6f91a9d3d382"
  "security|4b77eb0c-992b-4b6a-9c81-ccfe33ac9780"
  "delivery|0dcda81f-69cc-41a3-ab6b-cf9b31ed8ee7"
  "collaboration|4c2e3cb7-af94-4898-b201-73a4e1da98a1"
)

create_doc() {
  local file_path="$1"
  local parent_id="$2"

  local title
  title=$(head -1 "$file_path" | sed 's/^# //')

  local text
  text=$(tail -n +3 "$file_path")

  local body
  body=$(jq -n \
    --arg title "$title" \
    --arg text "$text" \
    --arg collId "$COLLECTION_ID" \
    --arg parentId "$parent_id" \
    '{title: $title, text: $text, collectionId: $collId, parentDocumentId: $parentId, publish: true}')

  local resp
  resp=$(curl -sS -X POST "$OUTLINE_URL/documents.create" \
    -H "Authorization: Bearer $OUTLINE_KEY" \
    -H "Content-Type: application/json" \
    -d "$body")

  local id url
  id=$(echo "$resp" | jq -r '.data.id // empty')
  url=$(echo "$resp" | jq -r '.data.url // empty')

  if [ -z "$id" ]; then
    echo "  ❌ $file_path → $(echo "$resp" | jq -c '.error // .')"
    return 1
  fi
  echo "  ✓ $(basename "$file_path") → $url"
}

for pair in "${PAIRS[@]}"; do
  folder="${pair%%|*}"
  parent="${pair##*|}"
  echo "=== $folder (parent: $parent) ==="
  for f in "$DOCS_ROOT/$folder"/*.md; do
    [ "$(basename "$f")" = "README.md" ] && continue
    create_doc "$f" "$parent"
  done
done

echo "Done."
