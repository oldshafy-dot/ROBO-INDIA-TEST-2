# ROBO INDIA — iOS build

This source includes the initial ROBO INDIA authorization gate and a GitHub Actions workflow that packages an unsigned iOS IPA.

## GitHub build

1. Upload/push the repository contents to a GitHub repository.
2. Open **Actions** and run **Build Unsigned iOS IPA**, or push to `main`/`master`.
3. Open the completed workflow run and download the `ROBO-INDIA-IPA` artifact.

The workflow runs on a macOS GitHub runner with Xcode. The local execution environment used to prepare this archive does not include Xcode, so a successful iOS compile has not been claimed; verify the first GitHub Actions run and review `xcodebuild.log` if it fails.

## License verification

The app sends a POST request to the configured public verification endpoint with JSON fields `key` and `device_id`. Access is granted only when the server responds with HTTP 2xx, `success: true`, `valid: true`, `status: "active"`, and a future `expires_at` timestamp. The expiration countdown uses the returned server expiry and access is removed locally when the timer expires. Saved keys are re-verified online when the app becomes active.

## Important

An unsigned IPA is not signed for direct installation. It must be signed through an appropriate legitimate signing workflow before installation on a physical device. Keep the existing bundle identifier unchanged because the project documents functionality that depends on it.
