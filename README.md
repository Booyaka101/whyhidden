# WhyHidden

A small addon for the WoW Forever and Midnight clients that answers one question:
**why is that a "?"**

The modern client hands addons *secret values*. During restricted content (arenas,
battlegrounds, enclosed encounters) health, names, casting, auras, cooldowns and
threat come back hidden, so addons cannot make decisions for you. When your unit
frame shows a question mark where a number used to be, the game is not broken.
Something is secret, and until now the client never told you which part or why.

WhyHidden reads the client's own predicate API, `C_Secrets`, and reports which
checked categories are hidden, for whatever you point it at. It cannot reveal
hidden values and does not try. It explains them.

## What you get

- **Mouse over anything** and, when something about it is actually hidden, the
  tooltip gains one line: `Hidden: max health, stats` with the context tagged on
  the line below (`WhyHidden · arena`). When nothing is hidden the tooltip stays
  exactly as it was.
- **`/whh`** prints a report: your context (arena, battleground, raid, dungeon), whether
  your auras and action cooldowns are hidden, and a per-value breakdown for you
  and your target. `/whh mouse` (or `/whh m`) reports the mouseover instead,
  falling back to the target when there is none. A spell being cast **or
  channelled** counts as its own value: `current cast`.
- **`/whh help`** (or `/whh ?`) shows command usage without needing the secret API.

Values that cannot be queried (the API is new and the Forever beta moves) show as
`unknown` rather than guessing.

The health check covers **maximum health**, not current health. The general
casting, aura and cooldown predicates describe categories, not every spell's
exceptions. "Nothing hidden in checked values" is not a guarantee that every
client value is public. Build support for secret values does not mean every
restriction is currently active. Instance labels describe location, not proof
of an active encounter.

Secret or unreadable names fall back to unit tokens such as `target`. Secret
cast metadata is left uninspected and counted as unknown. Tooltips show a partial
query's unknown count when at least one category is known to be hidden; otherwise
they stay silent. `/whh` distinguishes an unavailable API from a confirmed
`HasSecretRestrictions = false` result.

## Install

Drop the `WhyHidden` folder into `Interface\AddOns\` and log in. Use `/whh help`
for commands.

Targets the WoW Forever beta (interface 16001) and Midnight retail clients
(12.1.0 and 12.1.5). Modern clients use unit-tooltip post-callbacks; older clients
use `OnTooltipSetUnit` only if supported. If neither hook exists, `/whh` still
works. Clients without `C_Secrets` get no login banner or tooltip annotations.
Compatibility is covered by simulated API tests; in-game verification on the
current client builds is still required.

## Why this exists

From the author of [wow-secret-lint](https://github.com/Booyaka101/wow-secret-lint),
the linter addon developers use to find secret-value breakage before it ships.
That tool tells developers which calls can go dark. This one tells players what
is dark right now. Same system, other side of the counter.

## Development

`npm ci` followed by `npm test` executes the addon under a Lua VM against a stubbed
WoW client (login, tooltip gating, signature drift, channels, color integrity).
The suite runs against modern, legacy, overlapping and unavailable tooltip APIs,
including clients that reject `OnTooltipSetUnit`. No game install needed.
Strict cast and stats signatures, unreadable names and casts, invalid predicate
results, help, instance context and event cleanup have regression coverage.
Secret-value sentinels test our guards, but do not emulate WoW's taint engine.

## License

MIT
