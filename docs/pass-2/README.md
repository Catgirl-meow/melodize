# Pass 2 — Bug + design fixes

Each sub-item is a standalone file. Pick one up, execute, ship, move on.
Any session restart mid-pass can resume by reading just that one file.

| # | Topic | File | Status |
|---|-------|------|--------|
| 2a | Recommendations quality rewrite | [2a-recommendations.md](2a-recommendations.md) | in progress |
| 2b | Connection-error specificity on Home | [2b-connection-errors.md](2b-connection-errors.md) | pending |
| 2c | Download reliability + notifications | [2c-download-reliability.md](2c-download-reliability.md) | pending |
| 2d | `companionAvailableProvider` staleness | [2d-companion-freshness.md](2d-companion-freshness.md) | pending |
| 2e | Auto-download `'all'` idempotency | [2e-auto-download-idempotency.md](2e-auto-download-idempotency.md) | pending |
| 2f | Mini-player + dock design fixes | [2f-miniplayer-dock.md](2f-miniplayer-dock.md) | pending |
| 2g | Menu + visual-glitch triage | [2g-menu-triage.md](2g-menu-triage.md) | pending |

Ship order suggestion (smallest first → cheapest tokens, momentum):
`2d → 2e → 2a → 2b → 2c → 2f → 2g`

But the user asked to start with **2a** to benchmark Opus 4.7's output quality on a meaty item.

Each sub-plan has the same shape:

- **Current state** — what ships today, file:line citations.
- **Problems** — concrete issues the user called out + audit findings.
- **Proposal** — recommended approach (filled before implementation).
- **Open questions** — gaps that need user input, filled in as decisions arrive.
- **Files to touch** — targeted list so execution stays scoped.
- **Verification** — how we know it's actually working.
