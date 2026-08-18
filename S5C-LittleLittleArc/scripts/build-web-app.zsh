#!/bin/zsh
set -euo pipefail

PROGRAM_NAME="S5C LittleLittleArc"
SCRIPT_NAME="${0:t}"
MANAGED_KEY="S5CLittleLittleArcManaged"
TARGET_KEY="S5CTargetURL"
VERSION_KEY="S5CLittleLittleArcVersion"
DEFAULT_OUTPUT_DIR="$HOME/Applications"
FAVICON_BASE_URL="https://favicon.is"
SCRIPT_DIR="${0:A:h}"

if [[ -f "$SCRIPT_DIR/../VERSION" ]]; then
  VERSION_FILE="$SCRIPT_DIR/../VERSION"
  BUILD_NUMBER_FILE="$SCRIPT_DIR/../BUILD_NUMBER"
else
  VERSION_FILE="$SCRIPT_DIR/VERSION"
  BUILD_NUMBER_FILE="$SCRIPT_DIR/BUILD_NUMBER"
fi
[[ -r "$VERSION_FILE" ]] || { print -u2 -r -- "$PROGRAM_NAME: missing VERSION file"; exit 1; }
[[ -r "$BUILD_NUMBER_FILE" ]] || { print -u2 -r -- "$PROGRAM_NAME: missing BUILD_NUMBER file"; exit 1; }
PROGRAM_VERSION="$(<"$VERSION_FILE")"
BUILD_NUMBER="$(<"$BUILD_NUMBER_FILE")"
[[ "$PROGRAM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  print -u2 -r -- "$PROGRAM_NAME: VERSION must be MAJOR.MINOR.PATCH"
  exit 1
}
[[ "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || {
  print -u2 -r -- "$PROGRAM_NAME: BUILD_NUMBER must contain only numeric components"
  exit 1
}

url=""
mode=""
requested_name=""
output_dir="$DEFAULT_OUTPUT_DIR"
non_interactive=false
replace_managed=false
allow_sensitive=false
CANCEL_SENTINEL="__S5C_USER_CANCELLED__"

usage() {
  print -r -- "Usage: $SCRIPT_NAME [URL] [--url URL] [--mode exact|site] [--name NAME]"
  print -r -- "       [--output-dir DIR] [--non-interactive] [--replace-managed]"
  print -r -- "       [--allow-sensitive]"
}

die() {
  print -u2 -r -- "$PROGRAM_NAME: $*"
  exit 1
}

dialog_call() {
  # Standard Additions reports clicking a dialog's cancel button as error -128.
  local stderr_file rc result
  stderr_file="$(/usr/bin/mktemp -t s5c-littlelittlearc-dialog)" || return 1

  if result="$("$@" 2>"$stderr_file")"; then
    rc=0
  else
    rc=$?
  fi

  if (( rc != 0 )); then
    if /usr/bin/grep -q -- '(-128)' "$stderr_file"; then
      /bin/rm -f "$stderr_file"
      print -r -- "$CANCEL_SENTINEL"
      return 0
    fi
    /bin/cat "$stderr_file" >&2
    /bin/rm -f "$stderr_file"
    return "$rc"
  fi

  /bin/rm -f "$stderr_file"
  print -r -- "$result"
}

handle_dialog_result() {
  [[ "$1" == "$CANCEL_SENTINEL" ]] || return 0
  notify "用户已取消操作"
  print -r -- "用户已取消操作"
  exit 0
}

while (( $# > 0 )); do
  case "$1" in
    --url)
      (( $# >= 2 )) || die "--url requires a value"
      url="$2"
      shift 2
      ;;
    --mode)
      (( $# >= 2 )) || die "--mode requires a value"
      mode="$2"
      shift 2
      ;;
    --name)
      (( $# >= 2 )) || die "--name requires a value"
      requested_name="$2"
      shift 2
      ;;
    --output-dir)
      (( $# >= 2 )) || die "--output-dir requires a value"
      output_dir="$2"
      shift 2
      ;;
    --non-interactive)
      non_interactive=true
      shift
      ;;
    --replace-managed)
      replace_managed=true
      shift
      ;;
    --allow-sensitive)
      allow_sensitive=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$url" ]] || die "only one positional URL is allowed"
      url="$1"
      shift
      ;;
  esac
done

for dependency in /usr/bin/osascript /usr/bin/osacompile /usr/bin/plutil /usr/bin/codesign /usr/bin/sips /usr/bin/perl /usr/bin/curl /usr/bin/shasum; do
  [[ -x "$dependency" ]] || die "required system tool is missing: $dependency"
done
[[ -f "$SCRIPT_DIR/applet.js" ]] || die "missing applet.js next to the builder"
[[ -f "$SCRIPT_DIR/render-icon.js" ]] || die "missing render-icon.js next to the builder"
[[ -f "$SCRIPT_DIR/write-icns.pl" ]] || die "missing write-icns.pl next to the builder"

dialog_prompt() {
  local prompt="$1"
  local default_value="${2:-}"
  dialog_call /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      const app = Application.currentApplication();
      app.includeStandardAdditions = true;
      const answer = app.displayDialog(argv[0], {
        withTitle: "S5C LittleLittleArc",
        defaultAnswer: argv[1],
        buttons: ["取消", "继续"],
        defaultButton: "继续",
        cancelButton: "取消"
      });
      return answer.textReturned;
    }
  ' "$prompt" "$default_value"
}

dialog_mode() {
  dialog_call /usr/bin/osascript -l JavaScript -e '
    function run() {
      const app = Application.currentApplication();
      app.includeStandardAdditions = true;
      const answer = app.displayDialog("生成的 App 应该打开哪个地址？", {
        withTitle: "S5C LittleLittleArc",
        buttons: ["取消", "网站主页", "精确页面"],
        defaultButton: "精确页面",
        cancelButton: "取消"
      });
      return answer.buttonReturned === "网站主页" ? "site" : "exact";
    }
  '
}

dialog_continue() {
  local message="$1"
  dialog_call /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      const app = Application.currentApplication();
      app.includeStandardAdditions = true;
      const answer = app.displayDialog(argv[0], {
        withTitle: "S5C LittleLittleArc",
        buttons: ["取消", "继续"],
        defaultButton: "取消",
        cancelButton: "取消",
        withIcon: "caution"
      });
      return answer.buttonReturned;
    }
  ' "$message"
}

dialog_collision() {
  local message="$1"
  dialog_call /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      const app = Application.currentApplication();
      app.includeStandardAdditions = true;
      const answer = app.displayDialog(argv[0], {
        withTitle: "S5C LittleLittleArc",
        buttons: ["取消", "改名", "替换"],
        defaultButton: "取消",
        cancelButton: "取消",
        withIcon: "caution"
      });
      if (answer.buttonReturned === "替换") return "replace";
      if (answer.buttonReturned === "改名") return "rename";
      return "__S5C_USER_CANCELLED__";
    }
  ' "$message"
}

notify() {
  local message="$1"
  $non_interactive && return 0
  /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      const app = Application.currentApplication();
      app.includeStandardAdditions = true;
      app.displayNotification(argv[0], {withTitle: "S5C LittleLittleArc"});
    }
  ' "$message" >/dev/null 2>&1 || true
}

normalize_url() {
  /usr/bin/osascript -l JavaScript -e '
    ObjC.import("Foundation");
    function text(value) { return value ? ObjC.unwrap(value) : ""; }
    function run(argv) {
      const input = argv[0];
      if (!input || /[\u0000-\u001f\u007f]/.test(input)) throw new Error("URL contains control characters.");
      const components = $.NSURLComponents.componentsWithString(input);
      if (!components) throw new Error("URL is invalid.");
      const scheme = text(components.scheme).toLowerCase();
      const host = text(components.host).toLowerCase();
      if (scheme !== "http" && scheme !== "https") throw new Error("Only HTTP and HTTPS URLs are supported.");
      if (!host) throw new Error("URL does not contain a host.");
      if (text(components.user) || text(components.password)) throw new Error("URLs containing a username or password are not supported.");
      components.scheme = scheme;
      components.host = host;
      const exact = text(components.string);
      const site = $.NSURLComponents.alloc.init;
      site.scheme = scheme;
      site.host = components.host;
      site.port = components.port;
      site.path = "/";
      return [exact, host, text(site.string)].join("\t");
    }
  ' "$1"
}

sensitive_query_keys() {
  /usr/bin/osascript -l JavaScript -e '
    ObjC.import("Foundation");
    function run(argv) {
      const components = $.NSURLComponents.componentsWithString(argv[0]);
      const wanted = new Set(["token", "auth", "code", "key", "session", "signature", "access_token", "refresh_token", "api_key"]);
      const found = [];
      const items = components.queryItems;
      const count = items ? Number(items.count) : 0;
      for (let index = 0; index < count; index += 1) {
        const item = items.objectAtIndex(index);
        const name = String(ObjC.unwrap(item.name) || "").toLowerCase();
        if (wanted.has(name) || /(^|_)(token|auth|key|session|signature)($|_)/.test(name)) found.push(name);
      }
      return Array.from(new Set(found)).join(", ");
    }
  ' "$1"
}

suggest_name() {
  local host="${1:l}"
  /usr/bin/perl -CSDA - "$host" <<'PERL'
use strict;
use warnings;
use utf8;
my $host = shift // "web";
$host =~ s/^www\.//;
my @parts = grep { length } split /\./, $host;
my %compound = map { $_ => 1 } qw(
  co.uk org.uk gov.uk ac.uk com.cn net.cn org.cn gov.cn
  com.au net.au org.au co.jp ne.jp co.nz com.br com.sg com.hk
);
my $brand = $parts[0] // "web";
if (@parts >= 2) {
    my $suffix2 = join ".", @parts[-2, -1];
    $brand = $compound{$suffix2} && @parts >= 3 ? $parts[-3] : $parts[-2];
}
my %brands = (
    chatgpt => "ChatGPT", openai => "OpenAI", github => "GitHub",
    youtube => "YouTube", linkedin => "LinkedIn", icloud => "iCloud",
    notebooklm => "NotebookLM",
);
my %acronyms = map { $_ => uc $_ } qw(gpt ai api ui ux crm erp pdf url rss vr ar id qa);
my $name;
if (exists $brands{$brand}) {
    $name = $brands{$brand};
} else {
    my @tokens = grep { length } split /[-_]+/, $brand;
    @tokens = ($brand) unless @tokens;
    $name = join " ", map {
        my $token = lc $_;
        if (exists $acronyms{$token}) {
            $acronyms{$token};
        } else {
            my $matched = "";
            for my $suffix (sort { length($b) <=> length($a) } keys %acronyms) {
                if (length($token) > length($suffix) && $token =~ /\Q$suffix\E$/) {
                    my $prefix = substr($token, 0, length($token) - length($suffix));
                    $matched = ucfirst($prefix) . $acronyms{$suffix};
                    last;
                }
            }
            $matched || ucfirst($token);
        }
    } @tokens;
}
$name =~ s/\s+/ /g;
print "$name Web";
PERL
}

sanitize_name() {
  /usr/bin/perl -CSDA -e '
    use strict; use warnings; use utf8;
    local $/; my $name = <STDIN> // "";
    $name =~ s/[\x00-\x1f\x7f]//g;
    $name =~ s{[/:]}{-}g;
    $name =~ s/\.app\s*$//i;
    $name =~ s/^\s+|\s+$//g;
    $name =~ s/^\.+|\.+$//g;
    $name =~ s/\s+/ /g;
    my @chars = split //, $name;
    $name = join "", @chars[0 .. 79] if @chars > 80;
    if (length($name) && $name !~ /\sWeb$/i) { $name .= " Web"; }
    $name =~ s/\sweb$/ Web/i;
    print $name;
  '
}

plist_raw() {
  local plist="$1"
  local key="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$plist" 2>/dev/null || true
}

is_managed_app() {
  local app="$1"
  [[ -f "$app/Contents/Info.plist" ]] || return 1
  [[ "$(plist_raw "$app/Contents/Info.plist" "$MANAGED_KEY")" == "true" ]]
}

if [[ -z "$url" ]]; then
  clipboard="$(/usr/bin/pbpaste 2>/dev/null || true)"
  if [[ -n "$clipboard" ]] && normalize_url "$clipboard" >/dev/null 2>&1; then
    url="$clipboard"
  elif $non_interactive; then
    die "a URL is required in non-interactive mode"
  else
    url="$(dialog_prompt "请输入要打包的 HTTP 或 HTTPS 地址：" "https://")" || exit 2
    handle_dialog_result "$url"
  fi
fi

url_info="$(normalize_url "$url")" || die "invalid URL"
IFS=$'\t' read -r exact_url host site_url <<< "$url_info"

if [[ -z "$mode" ]]; then
  if $non_interactive; then
    mode="exact"
  else
    mode="$(dialog_mode)" || exit 2
    handle_dialog_result "$mode"
  fi
fi
[[ "$mode" == "exact" || "$mode" == "site" ]] || die "--mode must be exact or site"
target_url="$exact_url"
[[ "$mode" == "site" ]] && target_url="$site_url"

if [[ "$mode" == "exact" ]]; then
  sensitive="$(sensitive_query_keys "$target_url")"
  if [[ -n "$sensitive" ]] && ! $allow_sensitive; then
    if $non_interactive; then
      die "sensitive query keys require --allow-sensitive: $sensitive"
    fi
    dialog_result="$(dialog_continue "这个地址包含可能的敏感参数：$sensitive。目标 URL 会以明文保存在生成的 App 中。仍然继续吗？")" || exit 2
    handle_dialog_result "$dialog_result"
  fi
fi

suggested_name="$(suggest_name "$host")"
if [[ -z "$requested_name" ]]; then
  if $non_interactive; then
    requested_name="$suggested_name"
  else
    requested_name="$(dialog_prompt "确认 App 名称：" "$suggested_name")" || exit 2
    handle_dialog_result "$requested_name"
  fi
fi

/bin/mkdir -p "$output_dir"
output_dir="${output_dir:A}"

while true; do
  app_name="$(print -rn -- "$requested_name" | sanitize_name)"
  [[ -n "$app_name" ]] || {
    $non_interactive && die "App name is empty after sanitization"
    requested_name="$(dialog_prompt "名称不能为空，请重新输入：" "$suggested_name")" || exit 2
    handle_dialog_result "$requested_name"
    continue
  }
  final_app="$output_dir/$app_name.app"
  existing_target=""
  existing_bundle_id=""
  was_update=false

  if [[ -e "$final_app" ]]; then
    if ! is_managed_app "$final_app"; then
      if $non_interactive; then
        die "refusing to overwrite unmanaged application: $final_app"
      fi
      requested_name="$(dialog_prompt "同名 App 不是本工具创建的，不能覆盖。请输入其他名称：" "$app_name")" || exit 2
      handle_dialog_result "$requested_name"
      continue
    fi

    was_update=true
    existing_target="$(plist_raw "$final_app/Contents/Info.plist" "$TARGET_KEY")"
    existing_bundle_id="$(plist_raw "$final_app/Contents/Info.plist" CFBundleIdentifier)"
    if [[ "$existing_target" != "$target_url" ]] && ! $replace_managed; then
      if $non_interactive; then
        die "managed application has a different target; use --replace-managed or another name"
      fi
      decision="$(dialog_collision "“$app_name” 已由本工具管理，但它打开的是另一个地址。")" || exit 2
      handle_dialog_result "$decision"
      case "$decision" in
        replace) replace_managed=true ;;
        rename)
          requested_name="$(dialog_prompt "请输入其他名称：" "$app_name")" || exit 2
          handle_dialog_result "$requested_name"
          continue
          ;;
        *) exit 2 ;;
      esac
    fi
  fi
  break
