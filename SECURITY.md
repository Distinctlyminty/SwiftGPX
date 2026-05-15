# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 0.1.x | :white_check_mark: |

While SwiftGPX is in 0.x, only the most recent minor receives security fixes.
Once 1.0 ships, this table will be updated.

## Reporting a vulnerability

**Please do not file public issues for security vulnerabilities.**

To report a vulnerability privately:

1. Open a [GitHub Security Advisory](https://github.com/Distinctlyminty/SwiftGPX/security/advisories/new) on this repo, **or**
2. Email `security@sailr.co.uk` with details.

You can expect:
- An acknowledgement within 5 business days.
- A status update within 14 business days.
- Coordinated disclosure: once a fix is ready, we'll agree a public-disclosure
  date with you before publishing the advisory.

## Threat model

SwiftGPX parses XML from arbitrary external GPX files. Treat any reported
issue that involves crashing, hanging, infinite recursion, excessive memory
use, or arbitrary code execution from a crafted GPX input as in-scope.
