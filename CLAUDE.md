# CLAUDE.md

## UI layout

- Every UI screen must fit on a single page with no scroll bar. Never add a ScrollContainer (or let content overflow) to make things fit - the only exception is the "Vault".
- If a screen has too much content, split it into separate pages/views (tabs, steps, or sub-screens) instead of scrolling.

## Skill icons

- No two skills may share an icon (emblem), and no Birthstone may share one with a skill or another Birthstone. A new skill gets a new drawing in `view/gems/gem_icons.gd` (`SKILL_EMBLEMS` and `_emblem_shapes`); a Birthstone's is its `emblem` in `content/deep_cut.json`. `tests/test_view.gd` checks this.
- Several emblem drawings double as interface icons (`loupe`, `gem`, `reroll`, `copy`, `spark`, `flame`, ...). A redrawn skill emblem gets a new glyph name instead of editing a shared drawing, so the interface icon does not change with it.

## New skill gems: approve before implementing

- Before implementing any new skill gem (or Birthstone), put the whole proposal in an artifact for review and wait for every part to be approved. Do not write code or content until then.
- Icon: offer 3 different emblem options, drawn as `gem_icons.gd` shapes and shown the way the game renders them (flat mark at full and small sizes, and on the cut stone where possible). The user picks one or flags all of them for regeneration, with or without a comment.
- Everything else gets approve / reject / comment controls of its own: name, color, rarity, card text, activation requirement (trigger and Cut ladder), effects and numbers, and the Flawless line.
- Revise whatever was rejected or commented on, show the new version in the same artifact, and repeat until everything is approved. Then implement.
- Redrawing an existing emblem follows the same loop: 2-3 options per flagged emblem, pick one or flag again.
