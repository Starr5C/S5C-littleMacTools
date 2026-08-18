#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
support_dir="$HOME/Library/Application Support/S5C-LittleLittleArc"
timestamp=$(date +%Y%m%d-%H%M%S)

if [ -d "$support_dir" ]; then
  backup_dir="$support_dir.backup-$timestamp"
  /bin/mv "$support_dir" "$backup_dir"
  echo "Previous helper backed up to: $backup_dir"
fi

/bin/mkdir -p "$support_dir"
/usr/bin/install -m 755 "$project_dir/scripts/build-web-app.zsh" "$support_dir/build-web-app.zsh"
/usr/bin/install -m 644 "$project_dir/scripts/applet.js" "$support_dir/applet.js"
/usr/bin/install -m 644 "$project_dir/scripts/render-icon.js" "$support_dir/render-icon.js"
/usr/bin/install -m 755 "$project_dir/scripts/write-icns.pl" "$support_dir/write-icns.pl"
/usr/bin/install -m 644 "$project_dir/VERSION" "$support_dir/VERSION"
/usr/bin/install -m 644 "$project_dir/BUILD_NUMBER" "$support_dir/BUILD_NUMBER"

"$support_dir/build-web-app.zsh" --help >/dev/null

echo "Installed helper: $support_dir/build-web-app.zsh"
echo "Next: create or update the local Shortcut using SHORTCUT.md."
