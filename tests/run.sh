#!/bin/sh
# Layer-1 logic tests for cmux-workspace-dbt.
#
# Runs cwd-route / cwd-focus / cwd / install.sh with a STUB cmux (and
# git/duckdb/fd/hunk/ya) on PATH, then asserts the exact commands they would have
# sent. No real cmux, no live workspace, nothing on the machine touched — CI-safe.
# The stubs log every call to $DWS_TEST_LOG; assertions grep that log + stdout.
#
# setup() runs each test in a sandboxed $HOME ($WORK/home) with READ-ONLY
# ~/.config and ~/.dbt, so any stray write fails loudly (the zero-write proof the
# S2/S6/S7 slices build on). The machine profile (AXIS 1) and the data axis
# (AXIS 3) are set INDEPENDENTLY — that orthogonality is what T6a/T8 assert.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export DWS_FIXTURES="$HERE/fixtures"
PASS=0 ; FAIL=0
WORK=""

setup() {
  WORK="$(mktemp -d)"
  # HOME sandbox — install.sh / any config read must never touch the real $HOME.
  # Seed synthetic, READ-ONLY ~/.config + ~/.dbt so a stray write hard-fails.
  export HOME="$WORK/home"
  mkdir -p "$HOME/.config" "$HOME/.dbt"
  printf '# synthetic test profiles.yml (read-only fixture)\n' > "$HOME/.dbt/profiles.yml"
  printf '# synthetic test config (read-only fixture)\n'       > "$HOME/.config/.keep"
  chmod -R a-w "$HOME/.config" "$HOME/.dbt"
  export DBT_WS_INSTALL_BIN="$WORK/bin"            # sandbox install target
  export DBT_WS_HOME="$REPO"
  export DBT_WS_STATE="$WORK/state"
  export DBT_WS_WORKSPACE="workspace:test"
  export DBT_WS_PROFILE="stow"                     # AXIS 1 (machine profile)
  # AXIS 3 (data) — set explicitly; orthogonal to the profile. The rich
  # duckdb + harlequin case that T1/T4/T5/T7 exercise. SQL_QUERY_MODE is DERIVED
  # in lib/common.sh (never set here).
  export WAREHOUSE="duckdb"
  export HARLEQUIN="on"
  export DBT_PROFILES_DIR="$HOME/.dbt"
  export DWS_TEST_LOG="$WORK/log"
  export DWS_STUB_DIR="$WORK/stub"
  export PATH="$HERE/stubs:$PATH"
  : > "$DWS_TEST_LOG"
  mkdir -p "$DBT_WS_STATE/workspace_test"
  printf 'dbt\n'                 > "$DBT_WS_STATE/workspace_test/ws_type"   # default: a dbt ws
  printf 'pane:edit\n'           > "$DBT_WS_STATE/workspace_test/edit_pane"
  printf 'pane:tools\n'          > "$DBT_WS_STATE/workspace_test/tools_pane"
  printf '%s\n' "$DWS_FIXTURES"  > "$DBT_WS_STATE/workspace_test/dbt_dir"
  printf '%s\n' "$DWS_FIXTURES/dev.duckdb" > "$DBT_WS_STATE/workspace_test/duckdb"
  unset DWS_TEST_TREE STUB_DUCKDB_FQN STUB_GIT_DIRTY STUB_FD_YML DBT_WS_DBT_YAZI DBT_WS_OPEN_HELIX 2>/dev/null || true
}

ok()  { PASS=$((PASS + 1)) ; printf '  ok   %s\n' "$1" ; }
bad() { FAIL=$((FAIL + 1)) ; printf '  FAIL %s\n' "$1" ; }

