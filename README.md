<div align="center">

# Flunner

### *A focused, native macOS workbench for the Flutter run–observe–reload loop.*

[![CI](https://github.com/stackwares/flunner/actions/workflows/ci.yml/badge.svg)](https://github.com/stackwares/flunner/actions/workflows/ci.yml)
[![macOS](https://img.shields.io/badge/macOS-15.0%2B%20Sequoia-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## ⚡ Overview

**Flunner** is a dedicated developer workbench crafted specifically for macOS. Instead of wrestling with bulky IDE tabs or terminal juggling, Flunner gives Flutter developers a calm, fast, and tactile instrument designed around the core loop: **build, run, observe logs, hot reload, and debug**.

Whether you're developing solo or pairing with AI coding agents, Flunner gives you instant, keyboard-driven runtime control over what gets built.

---

## ✨ Features

- ⚡️ **Instant Runtime Control** — Trigger Hot Reload (`r`) and Hot Restart (`R`) with zero latency. Live session indicators keep you informed of compilation and process state.
- 🪵 **High-Throughput Console** — Smooth multi-line selection, real-time search, timestamp toggling, and fast filtering by log level (`Info`, `Error`, `Command`).
- 💻 **Integrated PTY Terminal** — Built-in interactive terminal tabs powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) with full interactive shell support (`zsh`, `fvm`, `bash`).
- 📱 **Device & Emulator Management** — Automatic detection and launching of iOS Simulators, Android Virtual Devices (AVDs), macOS desktop targets, and Chrome web instances via Flutter daemon.
- 🌿 **Git & Source Control Sheet** — Native source control dialog to stage files, inspect unified diffs, compose commits, switch branches, and push without leaving the workbench.
- 🛠️ **Project Maintenance & SDK Diagnostics** — One-click `flutter pub get`, `flutter clean`, integrated `flutter doctor` diagnostics viewer, and quick access to Flutter / Dart documentation.
- 🎨 **Purpose-Built Design** — Native macOS HIG adherence, custom copper/graphite workbench aesthetics, light/dark appearance support, and custom font scaling.

---

## 📋 Requirements

- **macOS:** 15.0 (Sequoia) or newer
- **Flutter SDK:** 3.0+ (supports standard Flutter installs and [FVM](https://fvm.app))
- **Xcode:** 16.0+ (for building from source)
- **Swift:** 5.9+

---

## 🚀 Quick Start

### Download DMG Installer (Recommended)

1. Download the latest **`Flunner.dmg`** from [GitHub Releases](https://github.com/stackwares/flunner/releases/latest).
2. Open the disk image and drag **Flunner** to your **Applications** folder.
3. Launch Flunner from Applications or Spotlight.

> **Tip:** If macOS Gatekeeper alerts you when launching an ad-hoc signed build for the first time, right-click (or Control-click) `Flunner.app` in `/Applications` and click **Open**.

---

### Install via Homebrew

Install the macOS app via Homebrew Cask:

```bash
brew install --cask stackwares/tap/flunner
```

To upgrade later:
```bash
brew upgrade --cask flunner
```

---

### Building & Running from Source

Clone the repository and run the convenience script:

```bash
# Clone the repository
git clone https://github.com/stackwares/flunner.git
cd flunner

# Build and launch in Debug mode
./script/build_and_run.sh

# Package a Release DMG installer (.dmg & .zip in dist/)
./script/build_dmg.sh
```

### Using Swift Package Manager / Xcode

You can also build directly via SwiftPM or generate the Xcode project:

```bash
# Build via Swift CLI
swift build

# Run unit and integration tests
swift test

# (Optional) Generate Xcode project using XcodeGen
xcodegen generate
open Flunner.xcodeproj
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ R` | Run Project / Active Configuration |
| `r` | Hot Reload |
| `R` | Hot Restart |
| `⌘ .` | Stop Running Session |
| `⌃ \`` | Toggle Integrated Terminal Pane |
| `⌘ 2` | Open Source Control Sheet |
| `⌘ ,` | Settings |

---

## 🏗️ Architecture

Flunner is built using modern native Swift and SwiftUI patterns:

- **UI Layer:** Pure SwiftUI targeting macOS 15 with strict concurrency checking enabled.
- **Terminal Engine:** Integrated PTY shell sessions using [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).
- **Process Orchestration:** Robust asynchronous process runners communicating with the Flutter daemon JSON-RPC protocol over stdio.
- **Project Structure:** Dual-source configuration using `Package.swift` (SPM) and `project.yml` (XcodeGen).

```
Flunner/
├── Sources/
│   └── Flunner/
│       ├── Models/         # App state, devices, launch configs, daemon protocol
│       ├── Services/       # Flutter daemon, runner, Git client, terminal manager
│       ├── Views/          # Console, terminal, sidebar, controls, settings
│       └── Design/         # Design tokens, color palette, typography
├── Tests/
│   └── FlunnerTests/       # Unit and integration test suites
└── script/                 # Build, run, and log streaming automation
```

---

## 🤝 Contributing

Contributions from the community are warmly welcomed! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting a pull request.

1. Fork the repo and create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit your changes (`git commit -m 'Add amazing feature'`)
3. Ensure all tests pass (`swift test`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

Flunner is open-source software licensed under the [MIT License](LICENSE).

---

<div align="center">
Made with ❤️ by <a href="https://github.com/stackwares">Stackwares</a>
</div>
