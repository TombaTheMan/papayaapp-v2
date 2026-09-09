# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Version control — auto-commit & push

Every change to this project is committed and pushed automatically:

- A **Stop hook** in `.claude/settings.json` runs `scripts/auto-commit.sh` after each
  session. The script stages everything, commits only if something changed
  (message `Auto-commit: <timestamp>`), and pushes when a git remote exists.
- **Also commit and push explicitly** whenever you finish a meaningful unit of work —
  don't rely solely on the Stop hook. Use a descriptive message for those; the hook's
  timestamped commits are just a safety net for anything left uncommitted.
- Remote is GitHub (`gh`-based). If `git push` fails because no remote is set, tell the
  user to run `gh repo create` / add the `origin` remote; don't treat it as fatal.

## What this is

**Host Ops** — a staff web app for managing check-ins/check-outs at short-term rental
apartments in Novalja. Two roles: **worker** (on-site guest handling) and **admin**
(creates bookings and apartments). Standalone from the existing booking-management app.

The entire application is one file: **`host-ops/index.html`** (~790 lines: inline
`<style>` + inline `<script>`, no external assets). No framework, no build step, no
package manager, no dependency, and this directory is not a git repo.

## Running & testing

- **Run:** open `host-ops/index.html` directly in a browser. Some tooling (the Chrome
  automation extension) refuses `file://` — serve instead: `python -m http.server 8777`
  from `host-ops/`, then open `http://localhost:8777/`.
- **Tests:** no framework. `selfTest()` at the bottom of the script runs the money/date
  logic (`nightsBetween`, `touristTax`, `recDeposit`, `eur`) on load and logs `✓`/`✗` to
  the browser console. Extend that function when touching those helpers.
- **Reset state:** append `?reset` to the URL — clears the `hostops_db` key and re-seeds.
- **Demo logins:** `maria` / `maria123` (worker), `admin` / `admin123` (admin).

## Architecture

**State** lives in four module-scoped variables in the script: `db`
(`{apartments, bookings}`, persisted to `localStorage["hostops_db"]`), `session`
(`localStorage["hostops_session"]`), `route`, `selectedDate`. `render()` rebuilds the
whole `#app` innerHTML from these on every change. `openApts` (a `Set`) keeps
apartment-card expansion state across re-renders.

**Events are fully delegated on `document`** (`click` / `input` / `change` / `submit`),
attached once — never re-wired after a render. Handlers dispatch on `data-action` /
`data-field` attributes. Consequence: new interactive markup must carry those attributes,
not inline handlers.

**Field edits deliberately do NOT trigger `render()`.** Typing into a booking's
tax-count / deposit / notes input persists via the `change` handler and updates only the
sibling `[data-tax-total]` node via the `input` handler. A full re-render here would
steal focus mid-edit. Only route/date/zone/status changes and create-dialog submits
re-render.

**Seed data is generated relative to `new Date()`** (`seedDB()` uses `addDays(today, n)`)
so the "Today" view always has content. Dates are handled as `YYYY-MM-DD` strings via
local-time helpers (`fmtISO`, `addDays`) — never `toISOString()`, which would shift the
day in +02:00.

**Role gating:** `isAdmin()` guards the `+` create buttons and the per-apartment status
`<select>`; workers get a read-only status pill. Both roles otherwise see the same
screens.

**Theme:** CSS custom properties on `:root`, with the dark palette duplicated under both
`@media (prefers-color-scheme: dark)` and `:root[data-theme="dark"]`. Default follows the
OS; the toggle writes `localStorage["hostops_theme"]` and re-renders. Keep the two dark
blocks in sync when editing colors.

**Icons** are inline SVG strings in the `I` object (single stroke weight, `currentColor`).

## Editing hot spots

- **Accounts:** `ACCOUNTS` array near the top of `<script>`. Marked with a `ponytail:`
  comment — plaintext, no backend; a real deployment needs a server + hashed passwords.
- **WhatsApp / greeting copy:** the `MESSAGES` object. `checkin` is a fixed template
  (worker name + apartment `town`); `checkout` is free to reword.
- **Tax rule:** `TAX_RATE` (€1.60) and `TAX_FREE_AGE` (12) constants; math in
  `touristTax()` / `nightsBetween()`.
- **`[hidden]{display:none!important}`** in the reset is load-bearing — the
  `label.f{display:block}` rule otherwise overrides `hidden` and leaks the
  conditional "Agency name" field.
