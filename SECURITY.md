# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Huevora, please report it responsibly.

**Do NOT open a public issue.**

Instead, email security@huevora.dev (or the repository maintainer) with:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and work with you to verify and address the issue before any public disclosure.

## Security Considerations

Huevora is a pure Dart color computation library. It does not:
- Execute untrusted code
- Process user-uploaded files (beyond hex string parsing)
- Make network requests
- Access sensitive system resources

The primary security surface is input validation (hex strings, OKLCH channel values). All inputs are validated and clamped before use.
