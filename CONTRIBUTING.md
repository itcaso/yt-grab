# Contributing to YT-Grab

Thank you for helping improve YT-Grab.

1. Open an issue before starting a substantial change.
2. Create a focused branch from `main`.
3. Keep user-facing text localized in both `en.lproj` and `es.lproj`.
4. Run `swift test -j 2` before opening a pull request.
5. Do not introduce shell interpolation for user-provided URLs. Use `Process.executableURL` and argument arrays.
6. Confirm that your contribution may be distributed under the repository license.

Downloads must remain limited to content the user owns or is authorized to save.

## Optional end-to-end test

The normal test suite does not access the network. To verify real audio and video output against media you own or are authorized to use, serve that media over HTTP and run:

```sh
YT_GRAB_E2E_URL="http://127.0.0.1:8000/authorized-demo.mp4" \
  swift test -j 2 --filter authorizedLocalMediaDownloadsAsAudioAndVideo
```

This test downloads MP3 and MP4 outputs, checks that they are nonempty, and asks FFmpeg to decode the audio stream plus the final video's audio and video streams.

## Publishing a release

Maintainers should update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, commit the change, and push a version tag:

```sh
git tag v1.1.0
git push origin main --tags
```

The Release workflow runs the tests, builds a universal Intel and Apple Silicon application, verifies its signature, and publishes both `YT-Grab-macOS-universal.dmg` and `YT-Grab-macOS-universal.zip` plus their SHA-256 files. The download buttons in both README files always point to the newest published assets.
