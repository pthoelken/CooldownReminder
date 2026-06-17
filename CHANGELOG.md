# Changelog

## Unreleased

Changes since GitHub release `v1.7.1`.

### Changed

- `CDR.VERSION` is now read from the `## Version` metadata in `CooldownReminder.toc`, so the addon version only needs to be maintained there.
- The README version badge now follows the latest GitHub release instead of using a hardcoded version number.
- The release workflow now uses `CHANGELOG.md` for CurseForge and GitHub release notes.

### Fixed

- Release packages now include the embedded `Libs/Ace3` directory referenced by `CooldownReminder.toc`.
