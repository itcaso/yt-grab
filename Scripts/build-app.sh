#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

if [[ "${YT_GRAB_UNIVERSAL:-0}" == "1" ]]; then
    swift build -c release --arch x86_64 --scratch-path "$project_dir/.build-x86_64" -j 2
    swift build -c release --arch arm64 --scratch-path "$project_dir/.build-arm64" -j 2
    binary_source="$project_dir/build/YT-Grab-universal"
    mkdir -p "$project_dir/build"
    lipo -create \
        "$project_dir/.build-x86_64/x86_64-apple-macosx/release/YT-Grab" \
        "$project_dir/.build-arm64/arm64-apple-macosx/release/YT-Grab" \
        -output "$binary_source"
else
    swift build -c release -j 2
    binary_source="$project_dir/.build/release/YT-Grab"
fi

app_dir="$project_dir/build/YT-Grab.app"
staging_dir="$project_dir/build/.YT-Grab.app.staging"
contents_dir="$staging_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

rm -rf "$staging_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp "$binary_source" "$macos_dir/YT-Grab"
cp "$project_dir/Support/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Assets/YT-Grab.icns" "$resources_dir/YT-Grab.icns"
cp "$project_dir/Sources/AudioGrab/Resources/YTGrabAppIcon.png" "$resources_dir/YTGrabAppIcon.png"
cp "$project_dir/LICENSE.md" "$resources_dir/LICENSE.md"
cp "$project_dir/NOTICE" "$resources_dir/NOTICE"
cp -R "$project_dir/Sources/AudioGrab/Resources/en.lproj" "$resources_dir/en.lproj"
cp -R "$project_dir/Sources/AudioGrab/Resources/es.lproj" "$resources_dir/es.lproj"

chmod +x "$macos_dir/YT-Grab"

codesign --force --deep --sign - "$staging_dir"
rm -rf "$app_dir"
mv "$staging_dir" "$app_dir"
echo "Built $app_dir"
