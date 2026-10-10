# WoW Ecosystem Quality Report — 2026-10-10

## Verification Matrix (all green)

| Check | wow-secret-lint | WhyHidden | ClearCombatText | wow-addon-sim |
|---|---|---|---|---|
| Unit tests (fengari/vitest) | 305/305 | ALL PASSED | ALL PASSED | n/a (is the test) |
| wow-secret-lint static | self-lints clean | 0 errors, 0 warnings | 0 errors, 0 warnings | n/a |
| wow-addon-sim runtime | n/a | CLEAN | CLEAN | n/a |
| lint:self | 0 errors, 0 warnings | n/a | n/a | n/a |
| validate:action | valid | n/a | n/a | n/a |
| Security scan | clean (npm-published) | clean | clean | clean* |
| GitHub release | v1.9.2 ✓ | v0.3.0 ✓ | v0.3.1 ✓ | v0.1.0 ✓ |
| npm | 1.9.2 live | n/a | n/a | n/a |
| CurseForge | n/a | #1731223 Approved | #1736875 Under Review | n/a |
| CI (GitHub Actions) | ✓ (8 jobs) | ✓ (added) | ✓ (added) | ✓ (added) |

*wow-addon-sim false positives are WoW API names from the client capture (BNTokenFindName, WowTokenRedemptionFrame_*, etc.)

## Infrastructure Added This Session

- CI workflows for WhyHidden, ClearCombatText, and wow-addon-sim
  (fengari harness tests + wow-secret-lint + cross-repo sim checks)
- wow-addon-sim: headless addon simulator with real API surface stubs

## Known Outstanding Items

1. ClearCombatText CF 0.3.1 file stuck in "Uploading" with incomplete game versions
   (12.1.0 only; 1.60.1 and 12.1.5 didn't bind on submit) — fix when project is approved
2. Both addons still need their first live login test (two minutes in-game)
3. wow-secret-lint 07af5e3 (comment-only demand-load caveat) went to main without a PR — noted
