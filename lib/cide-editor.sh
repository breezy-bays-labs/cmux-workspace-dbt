# cide-editor.sh — shared IDE-instance state for cide: editor-target resolution,
# a small registry, and self-healing regeneration of role-workspaces.
# shellcheck shell=sh
# Sourced by bin/cide-open, bin/cide-md-open, bin/cide-set-editor, bin/cide-regen.
# Requires DBT_WS_HOME set before sourcing (callers do this).
#
# Design (see .claude/architecture-direction.md → IDE INSTANCE IDENTITY): an IDE
# instance is a NAMED, coupled set of cmux workspaces (one per role). Coupling is
# functional — a registry (source of truth) + a workspace `description` tag
# (cide:instance=<name>;role=<role>, rebuild fallback). Closing a role-window no
# longer breaks routing: the next trigger self-heals (regenerate + recouple), and
# `cide-regen` lets the human do it on demand. THIS SLICE wires ONE recipe: the
# editor/portrait role (a trivial `hx-wrap` launch). tools/landscape regen needs
# layout-as-data (#21) and is intentionally NOT wired yet.

CIDE_STATE="${CIDE_STATE:-$HOME/.local/state/cide}"
CIDE_EDITOR_TARGET="$CIDE_STATE/editor_target"   # "<ws-ref> <pane-ref> <surface-ref>"
CIDE_REGISTRY="$CIDE_STATE/registry"             # lines: instance|role|ws|pane|sf|win

# absolute path for a file arg (shared)
_abs() { _d=$(dirname -- "$1"); _b=$(basename -- "$1"); (cd -- "$_d" 2>/dev/null && printf '%s/%s' "$(pwd)" "$_b") || printf '%s' "$1"; }