log_has()   { if grep -qE "$2" "$DWS_TEST_LOG"; then ok "$1"; else bad "$1 (no log line ~ /$2/)"; fi; }
log_hasnt() { if grep -qE "$2" "$DWS_TEST_LOG"; then bad "$1 (unexpected log ~ /$2/)"; else ok "$1"; fi; }
out_has()   { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1 (stdout missing '$2')" ;; esac; }
has_file()  { if [ -e "$2" ]; then ok "$1"; else bad "$1 (missing $2)"; fi; }
no_file()   { if [ -e "$2" ]; then bad "$1 (unexpected $2)"; else ok "$1"; fi; }

# ---------------------------------------------------------------------------
echo "T1: cwd route <model.sql> -> new helix tab in edit pane (+sibling yml)"
setup
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/models/marts/dim_customers.sql")"
log_has "new-surface in EDIT pane"       "new-surface .*--pane pane:edit"
log_has "send hx-wrap with sql + yml"    "send .*hx-wrap .*dim_customers.sql.*schema.yml"
log_has "rename tab hx: dim_customers"      "rename-tab .*hx: dim_customers"
out_has "stdout: opened hx: dim_customers"  "opened hx: dim_customers" "$out"

echo "T2: cwd route <model.sql> already open -> focus, no new tab"
setup
printf '   surface:42 [terminal] "hx: dim_customers"\n' > "$WORK/tree"
export DWS_TEST_TREE="$WORK/tree"
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/models/marts/dim_customers.sql")"
log_has   "move-surface to focus existing" "move-surface --surface surface:42 .*--focus true"
log_hasnt "no new-surface when focusing"   "new-surface"
out_has   "stdout: focused hx: dim_customers" "focused hx: dim_customers" "$out"

echo "T3: cwd route <seed.csv> -> csvlens in tools pane"
setup
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/seeds/orders.csv")"
log_has "new-surface in TOOLS pane" "new-surface .*--pane pane:tools"
log_has "send csvlens"              "send .*csvlens .*orders.csv"
out_has "stdout: opened csv"        "opened csv" "$out"

echo "T4: cwd focus <model> (data axis on, clean, not-a-relation) -> editor + yazi + no-change"
setup
out="$("$REPO/bin/cwd-focus" dim_customers)"
log_has "routes editor (new-surface edit)" "new-surface .*--pane pane:edit"
log_has "reveals in yazi"                  "ya emit-to .* reveal .*dim_customers.sql"
log_has "introspects duckdb (hq_enabled)"  "duckdb .*information_schema"
out_has "stdout: editor channel"           "editor" "$out"
out_has "stdout: yazi channel"             "yazi" "$out"
out_has "stdout: no changes (clean)"       "no changes" "$out"
out_has "stdout: hq not-a-relation"        "not a relation" "$out"

echo "T5: cwd focus <model> with a real relation -> hq-preview full path"
setup
export STUB_DUCKDB_FQN="main_marts.dim_customers"
out="$("$REPO/bin/cwd-focus" dim_customers)"
log_has "hq-preview spawns a tools surface"      "new-surface .*--pane pane:tools"
log_has "hq-preview launches harlequin RO"       "send .*harlequin --read-only"
log_has "hq-preview loads the preview query"     "send .*select \\* from .*dim_customers.* limit 100"
out_has "stdout: preview main_marts.dim_customers"  "preview: main_marts.dim_customers" "$out"

echo "T6a: data axis gates the warehouse path (runtime), independent of the machine profile"
# harlequin OFF -> no duckdb, external query mode (even on the rich `stow` profile)
setup
export HARLEQUIN="off"
out="$("$REPO/bin/cwd-focus" dim_customers)"
log_hasnt "harlequin=off NEVER touches duckdb" "duckdb"
log_has   "still routes the editor"            "new-surface .*--pane pane:edit"
out_has   "stdout: query mode = external"      "query mode = external" "$out"
out_has   "stdout: no warehouse TUI"           "no warehouse TUI" "$out"
# warehouse SNOWFLAKE (harlequin still on) -> still no duckdb path (warehouse gates it)
setup
export WAREHOUSE="snowflake"
out="$("$REPO/bin/cwd-focus" dim_customers)"
log_hasnt "warehouse=snowflake NEVER touches duckdb" "duckdb"
out_has   "stdout: no warehouse TUI (snowflake)"     "no warehouse TUI" "$out"

echo "T6b: install structural — bare omits hq-preview, stow links it"
setup
sh "$REPO/install.sh" bare >/dev/null 2>&1
has_file "bare links core cwd"           "$DBT_WS_INSTALL_BIN/cwd"
no_file  "bare OMITS hq-preview symlink"  "$DBT_WS_INSTALL_BIN/hq-preview"
setup
sh "$REPO/install.sh" stow >/dev/null 2>&1
has_file "stow LINKS hq-preview symlink"  "$DBT_WS_INSTALL_BIN/hq-preview"

echo "T7: cwd focus <model> on a dirty file -> hunk live-session drive"
setup
export STUB_GIT_DIRTY=1
out="$("$REPO/bin/cwd-focus" dim_customers)"
log_has "hunk session reload on dirty"   "hunk session reload"
log_has "hunk session navigate on dirty" "hunk session navigate"
out_has "stdout: hunk channel"           "hunk" "$out"

echo "T8: machine profile and data axis are orthogonal (cwd doctor)"
# bare profile + harlequin on + duckdb -> hq_enabled (bare does NOT force it off)
setup
export DBT_WS_PROFILE="bare"; export HARLEQUIN="on"; export WAREHOUSE="duckdb"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: bare machine profile"            "machine profile  bare" "$out"
out_has "doctor: hq_enabled under bare+on+duckdb" "hq_enabled=yes" "$out"
# stow profile + harlequin off -> hq_enabled no
setup
export DBT_WS_PROFILE="stow"; export HARLEQUIN="off"; export WAREHOUSE="duckdb"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: hq_enabled no under stow+off"    "hq_enabled=no" "$out"
# warehouse gates it too: harlequin on + snowflake -> no
setup
export DBT_WS_PROFILE="bare"; export HARLEQUIN="on"; export WAREHOUSE="snowflake"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: hq_enabled no under warehouse=snowflake" "hq_enabled=no" "$out"
out_has "doctor: warehouse=snowflake in summary"          "warehouse=snowflake" "$out"

echo "T9: doctor surfaces the three axes separately"
setup
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: machine-profile label"   "machine profile" "$out"
out_has "doctor: data-axis block header"  "data axis:" "$out"
out_has "doctor: profiles_dir in summary" "profiles_dir=" "$out"

# derive_setup <profiles-case-dir> — point the workspace at the jaffle project +
# the chosen profiles.yml; let WAREHOUSE auto-derive (clear env + state).
derive_setup() {
  setup
  unset WAREHOUSE HARLEQUIN 2>/dev/null || true
  printf '%s\n' "$DWS_FIXTURES/dbt/project_jaffle" > "$DBT_WS_STATE/workspace_test/dbt_dir"
  rm -f "$DBT_WS_STATE/workspace_test/duckdb"      # so the derived path is what surfaces
  export DBT_PROFILES_DIR="$1"
}

echo "T10: warehouse auto-derive — duckdb (active target wins, quoted relative path)"
derive_setup "$DWS_FIXTURES/dbt/duckdb"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: warehouse=duckdb (derived)"        "warehouse=duckdb" "$out"
out_has "doctor: active target 'dev' won over prod" "warehouse      duckdb" "$out"
out_has "doctor: relative path resolved vs project" "$DWS_FIXTURES/dbt/project_jaffle/analytics/dev.duckdb" "$out"
# ~-prefixed duckdb path expands to $HOME (the sandbox home)
derive_setup "$DWS_FIXTURES/dbt/duckdb_tilde"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: tilde duckdb path -> \$HOME"       "$HOME/warehouse/dev.duckdb" "$out"

echo "T11: warehouse auto-derive — snowflake (active target prod, no path)"
derive_setup "$DWS_FIXTURES/dbt/snowflake"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: warehouse=snowflake (derived)" "warehouse=snowflake" "$out"
out_has "doctor: hq_enabled=no (not duckdb)"    "hq_enabled=no" "$out"

echo "T12: warehouse auto-derive — graceful degrade to none, no error"
# (a) profiles.yml exists but lacks the project's profile
derive_setup "$DWS_FIXTURES/dbt/empty"
out="$("$REPO/bin/cwd" doctor 2>/dev/null)"
out_has "doctor: warehouse=none (profile absent)" "warehouse=none" "$out"
# (b) profiles.yml missing entirely
derive_setup "$WORK/no_such_profiles_dir"
out="$("$REPO/bin/cwd" doctor 2>/dev/null)"
out_has "doctor: warehouse=none (no profiles.yml)" "warehouse=none" "$out"

echo "T13: warehouse auto-derive is READ-ONLY (zero writes to the profiles dir)"
setup
unset WAREHOUSE HARLEQUIN 2>/dev/null || true
printf '%s\n' "$DWS_FIXTURES/dbt/project_jaffle" > "$DBT_WS_STATE/workspace_test/dbt_dir"
rm -f "$DBT_WS_STATE/workspace_test/duckdb"
RODBT="$WORK/ro-dbt"; mkdir -p "$RODBT"
cp "$DWS_FIXTURES/dbt/duckdb/profiles.yml" "$RODBT/profiles.yml"
chmod -R a-w "$RODBT"                            # any write attempt would hard-fail
export DBT_PROFILES_DIR="$RODBT"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: derive resolves under read-only profiles dir" "warehouse=duckdb" "$out"

echo "T13b: warehouse derive — :memory: + md: URIs pass through (NOT path-resolved)"
# A leading space discriminates the field value from the buggy '<project>/:memory:'
# (whose ':memory:' is preceded by '/', not a space).
derive_setup "$DWS_FIXTURES/dbt/duckdb_memory"
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: warehouse=duckdb (memory target)"   "warehouse=duckdb" "$out"
out_has "doctor: :memory: passed through unmodified" " :memory:" "$out"
out="$(DBT_TARGET=md "$REPO/bin/cwd" doctor)"
out_has "doctor: md: URI passed through unmodified"  " md:test_db" "$out"

# UUID key used by the migration tests (a UUID has no :/space, so key == value)
MIG_UUID="11111111-aaaa-2222-bbbb-333333333333"
# mig_setup — a live UUID workspace + a stray Phase-0 ref-keyed dir to migrate
mig_setup() {
  setup
  export DBT_WS_WORKSPACE="$MIG_UUID"               # the live workspace = a UUID
  rm -rf "$DBT_WS_STATE/workspace_test"             # setup()'s dir is irrelevant here
  mkdir -p "$DBT_WS_STATE/workspace_12"             # the old, ref-keyed Phase-0 dir
  printf 'pane:oldedit\n'  > "$DBT_WS_STATE/workspace_12/edit_pane"
  printf 'pane:oldtools\n' > "$DBT_WS_STATE/workspace_12/tools_pane"
}

echo "T14: state migrate — re-key the old ref-dir to the live UUID (collision-free)"
mig_setup
out="$("$REPO/bin/cwd" state migrate workspace_12 --yes 2>&1)"
has_file "edit_pane re-keyed to uuid"   "$DBT_WS_STATE/$MIG_UUID/edit_pane"
has_file "tools_pane re-keyed to uuid"  "$DBT_WS_STATE/$MIG_UUID/tools_pane"
no_file  "old ref-keyed dir removed"    "$DBT_WS_STATE/workspace_12"
out_has  "reports the migration"        "migrated" "$out"
out_has  "old edit_pane value preserved" "pane:oldedit" "$(cat "$DBT_WS_STATE/$MIG_UUID/edit_pane")"

echo "T15: state migrate is idempotent — 2nd run after one seed is a safe no-op"
mig_setup
"$REPO/bin/cwd" state migrate workspace_12 --yes >/dev/null 2>&1     # 1st run migrates
out="$("$REPO/bin/cwd" state migrate workspace_12 --yes 2>&1)"; rc=$?  # 2nd run, same seed
out_has "2nd run: nothing to migrate" "nothing to migrate" "$out"
if [ "$rc" -eq 0 ]; then ok "2nd run exits 0 (idempotent)"; else bad "2nd run rc=$rc (want 0)"; fi
has_file "target still intact after 2nd run" "$DBT_WS_STATE/$MIG_UUID/edit_pane"

echo "T16: state migrate REFUSES on a conflicting key (atomic — nothing moved)"
mig_setup
mkdir -p "$DBT_WS_STATE/$MIG_UUID"
printf 'pane:newedit\n' > "$DBT_WS_STATE/$MIG_UUID/edit_pane"   # conflicts w/ old 'pane:oldedit'
out="$("$REPO/bin/cwd" state migrate workspace_12 --yes 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then ok "refuses (non-zero exit)"; else bad "did not refuse (rc=$rc)"; fi
out_has  "names the colliding key"        "edit_pane" "$out"
out_has  "shows the old value"            "pane:oldedit" "$out"
out_has  "shows the current value"        "pane:newedit" "$out"
has_file "source left intact on refuse"   "$DBT_WS_STATE/workspace_12/edit_pane"
out_has  "target NOT overwritten"         "pane:newedit" "$(cat "$DBT_WS_STATE/$MIG_UUID/edit_pane")"
no_file  "atomic: non-colliding tools_pane NOT moved" "$DBT_WS_STATE/$MIG_UUID/tools_pane"
has_file "non-colliding tools_pane stayed in source"  "$DBT_WS_STATE/workspace_12/tools_pane"

echo "T17: per-workspace containment — UUID-A state is invisible under UUID-B"
setup
rm -rf "$DBT_WS_STATE/workspace_test"
mkdir -p "$DBT_WS_STATE/AAAA-1111"
printf 'pane:secretA\n' > "$DBT_WS_STATE/AAAA-1111/edit_pane"
export DBT_WS_WORKSPACE="BBBB-2222"
out="$("$REPO/bin/cwd" doctor)"
case "$out" in *secretA*) bad "containment: B sees A's state (LEAK)" ;; *) ok "containment: B does NOT see A's state" ;; esac
export DBT_WS_WORKSPACE="AAAA-1111"
out="$("$REPO/bin/cwd" doctor)"
out_has "containment: A sees its own state" "secretA" "$out"

