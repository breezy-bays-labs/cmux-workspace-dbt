#!/bin/sh
# install.sh [profile] — symlink the cwd bin scripts into ~/.local/bin.
#
# `profile` is AXIS 1 (machine config regime): bare | stow. The BARE profile omits
# hq-preview entirely — the interactive warehouse-query surface is structurally
# absent on a clean/team box (data-access boundary), not merely disabled by a
# flag. The harlequin/warehouse data axis is resolved at runtime (lib/common.sh),
# independent of this: the symlink omission is the structural belt, the runtime
# hq_enabled gate the braces. Re-running with a different profile re-points links.
set -eu
profile="bare"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile=*) profile="${1#--profile=}" ;;
    --profile)   shift; [ "$#" -gt 0 ] || { echo "install: --profile needs a value" >&2; exit 2; }; profile="$1" ;;
    bare|stow)   profile="$1" ;;
    -h|--help)   echo "usage: install.sh [--profile <bare|stow>]  (or a bare positional)"; exit 0 ;;
    *)           echo "install: unknown arg '$1'" >&2; exit 2 ;;
  esac
  shift
done
here="$(cd "$(dirname "$0")" && pwd)"
target="${DBT_WS_INSTALL_BIN:-$HOME/.local/bin}"
mkdir -p "$target"

# Profile must exist before we link anything against it.
[ -f "$here/profiles/${profile}.env" ] || { echo "install: unknown profile '$profile'" >&2; exit 2; }

common="cwd cwd-focus cwd-route hx-wrap yazi-wrap git-glance git-glance-render"
# cide IDE command family (editor/explorer/theme/agent surfaces) — no data-access
# boundary, so linked on every profile. (btop-wrap/hq-wrap/stgrev remain unmanaged
# here for now — pre-existing; hq-wrap's warehouse-boundary placement is a separate call.)
cide="cide-open cide-jump cide-md-open cide-regen cide-set-editor cide-set-role cide-theme cide-yazi cide-agent cide-space"
stow_only="hq-preview"   # warehouse-query surface; stow profile only (structural)

link() { ln -sfn "$here/bin/$1" "$target/$1"; echo "  linked $1"; }

echo "cwd install — profile: $profile -> $target"
for s in $common $cide; do link "$s"; done
if [ "$profile" = "stow" ]; then
  for s in $stow_only; do link "$s"; done
else
  rm -f "$target/hq-preview" 2>/dev/null || true
  echo "  (hq-preview NOT linked — warehouse-query surface absent on profile '$profile')"
fi

# dbt yazi overlay — the config home a dbt workspace uses (yazi-wrap points here).
# Always symlinks the bundled config/yazi/dbt/yazi.toml. On `stow`, ALSO symlinks the
# user's keymap.toml/theme.toml so keybinds/theme carry over. NEVER writes ~/.config:
# it is only the symlink TARGET; the symlinks themselves live under the overlay dir.
overlay="${DBT_WS_DBT_YAZI:-$HOME/.local/share/cmux-workspace-dbt/yazi-dbt}"
mkdir -p "$overlay"
ln -sfn "$here/config/yazi/dbt/yazi.toml" "$overlay/yazi.toml"; echo "  overlay yazi.toml -> bundled"
if [ "$profile" = "stow" ] && [ -d "$HOME/.config" ]; then
  echo "  detected ~/.config (Stow dotfiles) — reusing the user's helix opener + keymap/theme (read-only)"
  for f in keymap.toml theme.toml; do
    if [ -f "$HOME/.config/yazi/$f" ]; then
      ln -sfn "$HOME/.config/yazi/$f" "$overlay/$f"; echo "  overlay $f -> ~/.config/yazi/$f"
    fi
  done
else
  rm -f "$overlay/keymap.toml" "$overlay/theme.toml" 2>/dev/null || true   # bundled defaults only
fi

echo
echo "done. Next:"
echo "  - ensure $target is on PATH"
echo "  - set DBT_WS_PROFILE=$profile in the workspace shell env (bare is the default)"
[ "$profile" = stow ] && echo "  - NOTE: yazi opener paths changed -> restart yazi (no hot-reload)"
