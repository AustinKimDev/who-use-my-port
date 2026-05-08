# Security Policy

## Supported Versions

Security fixes are handled on the default branch until the project starts publishing versioned releases.

## Reporting A Vulnerability

Please open a private security advisory on GitHub if the repository supports it. If not, open an issue with a minimal description and avoid posting exploit details publicly.

## Local Data And System Commands

Who Use My Port is a local macOS utility.

- It reads live port/process information using local system tools such as `lsof` and `ps`.
- It may terminate processes only after an explicit user action.
- The `whoport` CLI stores local registration metadata at `~/Library/Application Support/WhoUseMyPort/registry.json`.
- The app does not require a network service for scanning or registry tracking.

Do not include private project paths, command arguments with secrets, or sensitive process output when filing public issues.
