#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/build/YT-Grab.app"
dmg_path="$project_dir/build/YT-Grab-macOS-universal.dmg"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/yt-grab-dmg.XXXXXX")"

cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT

if [[ ! -d "$app_dir" ]]; then
    echo "Missing $app_dir. Run YT_GRAB_UNIVERSAL=1 ./Scripts/build-app.sh first." >&2
    exit 1
fi

architectures="$(lipo -archs "$app_dir/Contents/MacOS/YT-Grab")"
if [[ "$architectures" != *"x86_64"* || "$architectures" != *"arm64"* ]]; then
    echo "The application must contain both x86_64 and arm64 architectures." >&2
    exit 1
fi

ditto "$app_dir" "$staging_dir/YT-Grab.app"
ln -s /Applications "$staging_dir/Applications"

rm -f "$dmg_path"
hdiutil create \
    -volname "YT-Grab" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -fs HFS+ \
    -ov \
    "$dmg_path"

codesign --force --sign - "$dmg_path"
codesign --verify --verbose=2 "$dmg_path"

(
    cd "$project_dir/build"
    shasum -a 256 "${dmg_path:t}" > "${dmg_path:t}.sha256"
)

echo "Built $dmg_path"
