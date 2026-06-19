# CooldownReminder

CooldownReminder is a lightweight World of Warcraft addon that tracks selected character cooldowns and shows a compact reminder when spells are ready again.

## Features

- Choose learned cooldown spells from your current character spellbook.
- Add spells from an icon grid with normal in-game spell tooltips.
- Filter the grid with search when a spell is hard to find.
- Show ready reminders vertically or horizontally.
- Use Time mode by default for persistent cooldown countdowns, or switch to PopUp mode for ready-only reminders.
- Drag watched spells to define the fixed reminder order.
- Move and scale the reminder stack directly on screen.
- Optional spell names, base cooldown numbers, sounds, load message, and top-most reminder behavior.
- Global monitoring toggle in the settings window or with `/cdr toggle`, `/cdr ac`, and `/cdr ia`.
- Character-specific saved settings.
- Localized UI for English, Portuguese, Spanish, French, German, Italian, Russian, Simplified Chinese, Korean, and Traditional Chinese.

## Commands

- `/cdr` opens the CooldownReminder window.
- `/cdr test` shows a temporary reminder.
- `/cdr reset` resets the reminder position.
- `/cdr toggle` toggles cooldown monitoring.
- `/cdr ac` enables cooldown monitoring.
- `/cdr ia` disables cooldown monitoring.

## Notes

CooldownReminder only lists spells that are known by the current character and have a meaningful cooldown or charges. Ready spells are shown immediately after adding them and again after reload if they are available. Optional base cooldown numbers appear on ready spell icons and stay out of the way while an active cooldown countdown is shown.
