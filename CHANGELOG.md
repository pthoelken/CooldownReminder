# Changelog

## Unreleased

Changes since GitHub release `v1.7.1`.

### Changed

- `CDR.VERSION` is now read from the `## Version` metadata in `CooldownReminder.toc`, so the addon version only needs to be maintained there.
- The README version badge now follows the latest GitHub release instead of using a hardcoded version number.
- The release workflow now uses `CHANGELOG.md` for CurseForge and GitHub release notes.
- Added Portuguese (Brazil), Italian, and Korean localizations.
- Cooldown scans, cast probes, and reminder UI refreshes are now batched to reduce event pressure during busy combat.
- Cast follow-up probes now target the affected watched spell and ignore stale callbacks after newer casts.
- Action bar cooldown checks now use a very short shared snapshot so heavy combat scans do not repeatedly walk every action slot per watched spell.
- Action button frame lists are cached separately from cooldown snapshots so combat event bursts do not repeatedly enumerate the whole UI.
- Action button frame discovery now uses targeted known button names instead of repeatedly enumerating every UI frame, removing periodic CPU spikes.
- Ready reminders now require a stable ready confirmation after cooldown fallback timers expire, preventing temporary all-spell flashes during combat API settle windows.
- Reminder rendering now also honors the last known cooldown block time, so stale ready flags cannot briefly display watched spells before their expected cooldown has elapsed.
- Confirmed ready action buttons can now clear stale fallback blocks quickly, reducing delayed reminders after the real cooldown has ended.
- Charge spells with at least one available charge now stay eligible for ready reminders while their next charge is recharging.
- Saved action bar slots are now rebuilt from the current bar state so stale slot links do not interfere with combat cooldown checks.
- Action bar ready shortcuts now require explicit usable-charge confirmation instead of a transient empty cooldown snapshot.
- Added `/cdr toggle` to switch cooldown monitoring on or off with one command.

### Fixed

- Release packages now include the embedded `Libs/Ace3` directory referenced by `CooldownReminder.toc`.
- Charge-based reminders no longer keep a stale `0` overlay after a charge becomes available.
- Ready fallback timing now adapts to updated cooldown and charge remaining times instead of relying on stale base cooldown estimates.
- Ready fallback timing now waits only for a short stable ready confirmation instead of blocking reminders until a stale fallback timestamp expires.
- Ready fallback timing now stays conservative during combat unless a matching action bar slot confirms the spell is ready.
- Pending ready callbacks no longer mark spells ready immediately from a single empty cooldown snapshot.
- Pending fallback times now hard-block ready transitions until the expected cooldown time has actually passed.
- Updated cooldown fallback times now replace older estimates instead of only extending them, preventing stale long blocks.
- Recharge timers for spells with available charges no longer suppress ready reminders.
- Charge spells are no longer marked ready immediately after a cast while cooldown and charge APIs are still settling.
- Visible action button cooldown frames are now read directly and matched by normalized icon keys, so ready reminders are suppressed when the UI button still shows a timer.
- Action button frame scanning now ignores unrelated UI frames with non-string names, preventing reload errors with damage meter entries and similar addons.
- Visible action bar cooldown timers now suppress ready reminders even when the underlying action still reports available charges.
- Watched spell status now cross-checks matching action bar icons so visible action bar cooldowns suppress incorrect ready reminders even when spell IDs or macro overrides are unstable.
- Non-charge spells no longer clear cooldown fallback blocks just because a matching action slot briefly reports no cooldown.
- Watched spells are no longer marked ready during combat when the WoW API briefly reports an empty cooldown state while the fallback ready time is still in the future.
