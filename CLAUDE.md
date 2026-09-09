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

**Papaya Travel** (formerly "Host Ops") — a staff web app for managing check-ins/check-outs
at short-term rental apartments in Novalja, plus a weekly worker Schedule (zone assignments,
shift hours, night shift). Two roles: **worker** (on-site guest handling, read-only Schedule)
and **admin** (creates bookings/apartments, manages user accounts on the admin-only Users
page, edits the Schedule). Standalone from the existing booking-management app.

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
- **Reset state:** append `?reset` to the URL — clears the `hostops_db` and `hostops_accounts`
  keys and re-seeds both.
- **Demo logins:** `maria` / `maria123` (worker), `admin` / `admin123` (admin). Admins can
  add/edit accounts and promote/demote roles from the Users page; changes persist to
  `localStorage["hostops_accounts"]` and flow straight into the existing login lookup.
  The Schedule seed data references 7 more worker accounts (`anja`, `tea`, `toma`, `jasna`,
  `fran`, `toni`, `armin` — password `<username>123`), also from `seedAccounts()`.

## Architecture

**State** lives in module-scoped variables in the script: `db`
(`{apartments, bookings, schedule}`, persisted to `localStorage["hostops_db"]`), `ACCOUNTS`
(persisted to `localStorage["hostops_accounts"]`, seeded from `seedAccounts()`), `session`
(`localStorage["hostops_session"]`), `route`
(`"checkinout" | "apartments" | "schedule" | "users"`), `selectedDate`, `activeZone`
(shared by the Apartments zone tabs and the Check in/out zone switcher), `scheduleWeekStart`.
`render()` rebuilds the whole `#app` innerHTML from these on every change. `openApts` (a
`Set`) keeps apartment-card expansion state across re-renders.

**`db.schedule`** is keyed by week-start ISO date (Monday, via `mondayOf()`):
`{ [monday]: { zones: {1:[row...], 2:[...], 3:[...]}, night: {[date]: username} } }`, where
each zone row is `{ username, days: {[date]: "H:MM - H:MM" | "H:MM - H:MM // H:MM - H:MM" | "FREE"} }`.
A worker's zone is fixed for the row's whole week; only the per-day cell value changes.
Weeks are created lazily on first edit (`ensureScheduleWeek()`); reading an unedited week
(`getScheduleWeek()`) returns an empty in-memory skeleton without writing to `db`, so
browsing past/future weeks doesn't litter storage. `loadDB()` patches `schedule: {}` onto
any pre-Schedule-feature saved data.

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
`<select>`; workers get a read-only status pill. The Users page (`screenUsers()`) is
admin-only end to end: hidden from `bottomNav()`, and `screenUsers()` itself falls back to
the check-in/out screen if reached with a non-admin session. `route` resets to `"checkinout"`
on logout so a worker who logs in next doesn't land on a stale admin route. The Schedule page
is visible to both roles (workers see it read-only — no `data-action` on its cells, so
nothing is clickable) but every cell/row edit control checks `isAdmin()` individually rather
than gating the whole screen, since workers still need to read it. Otherwise both roles see
the same screens.

**Zone concept is shared** between apartments (`apartment.zone`), the Check in/out zone
switcher, and Schedule's zone groupings — all just the numbers 1/2/3, cross-referenced via
`workerZone(username)` (searches this week's `db.schedule` for a row with that username).
A worker's Check in/out zone tabs glow green (their assigned zone) / orange (others) via
`workerZone()`; admins aren't assigned a zone so get plain tabs. Login also defaults
`activeZone` to the logging-in worker's assigned zone.

**Theme:** CSS custom properties on `:root`, with the dark palette duplicated under both
`@media (prefers-color-scheme: dark)` and `:root[data-theme="dark"]`. Default follows the
OS; the toggle writes `localStorage["hostops_theme"]` and re-renders. Keep the two dark
blocks in sync when editing colors.

**Icons** are inline SVG strings in the `I` object (single stroke weight, `currentColor`).

## Editing hot spots

- **Accounts:** default 3 accounts come from `seedAccounts()` near the top of `<script>`;
  the live list is the module-scoped `ACCOUNTS` (loaded/saved via `loadAccounts()` /
  `saveAccounts()`), mutated in place by the Users page so the unchanged login lookup
  (`ACCOUNTS.find(...)`) keeps working. Marked with a `ponytail:` comment — plaintext, no
  backend; a real deployment needs a server + hashed passwords.
- **WhatsApp / greeting copy:** the `MESSAGES` object. `checkin` is a fixed template
  (worker name + apartment `town`); `checkout` is free to reword.
- **Tax rule:** `TAX_RATE` (€1.60) and `TAX_FREE_AGE` (12) constants; math in
  `touristTax()` / `nightsBetween()`.
- **`[hidden]{display:none!important}`** in the reset is load-bearing — the
  `label.f{display:block}` rule otherwise overrides `hidden` and leaks the
  conditional "Agency name" field.