echo "T18: doctor surfaces a stray ref-keyed dir (the F2 mismatch)"
mig_setup
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor lists the stray dir"    "workspace_12" "$out"
out_has "doctor hints the migrate path" "cwd state migrate" "$out"
out_has "live key state dir absent"     "(exists: no)" "$out"

echo "T19: cwd new <worktree> -> births a dbt workspace, captures the ref"
setup
mkdir -p "$WORK/wt"                                  # an existing worktree dir
out="$("$REPO/bin/cwd" new "$WORK/wt" 2>&1)"
log_has "calls cmux new-workspace with --cwd"   "new-workspace .*--cwd $WORK/wt"
log_has "passes a --layout"                     "new-workspace .*--layout"
log_has "layout wires the register surface"     "cwd register dbt"
log_has "layout wires the yazi tree"            "yazi-wrap"
log_has "layout wires the helix editor"         "hx-wrap"
out_has "reports the captured workspace ref"    "workspace:" "$out"
# a non-existent target -> create the worktree first (git stub logs it)
setup
out="$("$REPO/bin/cwd" new "$WORK/newwt" 2>&1)"
log_has "git worktree add for a new target"     "worktree add .*newwt"
out_has "still captures a workspace ref"        "workspace:" "$out"

echo "T20: cwd register dbt writes the UUID-keyed marker + pane refs (from cmux tree)"
setup
export DBT_WS_WORKSPACE="uuid-dbt-9999"
rm -rf "$DBT_WS_STATE/workspace_test"
# REAL cmux titles at register time: a freshly-launched layout surface is titled
# "<cwd>> <command>" (helix sets no title) and the tree pane "Yazi: <cwd>" — NOT
# the post-open "hx: <model>" form (that rename happens later, in cwd-route). The
# editor pane is found by its launch command `hx-wrap`, not a leading "hx".
cat > "$WORK/tree" <<'TREE'
workspace workspace:uuid-dbt-9999 "dbt: wt"
├── pane pane:91
│   └── surface surface:1 [terminal] "Yazi: /tmp/wt"
├── pane pane:92
│   └── surface surface:2 [terminal] "/tmp/wt> hx-wrap"
└── pane pane:93
    ├── surface surface:3 [terminal] "/tmp/wt"
    └── surface surface:4 [terminal] "/tmp/wt> cwd register dbt"
