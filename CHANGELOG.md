# Changelog

## [1.7.7] - 2026-06-19

Changes since `1.7.6`.

### Added

- Added a reminder mode option with `PopUp Reminder` and `Time Reminder`.
- Added localized reminder mode labels and descriptions for all supported locales.
- Added an `About` section below Expert Settings with addon description, version, CurseForge link, GitHub link, and slash commands.

### Changed

- Cooldown readiness now follows the spell/charge state and the scheduled cooldown end before using action bar data as a fallback.
- Live icon matching is no longer used as an authoritative combat cooldown source, reducing false suppression from stale or shared action button icons.
- Time Reminder keeps watched spells visible while they are on cooldown, dims their icons, shows a native Blizzard cooldown swipe/countdown, and displays the remaining time.
- Ready transitions now store a short visual pulse window so Time Reminder can highlight newly ready spells while still using the normal ready sound.
- Moved reminder scaling plus reset and test buttons into the left navigation area to match the updated settings layout.
- Increased cooldown swipe contrast and enabled the cooldown edge so the radial timer is easier to see on dimmed spell icons.

### Fixed

- Ready spells should no longer stay hidden during heavy combat just because action button frames settle late after the actual cooldown has ended.
- Scheduled cooldown completions now bypass the extra combat confirmation delay once the spell API reports no remaining cooldown.
- Aligned the spell search label and input box to prevent the search field from appearing vertically offset.

## [1.7.6] - 2026-06-18

Changes since `1.7.5`.

### Added

- Added an Expert Settings section for cooldown timing values with localized names, descriptions, warnings, and a reset-to-defaults action.

### Changed

- Redesigned the custom options window with a left category navigation and a wider game-style settings layout.
- Refined the settings page spacing: language and layout dropdowns are stacked, full-width, and aligned with consistent label padding.
- Increased the spell grid width to reduce unused space in the spell selection view.
- Updated default cooldown timing values so ready reminders can react faster while still using confirmation windows.
- Release automation now publishes only the matching version section from `CHANGELOG.md` to GitHub Releases and CurseForge.

### Fixed

- Expert timing changes now apply immediately, refresh reminder state, and restart the ready scan ticker when needed.
- Top-row settings labels now keep their right-side padding instead of running into the panel border.

## [1.7.5] - 2026-06-17

Changes since `1.7.4`.

### Added

- Added `/cdr toggle` to switch cooldown monitoring on or off with one command.

### Changed

- Action bar cooldown checks now use a very short shared snapshot so heavy combat scans do not repeatedly walk every action slot per watched spell.
- Action button frame lists are cached separately from cooldown snapshots so combat event bursts do not repeatedly enumerate the whole UI.
- Action button frame discovery now uses targeted known button names instead of repeatedly enumerating every UI frame, removing periodic CPU spikes.
- Ready reminders now require a stable ready confirmation after cooldown fallback timers expire, preventing temporary all-spell flashes during combat API settle windows.
- Reminder rendering now also honors the last known cooldown block time, so stale ready flags cannot briefly display watched spells before their expected cooldown has elapsed.
- Confirmed ready action buttons can now clear stale fallback blocks quickly, reducing delayed reminders after the real cooldown has ended.
- Charge spells with at least one available charge now stay eligible for ready reminders while their next charge is recharging.
- Saved action bar slots are now rebuilt from the current bar state so stale slot links do not interfere with combat cooldown checks.
- Action bar ready shortcuts now require explicit usable-charge confirmation instead of a transient empty cooldown snapshot.

### Fixed

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

## [1.7.4] - 2026-06-17

Changes since `1.7.3`.

### Added

- Added Portuguese (Brazil), Italian, and Korean localizations.

### Changed

- The addon now loads the new `ptBR`, `itIT`, and `koKR` localization files from `CooldownReminder.toc`.
- README and description localization lists now include all 11 supported locales.

## [1.7.3] - 2026-06-17

Changes since `1.7.2`.

### Changed

- Cooldown scans, cast probes, and reminder UI refreshes are now batched to reduce event pressure during busy combat.
- Cast follow-up probes now target the affected watched spell and ignore stale callbacks after newer casts.

### Fixed

- Charge-based reminders no longer keep a stale `0` overlay after a charge becomes available.
- Ready fallback timing now adapts to updated cooldown and charge remaining times instead of relying on stale base cooldown estimates.
- Watched spells are no longer marked ready during combat when the WoW API briefly reports an empty cooldown state while the fallback ready time is still in the future.

## [1.7.2] - 2026-06-17

Changes since `1.7.1`.

### Added

- Embedded `Libs/Ace3` libraries are now loaded by `CooldownReminder.toc`.
- Added Ace3-backed Blizzard settings integration with the existing custom options window as fallback.

### Changed

- `CDR.VERSION` is now read from the `## Version` metadata in `CooldownReminder.toc`, so the addon version only needs to be maintained there.
- The README version badge now follows the latest GitHub release instead of using a hardcoded version number.
- The release workflow now uses `CHANGELOG.md` for CurseForge and GitHub release notes.

### Fixed

- Release packages now include the embedded `Libs/Ace3` directory referenced by `CooldownReminder.toc`.

## [1.7.1] - 2026-06-17

Changes since `1.7.0`.

### Added

- Ready reminders now show charge counts for charge-based spells.

### Changed

- Charge-based cooldown tracking now keeps an internal tracked charge state after casts.
- Cooldown, charge, and numeric helper functions now handle fragile WoW API return values more defensively.
- Release workflow handling was hardened for CurseForge upload validation and package generation.

### Fixed

- Fixed tainted cooldown charge handling for charge-based spells.
- Charge spells with available charges no longer stay hidden behind recharge cooldown checks.
- Ready reminders are rechecked against watched cooldown state before rendering, preventing stale reminder entries.
- `.DS_Store` is now ignored so local macOS metadata does not enter releases.

## [1.7.0] - 2026-06-17

Initial public release.
