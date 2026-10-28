#!/usr/bin/env bash
# Links every skill and command in this repo into one or more Claude Code config dirs.
# Usage: ./install.sh [config-dir ...]   (default: $CLAUDE_CONFIG_DIR, else ~/.claude)
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"

if [ "$#" -eq 0 ]; then
  set -- "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
fi

link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  # A real file or dir already there is someone's work: keep it as a backup, never delete it.
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$stamp"
    echo "  backed up $dst"
  fi
  ln -s "$src" "$dst"
  echo "  linked $dst"
}

for dir in "$@"; do
  echo "$dir"
  # skills/ is often itself a symlink shared between accounts; -p follows it.
  mkdir -p "$dir/skills" "$dir/commands"
  for s in "$repo"/skills/*/; do
    s="${s%/}"
    link "$s" "$dir/skills/$(basename "$s")"
  done
  for c in "$repo"/commands/*.md; do
    link "$c" "$dir/commands/$(basename "$c")"
  done
done
