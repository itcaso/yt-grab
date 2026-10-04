# Contributing to YT-Grab

Thank you for helping improve YT-Grab.

1. Open an issue before starting a substantial change.
2. Create a focused branch from `main`.
3. Keep user-facing text localized in both `en.lproj` and `es.lproj`.
4. Run `swift test -j 2` before opening a pull request.
5. Do not introduce shell interpolation for user-provided URLs. Use `Process.executableURL` and argument arrays.
6. Confirm that your contribution may be distributed under the repository license.

Downloads must remain limited to content the user owns or is authorized to save.

## Publishing a release

Maintainers should update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, commit the change, and push a version tag:

```sh
git tag v1.1.0
git push origin main --tags
```

The Release workflow runs the tests, builds a universal Intel and Apple Silicon application, verifies its signature, and publishes both `YT-Grab-macOS-universal.dmg` and `YT-Grab-macOS-universal.zip` plus their SHA-256 files. The download buttons in both README files always point to the newest published assets.
