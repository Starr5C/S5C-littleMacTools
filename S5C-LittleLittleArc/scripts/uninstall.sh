#!/bin/sh
set -eu

support_dir="$HOME/Library/Application Support/S5C-LittleLittleArc"

if [ -d "$support_dir" ]; then
  /bin/rm -rf "$support_dir"
  echo "Removed helper: $support_dir"
else
  echo "Helper is not installed."
fi

echo "Delete the “S5C LittleLittleArc” shortcut manually in Shortcuts."
echo "Generated web apps in ~/Applications were preserved."
