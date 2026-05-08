# Contributing

Thanks for considering a contribution to Who Use My Port.

## Development Setup

1. Clone the repository.
2. Open `WhoUseMyPort.xcodeproj` in Xcode.
3. Build the `WhoUseMyPort` scheme.

Command-line build:

```sh
xcodebuild -project WhoUseMyPort.xcodeproj -scheme WhoUseMyPort -configuration Debug -derivedDataPath DerivedData build
```

Validate the CLI script:

```sh
python3 -m py_compile bin/whoport
```

## Pull Requests

- Keep changes focused on one behavior or documentation improvement.
- Match the existing SwiftUI, shell, and Python style.
- Include verification notes in the pull request description.
- Do not commit local build output, caches, personal paths, or generated registry data.

## Reporting Issues

When reporting a bug, include:

- macOS version.
- App version or commit SHA.
- Port query used.
- Whether the issue involves live process scanning, `whoport` registrations, or process termination.
- Any relevant `whoport check <port>` output with private paths redacted.