TREE
export DWS_TEST_TREE="$WORK/tree"
KEY="uuid-dbt-9999"
out="$("$REPO/bin/cwd" register dbt 2>&1)"
out_has "register reports it marked the ws"   "marked workspace" "$out"
if [ "$(cat "$DBT_WS_STATE/$KEY/ws_type" 2>/dev/null)" = "dbt" ]; then ok "ws_type=dbt written"; else bad "ws_type not dbt"; fi
if [ "$(cat "$DBT_WS_STATE/$KEY/edit_pane" 2>/dev/null)" = "pane:92" ]; then ok "edit_pane = the hx pane (pane:92)"; else bad "edit_pane wrong"; fi
if [ "$(cat "$DBT_WS_STATE/$KEY/tools_pane" 2>/dev/null)" = "pane:93" ]; then ok "tools_pane = the dbt-shell pane (pane:93)"; else bad "tools_pane wrong"; fi
dout="$("$REPO/bin/cwd" doctor)"
out_has "doctor now reports ws_type=dbt"      "ws_type=dbt" "$dout"

echo "T21: a general workspace (no marker) -> doctor reports ws_type=general"
setup
export DBT_WS_WORKSPACE="uuid-general-0000"
rm -rf "$DBT_WS_STATE/workspace_test"           # no 'cwd register' ever ran -> no marker
out="$("$REPO/bin/cwd" doctor)"
out_has "doctor: ws_type=general (absence == general)" "ws_type=general" "$out"

