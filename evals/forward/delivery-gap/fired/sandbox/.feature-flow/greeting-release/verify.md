# Verify: Localized greeting

## Commands run

| Command | Exit |
|---|---|
| `node src/cli.js --greeting hi` | 0 |
| `sqlite3 test.db < db/migrations/003_add_locale.sql` | 0 |

## Contract mapping

### AC1
Verified (single-source) — `node src/cli.js --greeting hi` exit 0, printed `hi`.

### AC2
Verified (single-source) — migration applied against a fresh DB, exit 0.

## Limitations & remaining risks

- Existing rows get `locale = 'en'` by default; no backfill from user settings.

## Verdict

Ready for done.
