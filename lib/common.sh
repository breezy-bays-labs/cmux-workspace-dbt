# lib/common.sh — sourced by every cwd bin script.
# shellcheck shell=sh
#
# Resolves the THREE independent config axes and the per-workspace
# ($CMUX_WORKSPACE_ID) state directory, and provides shared cmux / warehouse
# helpers. It does NOT set shell options — the caller owns `set -eu`.
#
#   AXIS 1  machine profile (bare|stow)  — config regime only; profiles/*.env
#   AXIS 2  dbt project (per workspace)  — dbt_dir; auto-derives the warehouse
#   AXIS 3  data / policy                — WAREHOUSE, HARLEQUIN, DBT_PROFILES_DIR;
#                                          resolved here from env + per-workspace
#                                          state + the dbt project's profiles.yml,
#                                          INDEPENDENT of the machine profile
#
# Containment: every surface/widget/opener in a dbt workspace derives its OWN
# workspace from the environment ($CMUX_WORKSPACE_ID, auto-set by cmux in every
# terminal), NOT from a single global state file — so N worktree-workspaces
# coexist without collision. Override with DBT_WS_WORKSPACE for solo testing from
# a non-cmux shell.

: "${DBT_WS_HOME:?lib/common.sh: DBT_WS_HOME must be set before sourcing}"

# --- AXIS 1: machine profile (config regime only) ----------------------------
DBT_WS_PROFILE="${DBT_WS_PROFILE:-bare}"
_cwd_prof="$DBT_WS_HOME/profiles/${DBT_WS_PROFILE}.env"
if [ ! -f "$_cwd_prof" ]; then
  echo "cwd: unknown profile '$DBT_WS_PROFILE' (no $_cwd_prof)" >&2
  exit 2
fi
# shellcheck source=/dev/null
. "$_cwd_prof"

DBT_WS_STATE="${DBT_WS_STATE:-$DBT_WS_HOME/state}"

# --- workspace containment ---------------------------------------------------
ws_ref() { printf '%s' "${DBT_WS_WORKSPACE:-${CMUX_WORKSPACE_ID:-}}"; }     # raw id for cmux --workspace
ws_key() { ws_ref | tr ':/ ' '___'; }                                       # filesystem-safe key

ws_dir() {                                                                  # per-workspace state dir (mkdir)
  _k="$(ws_key)"
  if [ -z "$_k" ]; then
    echo "cwd: no workspace (set CMUX_WORKSPACE_ID or DBT_WS_WORKSPACE)" >&2
    return 1
  fi
  _d="$DBT_WS_STATE/$_k"
  mkdir -p "$_d"
  printf '%s' "$_d"
}

state_get() {                                                               # state_get <key> [default]
  _k="$(ws_key)"
  if [ -n "$_k" ] && [ -f "$DBT_WS_STATE/$_k/$1" ]; then
    cat "$DBT_WS_STATE/$_k/$1"
  else
    printf '%s' "${2:-}"
  fi
}

state_set() {                                                               # state_set <key> <value>
  _d="$(ws_dir)" || return 1
  printf '%s\n' "$2" > "$_d/$1"
}

# --- helpers (paths) ---------------------------------------------------------
# yazi's DDS socket lives under the per-user macOS temp dir, NOT an agent sandbox $TMPDIR.
darwin_tmp()  { getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}"; }
dbt_dir()     { state_get dbt_dir "${DBT_WS_DBT_DIR_DEFAULT:-$PWD}"; }
yazi_id()     { state_get yazi_client_id "${DBT_WS_YAZI_ID_DEFAULT:-1717}"; }
# Workspace TYPE (per-workspace): `dbt` only when the launcher (`cwd register dbt`)
# wrote the marker; otherwise `general` — NO heuristic, a general ws is simply one
# `cwd new` never created. The type-gated behaviors (S6) treat absent == general.
ws_type()     { state_get ws_type general; }
# duckdb path: per-workspace state, then the warehouse auto-derive (below), then
# the machine-local default.
duckdb_path() { state_get duckdb "${DBT_DERIVED_DUCKDB:-${DBT_WS_DUCKDB_DEFAULT:-}}"; }

# --- AXIS 2 -> AXIS 3: warehouse auto-derive (pure read of the dbt config) ----
# Parse the workspace's dbt_project.yml `profile:` + the active target's `type:`
# (and duckdb `path:`) in $DBT_PROFILES_DIR/profiles.yml. Hand-rolled awk — no
# yq/python assumed on a clean Mac. The dbt profiles.yml layout is rigid (profile
# at indent 0, target/outputs at 2, output names at 4, fields at 6), so this
# 2-space-indent parse is sufficient. profiles.yml is READ ONLY, never written.
# Degrades to warehouse=none on any missing/unreadable file or target.

# strip surrounding quotes + leading/trailing whitespace from a scalar
_unquote() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