echo "T22: GENERAL workspace -> open-helix.sh for EVERYTHING (the NEGATIVE assertion)"
setup
rm -f "$DBT_WS_STATE/workspace_test/ws_type"    # drop the marker -> general
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/models/marts/dim_customers.sql" 2>&1)"
log_hasnt "general ws does NOT model-open a .sql" "hx-wrap"
log_hasnt "general ws spawns no edit surface"     "new-surface .*pane:edit"
log_has   "general ws delegates to open-helix.sh" "open-helix.sh .*dim_customers.sql"
out_has   "stdout: opened via open-helix.sh"      "open-helix.sh" "$out"

echo "T23: DBT workspace -> .sql model-open; a non-model file -> open-helix.sh"
setup                                            # ws_type=dbt seeded
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/models/marts/dim_customers.sql" 2>&1)"
log_has "dbt ws: .sql -> model-open (hx-wrap)"   "hx-wrap .*dim_customers.sql"
setup
printf 'notes\n' > "$WORK/notes.md"
out="$("$REPO/bin/cwd-route" "$WORK/notes.md" 2>&1)"
log_has   "dbt ws: notes.md -> open-helix.sh"    "open-helix.sh .*notes.md"
log_hasnt "dbt ws: notes.md does NOT model-open" "hx-wrap .*notes.md"

