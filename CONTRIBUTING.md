# Contributing to Huevora

Thank you for your interest in contributing. This document covers the process and standards we follow.

## Code of Conduct

- Be respectful and constructive in all interactions.
- Focus on technical merit. No personal attacks, harassment, or discrimination.
- Assume good faith.

## How to Contribute

### Reporting Bugs

1. Check existing issues first.
2. Provide a minimal reproduction case.
3. Include Dart version, OS, and dependency versions.
4. Include the full stack trace if applicable.

### Suggesting Features

1. Open an issue with the `enhancement` label.
2. Describe the use case, not just the solution.
3. Explain why existing APIs cannot solve the problem.


### Pull Requests

1. **Fork** the repository and create a feature branch.
2. **Write tests** for new behavior. All PRs must maintain or improve coverage.
3. **Follow conventions**: see [ONBOARDING.md](ONBOARDING.md) for code style, naming rules, and documentation contracts.
4. **Run the full test suite**: `dart test` must pass.
5. **Run analysis**: `dart analyze` must be clean.
6. **Run formatting**: `dart format .` must produce no changes.
7. **Update documentation**: README, API.md, and ARCHITECTURE.md if behavior changes.
8. **Update CHANGELOG.md** under `[Unreleased]`.

### PR Review Process

- All PRs require at least one review.
- CI must pass (tests + analysis + formatting).
- Breaking changes require major version bump discussion.

## Development Setup

```bash
git clone https://github.com/you/huevora.git
cd huevora
dart pub get
dart test
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
