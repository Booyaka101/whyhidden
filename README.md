# WhyHidden

A small addon for the WoW Forever and Midnight clients that answers one question:
**why is that a "?"**

The modern client hands addons *secret values*. During restricted content (arenas,
battlegrounds, enclosed encounters) health, names, casting, auras, cooldowns and
threat come back hidden, so addons cannot make decisions for you. When your unit
frame shows a question mark where a number used to be, the game is not broken.
Something is secret, and until now the client never told you which part or why.

WhyHidden reads the client's own predicate API, `C_Secrets`, and reports exactly
what is hidden, for whatever you point it at. It cannot reveal hidden values and
does not try. It explains them.

## What you get

- **Mouse over anything** and, when something about it is actually hidden, the
  tooltip gains one line: `Hidden: health, stats` — with the context tagged on
  the line below (`WhyHidden · arena`). When nothing is hidden the tooltip stays
  exactly as it was.
- **`/whh`** prints a report: your context (arena, battleground, raid), whether
  your auras and action cooldowns are hidden, and a per-value breakdown for you
  and your target. `/whh mouse` (or `/whh m`) reports the mouseover instead,
  falling back to the target when there is none. A spell being cast **or
  channelled** counts as its own value: `current cast`.

Values that cannot be queried (the API is new and the Forever beta moves) show as
`unknown` rather than guessing.

## Install

Drop the `WhyHidden` folder into `Interface\AddOns\` and log in. On a client that
is not hiding anything the addon does nothing beyond a quiet check at login.

Works on the WoW Forever beta (interface 16001) and on Midnight retail clients
(12.1.0 and 12.1.5) with the secret-value system — the `C_Secrets` surface has
been verified identical on both live clients. On clients without `C_Secrets` it
stays inert.

## Why this exists

From the author of [wow-secret-lint](https://github.com/Booyaka101/wow-secret-lint),
the linter addon developers use to find secret-value breakage before it ships.
That tool tells developers which calls can go dark. This one tells players what
is dark right now. Same system, other side of the counter.

## Development

`npm install && npm test` executes the addon under a Lua VM against a stubbed
WoW client (13 assertion groups: login, tooltip gating, signature drift,
channels, color integrity). No game install needed.

## License

MIT