done

hash="$(print -rn -- "$target_url|$app_name" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print substr($1,1,20)}')"
bundle_id="com.starrchen.s5clittlelittlearc.web.$hash"
[[ -n "$existing_bundle_id" ]] && bundle_id="$existing_bundle_id"

staging_root="$(/usr/bin/mktemp -d "$output_dir/.s5c-littlelittlearc.XXXXXX")"
staged_app="$staging_root/$app_name.app"
work_dir="$staging_root/work"
backup_app="$staging_root/previous.app"
cleanup() {
  if [[ -e "$backup_app" ]] && [[ ! -e "$final_app" ]]; then
    /bin/mv "$backup_app" "$final_app" 2>/dev/null || true
  fi
  /bin/rm -rf "$staging_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
/bin/mkdir -p "$work_dir"

icon_source="$work_dir/favicon"
icon_fallback=false
if [[ -n "${S5C_ICON_FILE:-}" ]] && [[ -f "${S5C_ICON_FILE}" ]]; then
  /bin/cp "$S5C_ICON_FILE" "$icon_source"
elif [[ "${S5C_SKIP_NETWORK:-0}" != "1" ]]; then
  encoded_host="$(/usr/bin/osascript -l JavaScript -e 'function run(argv) { return encodeURIComponent(argv[0]); }' "$host")"
  if ! /usr/bin/curl --fail --location --silent --show-error \
      --connect-timeout 8 --max-time 20 --max-filesize 5242880 \
      --proto '=https' --user-agent "$PROGRAM_NAME/$PROGRAM_VERSION" \
      "$FAVICON_BASE_URL/$encoded_host?larger=true" -o "$icon_source"; then
    icon_fallback=true
  fi
else
  icon_fallback=true
fi

if ! $icon_fallback; then
  if [[ ! -s "$icon_source" ]] || ! /usr/bin/sips -g pixelWidth -g pixelHeight "$icon_source" >/dev/null 2>&1; then
    icon_fallback=true
  fi
fi

letter="${app_name[1,1]:-W}"
rendered_png="$work_dir/icon-1024.png"
if $icon_fallback; then
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/render-icon.js" - "$rendered_png" "$letter" >/dev/null
else
  if ! /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/render-icon.js" "$icon_source" "$rendered_png" "$letter" >/dev/null; then
    icon_fallback=true
    /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/render-icon.js" - "$rendered_png" "$letter" >/dev/null
  fi
fi

icon_parts="$work_dir/icon-parts"
/bin/mkdir -p "$icon_parts"
for size in 16 32 64 128 256 512 1024; do
  /usr/bin/sips -s format png -z "$size" "$size" "$rendered_png" -o "$icon_parts/$size.png" >/dev/null
done
/usr/bin/perl "$SCRIPT_DIR/write-icns.pl" "$icon_parts" "$work_dir/applet.icns"

/usr/bin/osacompile -l JavaScript -o "$staged_app" "$SCRIPT_DIR/applet.js"
info_plist="$staged_app/Contents/Info.plist"

/usr/bin/plutil -replace CFBundleName -string "$app_name" "$info_plist"
/usr/bin/plutil -insert CFBundleDisplayName -string "$app_name" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace CFBundleDisplayName -string "$app_name" "$info_plist"
/usr/bin/plutil -insert CFBundleIdentifier -string "$bundle_id" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace CFBundleIdentifier -string "$bundle_id" "$info_plist"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$PROGRAM_VERSION" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace CFBundleShortVersionString -string "$PROGRAM_VERSION" "$info_plist"
/usr/bin/plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$info_plist"
/usr/bin/plutil -replace CFBundleIconFile -string "applet" "$info_plist"
/usr/bin/plutil -insert LSUIElement -bool YES "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace LSUIElement -bool YES "$info_plist"
/usr/bin/plutil -insert "$MANAGED_KEY" -bool YES "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace "$MANAGED_KEY" -bool YES "$info_plist"
/usr/bin/plutil -insert "$TARGET_KEY" -string "$target_url" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace "$TARGET_KEY" -string "$target_url" "$info_plist"
/usr/bin/plutil -insert "$VERSION_KEY" -string "$PROGRAM_VERSION" "$info_plist" 2>/dev/null \
  || /usr/bin/plutil -replace "$VERSION_KEY" -string "$PROGRAM_VERSION" "$info_plist"

for key in CFBundleIconName NSAppleEventsUsageDescription NSAppleMusicUsageDescription NSCalendarsUsageDescription \
  NSCameraUsageDescription NSContactsUsageDescription NSHomeKitUsageDescription NSMicrophoneUsageDescription \
  NSPhotoLibraryUsageDescription NSRemindersUsageDescription NSSiriUsageDescription NSSystemAdministrationUsageDescription; do
  /usr/bin/plutil -remove "$key" "$info_plist" 2>/dev/null || true
done
/bin/rm -f "$staged_app/Contents/Resources/Assets.car"
/bin/cp "$work_dir/applet.icns" "$staged_app/Contents/Resources/applet.icns"

/usr/bin/plutil -lint "$info_plist" >/dev/null
/usr/bin/codesign --force --deep --sign - "$staged_app" >/dev/null
/usr/bin/codesign --verify --deep --strict "$staged_app"
[[ "$(plist_raw "$info_plist" "$TARGET_KEY")" == "$target_url" ]] || die "staged target validation failed"
[[ "$(plist_raw "$info_plist" "$MANAGED_KEY")" == "true" ]] || die "staged managed marker validation failed"
[[ -x "$staged_app/Contents/MacOS/applet" ]] || die "staged launcher is not executable"

if $was_update; then
  /bin/mv "$final_app" "$backup_app"
  if [[ "${S5C_TEST_FAIL_AFTER_BACKUP:-0}" == "1" ]]; then
    /bin/mv "$backup_app" "$final_app"
    die "injected failure after backup"
  fi
fi

if ! /bin/mv "$staged_app" "$final_app"; then
  if [[ -e "$backup_app" ]] && [[ ! -e "$final_app" ]]; then
    /bin/mv "$backup_app" "$final_app" || true
  fi
  die "could not install the generated application"
fi
/bin/rm -rf "$backup_app" 2>/dev/null || true

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ "${S5C_NO_REGISTER:-0}" != "1" ]] && [[ -x "$lsregister" ]]; then
  "$lsregister" -f "$final_app" >/dev/null 2>&1 || true
fi
/usr/bin/touch "$final_app"

if $icon_fallback; then
  notify "已生成 $app_name；网站图标不可用，已使用首字母图标。"
else
  notify "已生成 $app_name。"
fi
print -r -- "$final_app"
