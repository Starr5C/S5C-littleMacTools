#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILDER="$PROJECT_DIR/scripts/build-web-app.zsh"
WORK_ROOT="$(/usr/bin/mktemp -d /tmp/s5c-littlelittlearc-check.XXXXXX)"
APPS_DIR="$WORK_ROOT/Applications"
export S5C_SKIP_NETWORK=1
export S5C_NO_REGISTER=1

cleanup() { /bin/rm -rf "$WORK_ROOT" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

pass_count=0
pass() {
  (( pass_count += 1 ))
  print -r -- "ok $pass_count - $1"
}

fail() {
  print -u2 -r -- "not ok - $1"
  exit 1
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label (expected: $expected, actual: $actual)"
  pass "$label"
}

plist_raw() {
  /usr/bin/plutil -extract "$2" raw -o - "$1/Contents/Info.plist"
}

/bin/mkdir -p "$APPS_DIR"
/bin/chmod +x "$PROJECT_DIR/scripts/build-web-app.zsh" "$PROJECT_DIR/scripts/write-icns.pl"
/bin/zsh -n "$PROJECT_DIR/scripts/build-web-app.zsh"
/usr/bin/perl -c "$PROJECT_DIR/scripts/write-icns.pl" >/dev/null
[[ -s "$PROJECT_DIR/VERSION" ]] || fail "VERSION file is missing"
[[ -s "$PROJECT_DIR/BUILD_NUMBER" ]] || fail "BUILD_NUMBER file is missing"
project_version="$(<"$PROJECT_DIR/VERSION")"
build_number="$(<"$PROJECT_DIR/BUILD_NUMBER")"
[[ "$project_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION is not MAJOR.MINOR.PATCH"
[[ "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || fail "BUILD_NUMBER is not numeric"
if ! /usr/bin/grep -Fq "当前版本：\`$project_version\`" "$PROJECT_DIR/README.md"; then
  fail "README current version is out of sync"
fi
pass "script syntax"

install_home="$WORK_ROOT/install-home"
HOME="$install_home" "$PROJECT_DIR/scripts/install.sh" >/dev/null
assert_equal "$(<"$install_home/Library/Application Support/S5C-LittleLittleArc/VERSION")" "$project_version" "install carries VERSION"
assert_equal "$(<"$install_home/Library/Application Support/S5C-LittleLittleArc/BUILD_NUMBER")" "$build_number" "install carries BUILD_NUMBER"
HOME="$install_home" "$install_home/Library/Application Support/S5C-LittleLittleArc/build-web-app.zsh" --help >/dev/null
pass "installed helper reads version metadata"

chatgpt_app="$($BUILDER --url 'https://chatgpt.com/path?hello=world#section' --mode exact --output-dir "$APPS_DIR" --non-interactive)"
assert_equal "${chatgpt_app:t}" "ChatGPT Web.app" "ChatGPT automatic naming"
assert_equal "$(plist_raw "$chatgpt_app" S5CTargetURL)" "https://chatgpt.com/path?hello=world#section" "exact URL is preserved"
assert_equal "$(plist_raw "$chatgpt_app" S5CLittleLittleArcManaged)" "true" "managed marker"
assert_equal "$(plist_raw "$chatgpt_app" CFBundleShortVersionString)" "$project_version" "bundle short version follows VERSION"
assert_equal "$(plist_raw "$chatgpt_app" CFBundleVersion)" "$build_number" "bundle build follows BUILD_NUMBER"
assert_equal "$(plist_raw "$chatgpt_app" S5CLittleLittleArcVersion)" "$project_version" "managed version follows VERSION"
/usr/bin/plutil -lint "$chatgpt_app/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict "$chatgpt_app"
/usr/bin/file "$chatgpt_app/Contents/MacOS/applet" | /usr/bin/grep -q arm64
/usr/bin/file "$chatgpt_app/Contents/MacOS/applet" | /usr/bin/grep -q x86_64
pass "bundle, signature, and universal launcher"

for key in NSAppleEventsUsageDescription NSCameraUsageDescription NSContactsUsageDescription NSMicrophoneUsageDescription; do
  if /usr/bin/plutil -extract "$key" raw -o - "$chatgpt_app/Contents/Info.plist" >/dev/null 2>&1; then
    fail "unrelated privacy key remains: $key"
  fi
done
pass "unrelated privacy declarations removed"

bundle_before="$(plist_raw "$chatgpt_app" CFBundleIdentifier)"
$BUILDER --url 'https://chatgpt.com/path?hello=world#section' --mode exact --output-dir "$APPS_DIR" --non-interactive >/dev/null
bundle_after="$(plist_raw "$chatgpt_app" CFBundleIdentifier)"
assert_equal "$bundle_after" "$bundle_before" "same-target update preserves Bundle ID"

compound_app="$($BUILDER --url 'https://service.example.co.uk/docs?q=1#x' --mode site --output-dir "$APPS_DIR" --non-interactive)"
assert_equal "${compound_app:t}" "Example Web.app" "compound suffix naming"
assert_equal "$(plist_raw "$compound_app" S5CTargetURL)" "https://service.example.co.uk/" "site mode keeps origin only"

if $BUILDER --url 'file:///tmp/test' --mode exact --output-dir "$APPS_DIR" --non-interactive >/dev/null 2>&1; then
  fail "invalid scheme was accepted"
fi
pass "invalid scheme rejected"

if $BUILDER --url 'https://example.net/?access_token=secret' --mode exact --name Sensitive --output-dir "$APPS_DIR" --non-interactive >/dev/null 2>&1; then
  fail "sensitive query was accepted without opt-in"
fi
pass "sensitive query requires explicit opt-in"

sensitive_app="$($BUILDER --url 'https://example.net/?access_token=secret' --mode exact --name Sensitive --output-dir "$APPS_DIR" --non-interactive --allow-sensitive)"
assert_equal "$(plist_raw "$sensitive_app" S5CTargetURL)" "https://example.net/?access_token=secret" "sensitive opt-in preserves target"

unicode_app="$($BUILDER --url 'https://unicode.example/' --mode exact --name '测试' --output-dir "$APPS_DIR" --non-interactive)"
assert_equal "${unicode_app:t}" "测试 Web.app" "Unicode name"

unmanaged_app="$APPS_DIR/Unmanaged Web.app"
/bin/mkdir -p "$unmanaged_app/Contents"
/usr/bin/plutil -create xml1 "$unmanaged_app/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.example.unmanaged "$unmanaged_app/Contents/Info.plist"
if $BUILDER --url 'https://unmanaged.example/' --mode exact --name Unmanaged --output-dir "$APPS_DIR" --non-interactive >/dev/null 2>&1; then
  fail "unmanaged application was overwritten"
fi
assert_equal "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$unmanaged_app/Contents/Info.plist")" "com.example.unmanaged" "unmanaged collision protected"

managed_app="$($BUILDER --url 'https://managed.example/one' --mode exact --name Managed --output-dir "$APPS_DIR" --non-interactive)"
managed_bundle="$(plist_raw "$managed_app" CFBundleIdentifier)"
if $BUILDER --url 'https://managed.example/two' --mode exact --name Managed --output-dir "$APPS_DIR" --non-interactive >/dev/null 2>&1; then
  fail "different managed target was replaced without opt-in"
fi
pass "different managed target requires explicit replace"
$BUILDER --url 'https://managed.example/two' --mode exact --name Managed --output-dir "$APPS_DIR" --non-interactive --replace-managed >/dev/null
assert_equal "$(plist_raw "$managed_app" S5CTargetURL)" "https://managed.example/two" "managed target replaced"
assert_equal "$(plist_raw "$managed_app" CFBundleIdentifier)" "$managed_bundle" "managed replacement preserves Bundle ID"

rollback_app="$($BUILDER --url 'https://rollback.example/old' --mode exact --name Rollback --output-dir "$APPS_DIR" --non-interactive)"
if S5C_TEST_FAIL_AFTER_BACKUP=1 $BUILDER --url 'https://rollback.example/new' --mode exact --name Rollback --output-dir "$APPS_DIR" --non-interactive --replace-managed >/dev/null 2>&1; then
  fail "injected update failure unexpectedly succeeded"
fi
assert_equal "$(plist_raw "$rollback_app" S5CTargetURL)" "https://rollback.example/old" "failed update restores previous app"

iconset="$WORK_ROOT/extracted.iconset"
/usr/bin/iconutil -c iconset "$chatgpt_app/Contents/Resources/applet.icns" -o "$iconset"
icon_fixture="$iconset/icon_512x512.png"
[[ -s "$icon_fixture" ]] || fail "could not extract icon fixture"
S5C_ICON_FILE="$icon_fixture" $BUILDER --url 'https://icon.example/' --mode exact --name IconSource --output-dir "$APPS_DIR" --non-interactive >/dev/null
[[ -s "$APPS_DIR/IconSource Web.app/Contents/Resources/applet.icns" ]] || fail "source icon pipeline did not produce ICNS"
pass "downloaded-icon pipeline via local fixture"

print -r -- "1..$pass_count"
print -r -- "All checks passed."