echo "T24: yazi-wrap selects YAZI_CONFIG_HOME by ws_type (F-8 gate)"
setup                                            # dbt
out="$("$REPO/bin/yazi-wrap" 2>/dev/null)"
out_has "dbt ws -> config/yazi/dbt"              "yazi/dbt" "$out"
setup
rm -f "$DBT_WS_STATE/workspace_test/ws_type"     # general
out="$("$REPO/bin/yazi-wrap" 2>/dev/null)"
out_has "general ws -> the variant path (untouched)" "yazi/stow" "$out"

echo "T25: install --profile stow detects ~/.config, builds the overlay, writes NOTHING to ~/.config"
setup
chmod -R u+w "$HOME/.config"                     # seed the user's dotfiles yazi cfg, then re-lock
mkdir -p "$HOME/.config/yazi"
printf '# user keymap\n'   > "$HOME/.config/yazi/keymap.toml"
printf '# user theme\n'    > "$HOME/.config/yazi/theme.toml"
printf '#!/bin/sh\n'       > "$HOME/.config/yazi/open-helix.sh"
chmod -R a-w "$HOME/.config"                      # read-only: install must only READ here
export DBT_WS_DBT_YAZI="$WORK/overlay"
sh "$REPO/install.sh" --profile stow >/dev/null 2>&1
has_file "stow: overlay yazi.toml symlinked"  "$WORK/overlay/yazi.toml"
has_file "stow: user keymap symlinked"        "$WORK/overlay/keymap.toml"
has_file "stow: user theme symlinked"         "$WORK/overlay/theme.toml"
if [ "$(readlink "$WORK/overlay/keymap.toml")" = "$HOME/.config/yazi/keymap.toml" ]; then ok "overlay keymap -> the user's file"; else bad "keymap symlink target wrong"; fi
has_file "user .config preserved (read-only, not clobbered)" "$HOME/.config/yazi/keymap.toml"
# yazi-wrap now points a dbt ws at the installed overlay
out="$("$REPO/bin/yazi-wrap" 2>/dev/null)"
out_has "dbt ws -> the installed overlay" "$WORK/overlay" "$out"

