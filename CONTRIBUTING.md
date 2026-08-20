# Contributing to Flunner

Thank you for your interest in contributing to **Flunner**! We welcome contributions ranging from bug reports and documentation fixes to feature proposals and code contributions.

---

## Code of Conduct

All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please be kind, respectful, and constructive in all interactions.

---

## Development Setup

### Prerequisites
- **macOS 15.0+ (Sequoia)**
- **Xcode 16.0+**
- **Swift 5.9+**
- **Flutter SDK 3.0+**
- *(Optional)* [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Building the Project

1. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/flunner.git
   cd flunner
   ```

2. Build and run:
   ```bash
   ./script/build_and_run.sh
   ```

3. Run the test suite:
   ```bash
   swift test
   ```

---

## Code Guidelines

- **Swift Concurrency**: Flunner enforces `StrictConcurrency = YES` (`-enable-bare-slash-regex`, `@MainActor`, `Sendable`). Avoid non-sendable types crossing actor boundaries.
- **SwiftUI Architecture**: Keep views declarative and lightweight. State mutations and async operations belong in dedicated services or Observable view models.
- **Native HIG**: Adhere to macOS Human Interface Guidelines. Favor standard system controls, proper accessibility labels, and keyboard navigability.
- **No Unused Dependencies**: Keep the dependency footprint minimal. External packages should be thoroughly vetted.

---

## Pull Request Process

1. Create a new topic branch from `main`:
   ```bash
   git checkout -b feature/my-feature
   ```
2. Write clean, focused code and add test coverage for new functionality under `Tests/FlunnerTests/`.
3. Verify that the entire test suite passes cleanly:
   ```bash
   swift test
   ```
4. Write clear, concise commit messages.
5. Push to your fork and submit a Pull Request describing your changes, motivation, and any UI changes (screenshots/GIFs are highly appreciated).

---

## Reporting Issues

- Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) template.
- Include your macOS version, Flutter version (`flutter --version`), and steps to reproduce.
- Check existing issues before opening a duplicate.
