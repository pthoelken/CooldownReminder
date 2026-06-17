# CooldownReminder

CooldownReminder is a lightweight World of Warcraft addon that shows a compact reminder when selected character spells are ready again.

## Features

- Choose learned cooldown spells from your current character spellbook.
- Add spells from an icon grid with normal in-game spell tooltips.
- Filter the grid with search when a spell is hard to find.
- Show ready reminders vertically or horizontally.
- Drag watched spells to define the fixed reminder order.
- Move and scale the reminder stack directly on screen.
- Optional spell names, sounds, load message, and top-most reminder behavior.
- Global monitoring toggle in the settings window or with `/cdr ac` and `/cdr ia`.
- Character-specific saved settings.
- Localized UI for English, Portuguese, Spanish, French, German, Italian, Russian, Simplified Chinese, Korean, and Traditional Chinese.

## Commands

- `/cdr` opens the CooldownReminder window.
- `/cdr test` shows a temporary reminder.
- `/cdr reset` resets the reminder position.
- `/cdr ac` enables cooldown monitoring.
- `/cdr ia` disables cooldown monitoring.

## Notes

CooldownReminder only lists spells that are known by the current character and have a meaningful cooldown or charges. Ready spells are shown immediately after adding them and again after reload if they are available.