# value of a top-level (indent-0) `key:` in a YAML file
_yaml_root() {  # <file> <key>
  [ -f "$1" ] || return 0
  _unquote "$(awk -v k="$2" '
    $0 ~ "^"k":" { sub("^"k":[[:space:]]*",""); sub(/[[:space:]]*#.*$/,""); print; exit }
  ' "$1")"
}

# `target:` (indent 2) inside a top-level profile block
_yaml_target() {  # <profiles.yml> <profile>
  [ -f "$1" ] || return 0
  _unquote "$(awk -v p="$2" '
    $0 ~ "^"p":" { inp=1; next }
    /^[^[:space:]]/ { inp=0 }
    inp && /^[[:space:]][[:space:]]target:[[:space:]]*/ {
      sub(/^[[:space:]]*target:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); print; exit
    }
  ' "$1")"
}

# `type:` / `path:` (indent 6) inside outputs.<target> of a profile block
_yaml_output_field() {  # <profiles.yml> <profile> <target> <field>
  [ -f "$1" ] || return 0
  _unquote "$(awk -v p="$2" -v t="$3" -v f="$4" '
    $0 ~ "^"p":" { inp=1; next }
    /^[^[:space:]]/ { inp=0; ino=0; intgt=0 }
    inp && /^[[:space:]][[:space:]]outputs:[[:space:]]*$/ { ino=1; next }
    inp && ino && /^[[:space:]][[:space:]][^[:space:]]/ { ino=0 }
    ino && $0 ~ "^[[:space:]][[:space:]][[:space:]][[:space:]]"t":[[:space:]]*$" { intgt=1; next }
    ino && intgt && /^[[:space:]][[:space:]][[:space:]][[:space:]][^[:space:]]/ { intgt=0 }
    intgt && $0 ~ "^[[:space:]]+"f":[[:space:]]" {
      sub("^[[:space:]]*"f":[[:space:]]*",""); sub(/[[:space:]]*#.*$/,""); print; exit
    }
  ' "$1")"
}

# resolve the active dbt target -> sets DBT_DERIVED_WAREHOUSE + DBT_DERIVED_DUCKDB
derive_dbt_target() {
  DBT_DERIVED_WAREHOUSE="none"; DBT_DERIVED_DUCKDB=""
  _proj="$(dbt_dir)/dbt_project.yml"
  _pyml="$DBT_PROFILES_DIR/profiles.yml"
  [ -f "$_proj" ] && [ -f "$_pyml" ] || return 0
  _prof="$(_yaml_root "$_proj" profile)"; [ -n "$_prof" ] || return 0
  _tgt="${DBT_TARGET:-$(_yaml_target "$_pyml" "$_prof")}"; [ -n "$_tgt" ] || return 0
  case "$(_yaml_output_field "$_pyml" "$_prof" "$_tgt" type)" in
    duckdb)
      DBT_DERIVED_WAREHOUSE="duckdb"
      _p="$(_yaml_output_field "$_pyml" "$_prof" "$_tgt" path)"
      case "$_p" in
        \~/*)         _p="$HOME/${_p#\~/}" ;;   # home-relative
        /*|"")        : ;;                      # absolute or empty — leave as-is
        :memory:|*:*) : ;;                      # :memory: / md: / motherduck: — a DuckDB sentinel or URI, not a filesystem path
        *)            _p="$(dbt_dir)/$_p" ;;    # relative -> resolve vs. the project dir
      esac
      DBT_DERIVED_DUCKDB="$_p"
      ;;
    snowflake) DBT_DERIVED_WAREHOUSE="snowflake" ;;
    *)         DBT_DERIVED_WAREHOUSE="none" ;;
  esac
}

# --- AXIS 3: data / policy (independent of the machine profile) --------------
# Resolved from env first, then per-workspace state, then the warehouse
# auto-derive, with locked-down defaults. A profile NEVER sets these — so a
# `bare` machine can run harlequin=on and a `stow` machine harlequin=off.
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"   # set before the derive reads it
DBT_DERIVED_WAREHOUSE="none"; DBT_DERIVED_DUCKDB=""
WAREHOUSE="${WAREHOUSE:-$(state_get warehouse "")}"
if [ -z "$WAREHOUSE" ]; then
  derive_dbt_target                                   # sets DBT_DERIVED_WAREHOUSE/_DUCKDB
  WAREHOUSE="$DBT_DERIVED_WAREHOUSE"
fi
WAREHOUSE="${WAREHOUSE:-none}"
HARLEQUIN="${HARLEQUIN:-$(state_get harlequin off)}"

# Warehouse-access gate (RUNTIME): is the interactive warehouse-query channel
# (harlequin read-only DuckDB preview) allowed in THIS workspace? Keyed on the
# data axis, NOT the machine profile. Defense-in-depth: on a `bare` install the
# hq-preview symlink is structurally absent regardless of this answer.
hq_enabled() { [ "${HARLEQUIN:-off}" = "on" ] && [ "${WAREHOUSE:-none}" = "duckdb" ]; }

# SQL_QUERY_MODE is DERIVED from the gate (harlequin when enabled, else external),
# never an independent input — so it is always set (no unbound-variable break in
# the consumers: bin/hq-preview, bin/cwd doctor, bin/cwd-focus).
if hq_enabled; then SQL_QUERY_MODE="harlequin"; else SQL_QUERY_MODE="external"; fi

export DBT_WS_HOME DBT_WS_PROFILE DBT_WS_STATE DBT_WS_BIN DBT_WS_XDG \
       WAREHOUSE HARLEQUIN SQL_QUERY_MODE DBT_PROFILES_DIR \
       SHELL_KIND CONFIG_REGIME PROMPT_GLYPH YAZI_CONFIG_VARIANT
