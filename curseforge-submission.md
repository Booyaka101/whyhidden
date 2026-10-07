# WhyHidden — CurseForge submission content (ready to paste)

- **Game:** World of Warcraft
- **Project type:** Addon
- **Name:** WhyHidden
- **Slug:** whyhidden
- **Authors:** Booyaka101
- **Summary:** Shows which values the client is hiding from addons right now, and why.
- **Categories:** Miscellaneous, Unit Frames tooltip-adjacent → pick "Miscellaneous" (primary); "Development Tools" optional but secondary — this is a player-facing explainer, not a dev tool.
- **License:** MIT (LICENSE file in zip)
- **Supported game versions:** WoW Forever (1.60.1 beta) + Retail 12.1.0 / 12.1.5 — one file, both flavors (TOC: 16001, 120100, 120105).
- **File:** WhyHidden-0.3.0.zip (attached to the GitHub release)
- **Changelog:** paste from https://github.com/Booyaka101/whyhidden/releases/tag/v0.3.0

## Description (paste into the description field)

The Midnight and Forever clients hand addons "secret values": health, names, casting, auras, cooldowns and threat come back hidden during restricted content (arenas, battlegrounds, enclosed encounters), so addons cannot make decisions for you. When a unit frame shows a question mark where a number used to be, the game is not broken — something is secret, and until now the client never told you which part or why.

WhyHidden reads the client's own predicate API (C_Secrets) and reports exactly what is hidden, for whatever you point it at. It cannot reveal hidden values and does not try. It explains them.

Mouse over anything: when something about it is actually hidden, the tooltip gains one line — Hidden: health, stats — with the context tagged below (WhyHidden · arena). When nothing is hidden, the tooltip stays exactly as it was.

/whh prints a report: your context, whether your auras and action cooldowns are hidden, and a per-value breakdown for you and your target. /whh mouse (or /whh m) reports the mouseover, falling back to your target. A spell being cast or channelled counts as its own value.

Runs on the WoW Forever beta and on Midnight retail (12.1.0 and 12.1.5); the C_Secrets surface has been verified identical on both live clients. Inert on clients without secret values. From the author of wow-secret-lint.

## Steps (2 minutes, needs your CurseForge login)

1. Sign in at curseforge.com
2. Start a Project → World of Warcraft → Addon
3. Paste name/slug/summary, pick Miscellaneous, MIT
4. Upload WhyHidden-0.3.0.zip, mark game versions: Forever 1.60.1, Retail 12.1.0 + 12.1.5
5. Paste the description above, submit for review
