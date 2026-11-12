#!/usr/bin/env bash
# Install the latest Mise release to ~/.local/bin (user-local, no host layer).
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
readonly MISE_PATH="$HOME/.local/bin/mise"

info() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if (($#)); then
  printf 'Usage: %s\n' "${0##*/}" >&2
  exit 2
fi

(( EUID != 0 )) || die "run this script as your regular user"

installed_version=
if [[ -x $MISE_PATH ]]; then
  installed_version=$("$MISE_PATH" --version 2>/dev/null || true)
fi

if [[ -n $installed_version ]]; then
  info "Updating Mise ${installed_version%% *} to the latest release at $MISE_PATH"
else
  info "Installing the latest Mise release to $MISE_PATH"
fi

command -v curl >/dev/null 2>&1 || die "required command not found: curl"
mkdir -p -- "$HOME/.local/bin"
# Intentionally unpinned: desktop tools track rolling `latest` (see README).
# Repository GPG keys and fonts stay pinned; Mise itself is TLS-trusted.
curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_PATH" sh
installed_version=$("$MISE_PATH" --version 2>/dev/null || true)
[[ -n $installed_version ]] || die "Mise installation failed or produced no version"
info "Using Mise $installed_version"

"$MISE_PATH" trust "$REPO_ROOT/mise.toml"
(
  cd "$REPO_ROOT"
  "$MISE_PATH" install
  "$MISE_PATH" run ansible-collections
)

# Make repo tools resolve in EVERY directory (not just the checkout) by
# pointing the global Mise config at the repo file. Dotfile sources stay
# relative to the repo root, so this is safe.
# Host and Toolbx share the same toolset (including Starship); the prompt
# itself shows a toolbox marker via the starship `container` module.
mkdir -p -- "$HOME/.config/mise"
target="$HOME/.config/mise/config.toml"
source="$REPO_ROOT/mise.toml"
if [[ -L $target && $(readlink -f -- "$target" 2>/dev/null || true) == "$source" ]]; then
  info "global Mise config.toml already points at repository"
elif [[ -e $target || -L $target ]]; then
  die "global Mise config.toml conflicts at $target; back it up or remove it manually"
else
  ln -s -- "$source" "$target"
  info "linked global Mise config.toml to repository"
fi