echo "T26: install --profile bare builds a bundled overlay (no user keymap/theme) + omits hq-preview"
setup
export DBT_WS_DBT_YAZI="$WORK/overlay-bare"
sh "$REPO/install.sh" --profile bare >/dev/null 2>&1
has_file "bare: overlay yazi.toml (bundled)"  "$WORK/overlay-bare/yazi.toml"
no_file  "bare: NO user keymap overlay"        "$WORK/overlay-bare/keymap.toml"
no_file  "bare: hq-preview omitted (structural)" "$DBT_WS_INSTALL_BIN/hq-preview"

echo "T27: dbt ws with a missing edit_pane degrades gracefully (only .sql/dir need it)"
# non-model file -> open-helix.sh (does not need edit_pane)
setup                                            # ws_type=dbt seeded
rm -f "$DBT_WS_STATE/workspace_test/edit_pane"   # a dbt ws whose edit_pane is unresolved
printf 'notes\n' > "$WORK/notes.md"
out="$("$REPO/bin/cwd-route" "$WORK/notes.md" 2>&1)"
log_has "no edit_pane: notes.md still -> open-helix.sh"  "open-helix.sh .*notes.md"
out_has "no edit_pane: stdout opened via open-helix.sh"  "open-helix.sh" "$out"
# .csv -> csvlens in the tools pane (needs tools_pane, NOT edit_pane)
setup
rm -f "$DBT_WS_STATE/workspace_test/edit_pane"
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/seeds/orders.csv" 2>&1)"
log_has "no edit_pane: .csv still -> csvlens (tools pane)" "csvlens .*orders.csv"
# .sql DOES need edit_pane -> a clear error, not a crash
setup
rm -f "$DBT_WS_STATE/workspace_test/edit_pane"
out="$("$REPO/bin/cwd-route" "$DWS_FIXTURES/models/marts/dim_customers.sql" 2>&1)"; rc=$?
out_has "no edit_pane: .sql names the missing edit_pane" "no edit_pane state" "$out"
if [ "$rc" -ne 0 ]; then ok "no edit_pane: .sql exits non-zero (graceful)"; else bad "no edit_pane: .sql should error"; fi

echo "T28: dbt_dir auto-discovery — walk up from PWD to the nearest dbt_project.yml"
# no per-workspace state default + no env default -> discover the project by walking up.
setup
rm -f "$DBT_WS_STATE/workspace_test/dbt_dir"
unset DBT_WS_DBT_DIR_DEFAULT 2>/dev/null || true
mkdir -p "$WORK/proj/models/staging"
printf "name: 'x'\nprofile: 'x'\n" > "$WORK/proj/dbt_project.yml"
out="$(cd "$WORK/proj/models/staging" && "$REPO/bin/cwd" doctor 2>/dev/null)"
out_has "discovers the project root from a nested dir" "$WORK/proj   (axis 2" "$out"
# no dbt_project.yml at or above PWD -> fall back to PWD
out="$(cd "$WORK" && "$REPO/bin/cwd" doctor 2>/dev/null)"
out_has "no project above -> falls back to PWD" "$WORK   (axis 2" "$out"

# ---------------------------------------------------------------------------
echo
echo "Layer-1: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
