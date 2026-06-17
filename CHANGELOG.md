# Changelog

## Unreleased

Changes since GitHub release `v1.7.1`.

### Changed

- `CDR.VERSION` is now read from the `## Version` metadata in `CooldownReminder.toc`, so the addon version only needs to be maintained there.
- The README version badge now follows the latest GitHub release instead of using a hardcoded version number.
- The release workflow now uses `CHANGELOG.md` for CurseForge and GitHub release notes.
- Cooldown scans, cast probes, and reminder UI refreshes are now batched to reduce event pressure during busy combat.
- Cast follow-up probes now target the affected watched spell and ignore stale callbacks after newer casts.

### Fixed

- Release packages now include the embedded `Libs/Ace3` directory referenced by `CooldownReminder.toc`.
- Charge-based reminders no longer keep a stale `0` overlay after a charge becomes available.
- Ready fallback timing now adapts to updated cooldown and charge remaining times instead of relying on stale base cooldown estimates.
- Watched spells are no longer marked ready during combat when the WoW API briefly reports an empty cooldown state while the fallback ready time is still in the future.
