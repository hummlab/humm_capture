# Contributing

## Scope

Keep the public package API small and backend-neutral. Do not add Firebase, authentication, analytics, Hub secrets or
host-specific storage to this package.

## Code structure

- Keep public exports in `lib/humm_capture.dart`.
- Put implementation details in `lib/src/`.
- Keep a focused widget or implementation file below 400 lines. Extract a meaningful component instead of using `part`
  files to hide length.
- Use immutable typed models and document every public API member.

## Before opening a change

```bash
fvm dart format .
fvm dart analyze lib test example/lib
fvm flutter test
fvm dart pub publish --dry-run
```

Add tests for public data contracts, delivery mapping, and user-visible capture or composer behavior when that behavior
changes.
