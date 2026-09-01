# Triage Labels

The skills speak in terms of five canonical triage roles. `knot` has no generic "label" field, so each role maps onto its `tags` or `mode` frontmatter instead.

| Role in mattpocock/skills | Represented in knot | How to apply |
| --- | --- | --- |
| `needs-triage` | tag `needs-triage` | `knot update <id> --add-tag needs-triage` |
| `needs-info` | tag `needs-info` | `knot update <id> --add-tag needs-info` |
| `ready-for-agent` | `mode: afk` | `knot update <id> --mode afk` |
| `ready-for-human` | `mode: hitl` (repo default) | `knot update <id> --mode hitl` |
| `wontfix` | tag `wontfix` + `status: closed` | `knot update <id> --add-tag wontfix`, then `knot close <id> --summary "wontfix: ..."` |

`ready-for-agent`/`ready-for-human` are never literal tags — they're the pre-existing `mode` field. Query examples: `knot list --tag needs-info`, `knot list --mode afk`, `knot list --tag wontfix --status closed`.
