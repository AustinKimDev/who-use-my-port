# Who Use My Port

A macOS utility for finding which process is using a port or port range, inspecting process details, and terminating processes when needed.

The top-right macOS entry point is a menu bar item / status bar item. In SwiftUI this is implemented with `MenuBarExtra`; it is not a macOS widget.

## Build

Open `WhoUseMyPort.xcodeproj` in Xcode and build the `WhoUseMyPort` scheme.

Command line:

```sh
xcodebuild -project WhoUseMyPort.xcodeproj -scheme WhoUseMyPort -configuration Debug -derivedDataPath DerivedData build
```

## Usage

Enter a port query such as:

- `3000`
- `3000-3010`
- `3000, 5000-5010`

The app uses macOS system tools (`lsof`, `ps`, and `kill`) and may need elevated permissions outside the app for processes owned by other users.
