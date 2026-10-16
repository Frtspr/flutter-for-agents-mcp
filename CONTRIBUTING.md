# Contributing to Flutter Sanity MCP

Thank you for your interest in contributing to `flutter-sanity-mcp`!

## Development Setup

1. **Prerequisites**: Dart SDK `>=3.5.0` and Flutter SDK.
2. **Clone the repository**:
   ```bash
   git clone https://github.com/Frtspr/flutter-sanity-mcp.git
   cd flutter-sanity-mcp
   dart pub get
   ```

## Running Tests

Before submitting a pull request, verify that all tests pass and static analysis produces zero warnings:

```bash
dart test
dart analyze --fatal-infos
```

## Running the Benchmark Suite

To measure compression ratio and token savings across the Chamber of Horrors testbed:

```bash
dart run benchmark/run_benchmark.dart
```

## Architecture Principles

* **Zero External Dependencies**: Pure Dart stdio server. No Python, Node.js, or native binaries required.
* **Deterministic Guardrails**: All heuristics and failure fingerprints must be reproducible and stable across line shifts.
* **Non-Destructive CLI Config**: `bin/setup.dart` must always backup existing configurations before modifying.
