#!/bin/bash
# cka-sim/lib/fileblock.sh — idempotent sentinel-fenced block writer
#
# Used by bootstrap to manage ~/.bashrc and ~/.ssh/config edits without ever
# duplicating entries, even across many bootstrap re-runs.
#
# Contract:
#   cka_sim::fileblock::write <file> <begin-marker> <end-marker> <content>
#   - Creates <file> if absent.
#   - Removes any existing <begin-marker>...<end-marker> block.
#   - Appends a fresh block with <content>.
#   - <content> is raw text; may contain newlines.

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

cka_sim::fileblock::write() {
  local file="$1"
  local begin_marker="$2"
  local end_marker="$3"
  local content="$4"

  [[ -n "$file" ]] || { printf 'fileblock::write: missing file arg\n' >&2; return 1; }
  [[ -n "$begin_marker" ]] || { printf 'fileblock::write: missing begin_marker\n' >&2; return 1; }
  [[ -n "$end_marker" ]] || { printf 'fileblock::write: missing end_marker\n' >&2; return 1; }

  # Create file if missing (with parent dir) and ensure it ends in a newline.
  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : > "$file"
  if [[ -s "$file" ]] && [[ "$(tail -c 1 "$file")" != $'\n' ]]; then
    printf '\n' >> "$file"
  fi

  # Strip any existing block between markers (fixed-string match, any position).
  if grep -qF "$begin_marker" "$file"; then
    # Use sed to remove the block inclusive of both markers.
    # Note: this relies on both markers appearing once as whole lines.
    local tmp
    tmp="$(mktemp)"
    # Escape forward-slash and ampersand in markers for sed address.
    local esc_begin esc_end
    esc_begin="$(printf '%s' "$begin_marker" | sed -e 's/[\/&]/\\&/g')"
    esc_end="$(printf '%s' "$end_marker"   | sed -e 's/[\/&]/\\&/g')"
    sed "/$esc_begin/,/$esc_end/d" "$file" > "$tmp"
    mv "$tmp" "$file"
  fi

  # Append a fresh block.
  {
    printf '%s\n' "$begin_marker"
    printf '%s\n' "$content"
    printf '%s\n' "$end_marker"
  } >> "$file"
}
