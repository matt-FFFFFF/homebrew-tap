#!/usr/bin/env bash
# Regenerate the FORMULAE section of README.md from Formula/*.rb and Casks/*.rb.
set -euo pipefail

README="README.md"
START_MARKER="<!-- FORMULAE:START -->"
END_MARKER="<!-- FORMULAE:END -->"

# Extract the first `key "value"` or `key 'value'` pair from a Ruby file.
extract() {
  local file="$1" key="$2"
  python3 - "$file" "$key" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        m = re.match(rf'\s*{re.escape(key)}\s+["\'](.+?)["\']\s*$', line)
        if m:
            print(m.group(1))
            break
PY
}

render_rows() {
  local dir="$1" kind="$2"
  [[ -d "$dir" ]] || return 0
  shopt -s nullglob
  for f in "$dir"/*.rb; do
    local name desc homepage version
    name=$(basename "$f" .rb)
    desc=$(extract "$f" desc)
    homepage=$(extract "$f" homepage)
    version=$(extract "$f" version)
    if [[ -z "$version" ]]; then
      version=$(grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' "$f" | head -1 || true)
    fi
    local display="$name"
    [[ -n "$homepage" ]] && display="[$name]($homepage)"
    printf '| %s | %s | %s | %s |\n' "$display" "${desc:-—}" "${version:-—}" "$kind"
  done
}

build_section() {
  local rows
  rows=$({
    render_rows "Formula" "formula"
    render_rows "Casks"   "cask"
  })

  {
    printf '%s\n' "$START_MARKER"
    printf '%s\n' "<!-- This section is auto-generated. Do not edit manually. -->"
    if [[ -z "$rows" ]]; then
      printf '%s\n' "_No formulae yet._"
    else
      printf '\n'
      printf '| Name | Description | Version | Type |\n'
      printf '| ---- | ----------- | ------- | ---- |\n'
      printf '%s\n' "$rows"
    fi
    printf '%s\n' "$END_MARKER"
  }
}

main() {
  [[ -f "$README" ]] || { echo "README.md not found" >&2; exit 1; }
  grep -qF "$START_MARKER" "$README" || { echo "Start marker missing in README.md" >&2; exit 1; }
  grep -qF "$END_MARKER"   "$README" || { echo "End marker missing in README.md"   >&2; exit 1; }

  local new_section
  new_section=$(build_section)

  NEW_SECTION="$new_section" \
  START="$START_MARKER" \
  END="$END_MARKER" \
  README_PATH="$README" \
  python3 <<'PY'
import os, re
readme = os.environ["README_PATH"]
start = os.environ["START"]
end = os.environ["END"]
new = os.environ["NEW_SECTION"].rstrip("\n")
with open(readme, "r", encoding="utf-8") as f:
    content = f.read()
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.DOTALL)
if not pattern.search(content):
    raise SystemExit("Markers not found in README")
updated = pattern.sub(lambda _: new, content, count=1)
with open(readme, "w", encoding="utf-8") as f:
    f.write(updated)
PY
}

main "$@"
