# cide-layout.sh — layout-as-data for cide (#21). Turns the cide.toml [ide].layout
# preset into a WINDOW PLAN: one line per window, each carrying a cmux layout-JSON tree
# that `cmux workspace create --layout <json>` instantiates (panes + per-surface
# launch commands). The cmux layout tree IS the format (no cide DSL); the only thing it
# can't express is multi-window, so a "preset" is just a list of {role, orientation,
# layout-json} windows. cide-space replays this into fresh, registered workspaces.
# shellcheck shell=sh
#
# Composition (CONFIRMED — architecture-direction.md "ARTIFACT PANE + dual composition"):
#   landscape-portrait  (the active setup)
#     PORTRAIT  = artifact pane (helix), full height  (+ markdown/viewer tabs on demand)
#     LANDSCAPE = tools:  [yazi(+agent tab) | review(tig·lazygit·gh-dash·difft·cmux-diff)]
#                         over  [shell | task-runner(just·notify)]
# Requires DBT_WS_HOME set + lib/cide-editor.sh sourced (for cide_toml_get). jq required.

# cmux layout-tree facts (probed live):
#   node = split {direction, split, children:[...]}  OR  leaf {pane:{surfaces:[...]}}
#   direction "horizontal" = side-by-side columns; "vertical" = stacked rows (verified)
#   surface = {type:"terminal", name, command}; command runs in the surface's shell,
#             which persists after it exits (so `echo …` = a labeled, ready shell).

# Artifact (portrait) window: a single helix pane. Viewer/markdown/html ride as tabs
# added on demand, not at birth.
_cide_portrait_json() {
  jq -nc '{pane:{surfaces:[{type:"terminal",name:"helix",command:"hx-wrap"}]}}'
}

# Tools (landscape) window. include_agent=1 rides an agent tab in the yazi pane (the
# configured placement=landscape default; the agent shares yazi's pane so review + agent
# + editor are visible at once). "Lazy" tools (difft/cmux-diff) open to --help — they
# act on a target, they don't auto-run. shell pane = a bare shell; notify is a labeled
# placeholder until the PR-review/notifications work (#25) lands.
# $2 (optional) overrides the agent surface's command — `cide-space open` passes a
# `claude --resume <checkpoint>` here to continue a captured conversation; `new` omits it
# and the agent tab is a labeled hint shell (no auto-claude).
_cide_landscape_json() {  # <include_agent: 1|0> [agent-cmd-override]
  _agentcmd="${2:-}"
  [ -n "$_agentcmd" ] || _agentcmd='echo "↳ run cide-agent here to start the agent in this pane"'
  _notifyhint='echo "↳ notifications pane — tracked: #25"'
  jq -nc --argjson agent "${1:-1}" --arg ah "$_agentcmd" --arg nh "$_notifyhint" '
  {
    direction:"vertical", split:0.75,
    children:[
      { direction:"horizontal", split:0.5, children:[
          { pane:{ surfaces:
              ( [ {type:"terminal",name:"yazi",command:"yazi-wrap"} ]
                + (if $agent==1 then [ {type:"terminal",name:"agent",command:$ah} ] else [] end) ) } },
          { pane:{ surfaces:[
              {type:"terminal",name:"tig",command:"tig"},
              {type:"terminal",name:"lazygit",command:"lazygit"},
              {type:"terminal",name:"gh-dash",command:"gh dash"},
              {type:"terminal",name:"difft",command:"difft --help"},
              {type:"terminal",name:"cmux-diff",command:"cmux diff --help"}
          ] } }
      ] },
      { direction:"horizontal", split:0.5, children:[
          { pane:{ surfaces:[ {type:"terminal",name:"shell"} ] } },
          { pane:{ surfaces:[
              {type:"terminal",name:"just",command:"just --list"},
              {type:"terminal",name:"notify",command:$nh}
          ] } }
      ] }
    ]
  }'
}

# Emit the window plan for a layout: one TSV line per window — role<TAB>orientation<TAB>layout-json.
# jq -c keeps each json on a single line (no tabs/newlines), so the TSV is safe.
# $2 (optional) overrides the agent surface's command (see _cide_landscape_json) — used by
# `cide-space open` to relaunch the agent slot as a `claude --resume <checkpoint>`.
cide_layout_plan() {  # <layout-name> [agent-cmd-override]
  _lay="$1"; _agentcmd="${2:-}"
  _place="$(cide_toml_get agents placement)"; _place="${_place:-landscape}"
  case "$_place" in landscape|both) _agent=1 ;; *) _agent=0 ;; esac
  _t="$(printf '\t')"
  case "$_lay" in
    landscape-portrait)
      printf 'editor%sportrait%s%s\n'  "$_t" "$_t" "$(_cide_portrait_json)"
      printf 'tools%slandscape%s%s\n'  "$_t" "$_t" "$(_cide_landscape_json "$_agent" "$_agentcmd")"
      ;;
    single-portrait)
      printf 'editor%sportrait%s%s\n'  "$_t" "$_t" "$(_cide_portrait_json)"
      ;;
    single-landscape|dual-landscape|dual-portrait)
      # Not yet specialized — fall back to the artifact window so `new` still works,
      # and flag it. Full role-maps for these are a follow-up (#21).
      printf 'editor%sportrait%s%s\n'  "$_t" "$_t" "$(_cide_portrait_json)"
      echo "cide-layout: '$_lay' not fully specialized yet — created the artifact window only (tracked: #21)." >&2
      ;;
    *)
      printf 'editor%sportrait%s%s\n'  "$_t" "$_t" "$(_cide_portrait_json)"
      echo "cide-layout: unknown layout '$_lay' — defaulted to a single artifact window." >&2
      ;;
  esac
}