# --- TOML reader (generic [section] key -> value; minimal, matches common.sh style)
cide_toml_file_get() {  # <file> <section> <key>
  [ -f "$1" ] || return 0
  awk -v s="$2" -v k="$3" '
    /^[[:space:]]*\[/ { ins = ($0 ~ "^[[:space:]]*\\["s"\\][[:space:]]*$"); next }
    ins && $0 ~ "^[[:space:]]*"k"[[:space:]]*=" {
      sub("^[[:space:]]*"k"[[:space:]]*=[[:space:]]*",""); sub(/[[:space:]]*#.*$/,""); print; exit
    }
  ' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}
cide_toml_get() { cide_toml_file_get "$DBT_WS_HOME/cide.toml" "$1" "$2"; }  # cide.toml convenience

cide_ide_name() { _n="$(cide_toml_get ide name)"; if [ -n "$_n" ]; then printf '%s' "$_n"; else basename "$DBT_WS_HOME"; fi; }

# --- registry (sh-simple; pipe-delimited; one row per instance+role) ----------
cide_registry_log() {  # instance role ws pane sf win
  mkdir -p "$CIDE_STATE"
  if [ -f "$CIDE_REGISTRY" ]; then
    grep -v "^$1|$2|" "$CIDE_REGISTRY" > "$CIDE_REGISTRY.tmp" 2>/dev/null || true
    mv "$CIDE_REGISTRY.tmp" "$CIDE_REGISTRY" 2>/dev/null || true
  fi
  printf '%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$CIDE_REGISTRY"
}

cide_registry_get() {  # instance role -> "ws pane sf win" (nonzero if absent)
  [ -f "$CIDE_REGISTRY" ] || return 1
  _row="$(awk -F'|' -v i="$1" -v r="$2" '$1==i && $2==r {print $3, $4, $5, $6; exit}' "$CIDE_REGISTRY")"
  [ -n "$_row" ] && printf '%s' "$_row"
}

cide_registry_role_of_ws() {  # instance ws -> role (nonzero if not found)
  [ -f "$CIDE_REGISTRY" ] || return 1
  _r="$(awk -F'|' -v i="$1" -v w="$2" '$1==i && $3==w {print $2; exit}' "$CIDE_REGISTRY")"
  [ -n "$_r" ] && printf '%s' "$_r"
}

# window ref of a workspace (refs are derived live — stored win can go stale).
cide_ws_window() { [ -n "${1:-}" ] || return 1; cmux tree --workspace "$1" 2>/dev/null | grep -oE 'window:[0-9]+' | head -1; }

# --- editor target load / liveness -------------------------------------------
cide_editor_load() {
  [ -f "$CIDE_EDITOR_TARGET" ] || return 1
  read -r EDITOR_WS EDITOR_PANE EDITOR_SF < "$CIDE_EDITOR_TARGET" || return 1
  [ -n "${EDITOR_WS:-}" ] && [ -n "${EDITOR_SF:-}" ]
}

# Live iff the workspace exists, still contains the surface, AND still carries our
# editor tag (the tag check defends against cmux reusing a ref after a close).
cide_editor_alive() {
  [ -n "${EDITOR_WS:-}" ] && [ -n "${EDITOR_SF:-}" ] || return 1
  _t="$(cmux --json tree --workspace "$EDITOR_WS" 2>/dev/null)" || return 1
  printf '%s' "$_t" | grep -qF "$EDITOR_SF" || return 1
  printf '%s' "$_t" | grep -q 'role=editor' || return 1
}

cide_editor_window() { [ -n "${EDITOR_WS:-}" ] || return 1; cmux tree --workspace "$EDITOR_WS" 2>/dev/null | grep -oE 'window:[0-9]+' | head -1; }
cide_editor_clear()  { rm -f "$CIDE_EDITOR_TARGET" 2>/dev/null || true; }

cide_editor_warn() {
  _m="cide: no live editor — the editor window may be closed. It self-heals on the next open, or run 'cide-regen editor'."
  cmux notify --title "cide editor not found" --body "$_m" >/dev/null 2>&1 || true
  printf '%s\n' "$_m" >&2
}

# --- window orientation (portrait vs landscape) via the container frame --------
# cmux exposes a per-window container_frame {width,height} in `list-panes --json`.
# width < height => portrait monitor; otherwise landscape. This is what lets
# on_missing_window=reuse place the editor on the RIGHT monitor.
cide_window_orientation() {  # <window-ref> -> portrait|landscape (nonzero on failure)
  _j="$(cmux --json list-panes --window "$1" 2>/dev/null)" || return 1
  _h="$(printf '%s' "$_j" | grep -oE '"height"[[:space:]]*:[[:space:]]*[0-9.]+' | head -1 | grep -oE '[0-9.]+' | head -1)"
  _w="$(printf '%s' "$_j" | grep -oE '"width"[[:space:]]*:[[:space:]]*[0-9.]+'  | head -1 | grep -oE '[0-9.]+' | head -1)"
  [ -n "$_w" ] && [ -n "$_h" ] || return 1
  awk -v w="$_w" -v h="$_h" 'BEGIN{ print (w+0 < h+0) ? "portrait" : "landscape" }'
}

# First existing window matching an orientation (lowest window:N first), else nonzero.
cide_find_window() {  # <orientation>
  for _w in $(cmux tree --all 2>/dev/null | grep -oE 'window:[0-9]+' | sort -t: -k2 -n -u); do
    [ "$(cide_window_orientation "$_w" 2>/dev/null)" = "$1" ] && { printf '%s' "$_w"; return 0; }
  done
  return 1
}

# "ws pane sf" of a window's SELECTED workspace (resolves what we just created with --focus).
cide_window_selected_refs() {  # <window-ref>
  _j="$(cmux --json list-panes --window "$1" 2>/dev/null)" || return 1
  _ws="$(printf '%s' "$_j" | grep -oE 'workspace:[0-9]+' | head -1)"
  _pn="$(printf '%s' "$_j" | grep -oE 'pane:[0-9]+' | head -1)"
  _sf="$(printf '%s' "$_j" | grep -oE 'surface:[0-9]+' | head -1)"
  [ -n "$_ws" ] && [ -n "$_sf" ] && printf '%s %s %s' "$_ws" "${_pn:-pane:0}" "$_sf"
}

# --- regeneration: ONE wired recipe (editor/portrait role) -------------------
# Launches the portrait editor (helix) with the given file(s), tags + registers it, and
# sets EDITOR_WS/PANE/SF + editor_target. Placement per on_missing_window:
#   reuse -> open the editor workspace IN an existing portrait window (right monitor; no drag)
#   new   -> create a fresh window (lands on the main monitor; drag once)
# Returns 1 on failure. (tools/landscape recipe still deferred to #21.)
cide_regen_editor() {  # [file...]
  _name="$(cide_ide_name)"
  _omw="$(cide_toml_get ide on_missing_window)"; _omw="${_omw:-reuse}"
  _tag="cide:instance=$_name;role=editor"
  _cmd="hx-wrap"
  for _f in "$@"; do _cmd="$_cmd \"$(_abs "$_f")\""; done

  _win=""; _defws=""
  # editor role -> portrait orientation. Try to reuse an existing portrait window.
  [ "$_omw" = "reuse" ] && _win="$(cide_find_window portrait 2>/dev/null || true)"
  if [ -z "$_win" ]; then
    _out="$(cmux new-window 2>&1)" || return 1          # fresh window (new mode, or reuse found none)
    _win="${_out#OK }"; _win="$(printf '%s' "$_win" | tr -d '[:space:]')"
    [ -n "$_win" ] || return 1
    _defws="$(cmux tree --window "$_win" 2>/dev/null | grep -oE 'workspace:[0-9]+' | head -1)"  # default "Terminal" ws to drop
  fi

  # create the editor workspace (cmux --command handles the post-create send timing).
  cmux new-workspace --window "$_win" --name "$_name" --description "$_tag" --command "$_cmd" --focus true >/dev/null 2>&1 || return 1
  [ -n "$_defws" ] && cmux close-workspace --workspace "$_defws" --window "$_win" >/dev/null 2>&1 || true

  # resolve the new editor = the window's now-selected workspace (works for reuse AND new).
  _refs="$(cide_window_selected_refs "$_win")" || return 1
  EDITOR_WS="${_refs%% *}"; _rest="${_refs#* }"; EDITOR_PANE="${_rest%% *}"; EDITOR_SF="${_rest##* }"
  [ -n "$EDITOR_WS" ] && [ -n "$EDITOR_SF" ] || return 1

  mkdir -p "$CIDE_STATE"
  printf '%s %s %s\n' "$EDITOR_WS" "${EDITOR_PANE:-pane:0}" "$EDITOR_SF" > "$CIDE_EDITOR_TARGET"
  cide_registry_log "$_name" editor "$EDITOR_WS" "${EDITOR_PANE:-}" "$EDITOR_SF" "$_win"
  return 0
}

# --- agent surfaces (claude-only v1) -----------------------------------------
# The agent role is the first SURFACE-grained, multi-instance role, so it does NOT
# use the workspace-grained editor/tools registry. cide composes over cmux's native
# agent machinery instead: cmux hooks capture each session (sessionId/checkpoint,
# surfaceId, lifecycle, updatedAt, launch command incl. our -n label). cide keeps only
# a tiny append-only index of the surfaces IT launched, so the vault can show dead
# sessions with a human label even after cmux's lossy store forgets them.
#   CIDE_AGENTS:      instance|label|surfaceId|cwd|started   (never pruned = history)
#   CIDE_AGENT_STORE: cmux's native claude session store (read-only to us)
CIDE_AGENTS="${CIDE_AGENTS:-$CIDE_STATE/agents}"
CIDE_AGENT_STORE="${CIDE_AGENT_STORE:-$HOME/.cmuxterm/claude-hook-sessions.json}"

# Install cmux's claude agent hooks once (guarded by a marker), so cmux captures each
# claude session (sessionId/checkpoint, surfaceId, transcriptPath). Idempotent + cheap;
# shared by cide-agent (launch) and cide-space open (layout-launched --resume). Without
# hooks cmux can't capture the session, so resume-on-next-open would have nothing to read.
cide_ensure_claude_hooks() {
  _cech_m="$CIDE_STATE/hooks-claude"
  [ -f "$_cech_m" ] && return 0
  mkdir -p "$CIDE_STATE"
  cmux hooks setup --agent claude >/dev/null 2>&1 || true
  : > "$_cech_m"
}

# All LIVE surface UUIDs (uppercased), one per line — used to split active vs dead.
cide_live_uuids() {
  cmux tree --all --id-format uuids 2>/dev/null \
    | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | tr 'a-f' 'A-F' | sort -u
}

# Caller's current surface UUID (the surface a cide-* tool was invoked from).
cide_cur_surface() {
  cmux identify --json --id-format both 2>/dev/null \
    | grep -oiE '"surface_id"[[:space:]]*:[[:space:]]*"[0-9a-f-]{36}"' \
    | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | head -1 | tr 'a-f' 'A-F'
}

# cide label override for a surface UUID (latest row wins); empty if none.
cide_agent_label_of() {  # <surface-uuid>
  [ -f "$CIDE_AGENTS" ] || return 0
  grep -iF "|$1|" "$CIDE_AGENTS" 2>/dev/null | tail -1 | awk -F'|' '{print $2}'
}

# --- IDE spaces: store + active-space scoping --------------------------------
# An IDE *space* is a named, lifecycle-managed container of cmux workspaces that
# cide-space CREATES FRESH from a layout preset (#21) — each space owns its own
# workspaces (disjoint by construction; no overlap with the live IDE). The repo-
# derived instance is the implicit DEFAULT space (empty id), byte-for-byte the
# pre-spaces behavior. cide-space records the store as source of truth, and stamps
# each created workspace's description with a cide:spaces=<id> tag at birth so live
# members resolve without stable UUIDs (refs/UUIDs die across restart).
#   $CIDE_SPACES/<id>/meta     id|name|status|created|layout
#   $CIDE_SPACES/<id>/members  role|ws-uuid|cwd   (the workspaces this space created)
#   $CIDE_SPACES/<id>/history  epoch|event|detail
#   $CIDE_CURRENT_SPACE        the global active-space marker (empty => default)
CIDE_SPACES="${CIDE_SPACES:-$CIDE_STATE/spaces}"
CIDE_CURRENT_SPACE="${CIDE_CURRENT_SPACE:-$CIDE_STATE/current_space}"

# The active space id, or empty for the default (repo) space. A marker pointing at a
# space whose record is gone self-heals to default. Always exits 0 (safe under set -e).
cide_current_space() {
  _csid=""
  [ -f "$CIDE_CURRENT_SPACE" ] && _csid="$(cat "$CIDE_CURRENT_SPACE" 2>/dev/null || true)"
  if [ -n "$_csid" ] && [ -f "$CIDE_SPACES/$_csid/meta" ]; then printf '%s' "$_csid"; fi
  return 0
}

# Member workspace UUIDs (uppercased, one per line) of a space — THE SCOPE BOUNDARY:
# cide features (jump, vault, …) operate only over members. Empty id => the DEFAULT
# space: cwd==repo OR cide:instance=<name> tag, AND NOT carrying any cide:spaces= tag —
# so the default is strictly the baseline IDE, disjoint from every named space (whose
# workspaces also live at cwd==repo). A named id => any workspace whose cide:spaces=<csv>
# token contains that id. Result: default ⟂ named spaces, and named spaces ⟂ each other.
cide_member_workspaces() { cide_space_members "$(cide_current_space)"; }  # back-compat shim (cide-jump's caller)
cide_space_members() {  # [space-id]
  _smid="${1:-}"
  if [ -z "$_smid" ]; then
    _nm="$(cide_ide_name)"
    # Ids of spaces that actually exist on disk. A workspace whose cide:spaces tag points
    # ONLY at removed spaces (stale cruft) is self-healed back into the default scope;
    # only a tag naming a LIVE space excludes it. (No tag => default member, as before.)
    _sp_json="$(if [ -d "$CIDE_SPACES" ]; then for _d in "$CIDE_SPACES"/*/; do [ -f "$_d/meta" ] && cut -d'|' -f1 "$_d/meta"; done; fi | jq -Rn '[inputs]')"
    cmux rpc workspace.list '{}' 2>/dev/null \
      | jq -r --arg repo "$DBT_WS_HOME" --arg nm "$_nm" --argjson spaces "$_sp_json" \
          '(.workspaces // .)[]
             | select(((.current_directory==$repo)
                       or ((.description // "") | test("cide:instance=" + $nm + "(;|$)")))
                      and (((.description // "") | [scan("(^|;)cide:spaces=([^;]*)")] | (.[-1] // [""]) | .[-1]
                            | split(",") | map(select(. != "")) | map(. as $x | ($spaces | index($x))) | all(. == null))))
             | .id' 2>/dev/null \
      | tr 'a-f' 'A-F' | sort -u
  else
    cmux rpc workspace.list '{}' 2>/dev/null \
      | jq -r --arg sid "$_smid" \
          '(.workspaces // .)[]
             | select(((.description // "") | [scan("(^|;)cide:spaces=([^;]*)")] | (.[-1] // [""]) | .[-1]
                       | split(",") | index($sid)) != null)
             | .id' 2>/dev/null \
      | tr 'a-f' 'A-F' | sort -u
  fi
}

# Distinct cwds in scope for a space (vault scoping — catches DEAD sessions by cwd).
# Empty id => the repo (pre-spaces behavior). Named id => unique member cwds.
cide_space_member_cwds() {  # [space-id]
  _scid="${1:-}"
  if [ -z "$_scid" ] || [ ! -s "$CIDE_SPACES/$_scid/members" ]; then
    printf '%s\n' "$DBT_WS_HOME"
  else
    cut -d'|' -f3 "$CIDE_SPACES/$_scid/members" | awk 'NF' | sort -u
  fi
}
