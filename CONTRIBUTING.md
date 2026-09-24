# Contributing

Bug reports and focused improvements are welcome. Please describe the macOS
version, player, and media key involved when reporting a playback issue. Do not
include private logs or other personal data in a public issue.

## Changes

- Keep changes focused and compatible with the supported macOS workflow.
- Preserve existing Karabiner settings when changing installation behavior.
- Update the README when installation requirements or user-facing commands
  change.
- Run the existing router checks before submitting a code change:

  ```sh
  bash tests/test-router.sh
  ```
