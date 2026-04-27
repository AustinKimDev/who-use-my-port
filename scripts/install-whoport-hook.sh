#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
hook_path="$repo_root/hooks/whoport-hook.sh"
profile_path="${1:-$HOME/.zshrc}"

if [ ! -f "$hook_path" ]; then
  echo "Missing hook file: $hook_path" >&2
  exit 1
fi

marker_begin="# >>> whoport hook >>>"
marker_end="# <<< whoport hook <<<"

if [ -f "$profile_path" ] && grep -Fq "$marker_begin" "$profile_path"; then
  echo "whoport hook is already installed in $profile_path"
  exit 0
fi

{
  echo ""
  echo "$marker_begin"
  echo "export WHOPORT_BIN=\"$repo_root/bin/whoport\""
  echo "# WHOPORT_TOOL is inferred by the hook for AI terminals; set it here only to override."
  echo ". \"$hook_path\""
  echo "$marker_end"
} >> "$profile_path"

echo "Installed whoport hook in $profile_path"
echo "Restart the shell or run:"
echo ". \"$hook_path\""
