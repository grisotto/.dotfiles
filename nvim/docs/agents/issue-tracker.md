# Issue Tracker: Knot

Issues and specs for this repo live as tickets tracked by the `knot` CLI, backed by markdown files under `.tickets/` (config: `.knot.edn`).

## Conventions

- Tickets are created with `knot create "<title>" [flags]` — one ticket = one markdown file under `.tickets/`, id format `nvi-<base32>`.
- Lifecycle: `status` is `open → in_progress → closed`. `knot start <id>` moves a ticket to `in_progress`; `knot close <id>` moves it to `closed` (terminal — files auto-archive to `.tickets/archive/`).
- `type` (bug/feature/task/epic/chore), `priority` (0-4, default 2), and `mode` (afk/hitl, default hitl) are first-class frontmatter fields — set at create time or later with `knot update <id> --type ... --priority ... --mode ...`.
- Anything not covered by a first-class field is recorded as a tag via `--tags`/`--add-tag`/`--remove-tag`; see `triage-labels.md` for the exact mapping.
- Relations: `knot dep <from> <to>` (blocking), `knot link <a> <b>` (symmetric), `--parent <id>` at create time for a sub-ticket of an umbrella.
- Notes/conversation history: `knot add-note <id> "..."` appends a timestamped note to the ticket file.

## When a skill says "publish to the issue tracker"

Run `knot create "<title>" -t <type> -p <priority> --mode <mode> -d "<description>"`. Add `--parent <id>` for sub-tickets, `--dep <id>` for blockers.

## When a skill says "fetch the relevant ticket"

Run `knot show <id>` (accepts an unambiguous id prefix). To find candidate work: `knot list`, `knot ready` (all deps closed), or `knot list --tag <tag> --mode <mode>`.

## When a skill says "apply the triage label X"

See `triage-labels.md` — most roles are a tag; `ready-for-agent`/`ready-for-human` are the `mode` field instead.

## PRs as a request surface

Off. This repo has no git remote and no PR workflow — knot tickets are the only request surface.
