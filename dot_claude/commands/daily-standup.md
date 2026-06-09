---
name: daily-standup
description: Build a prioritized daily task list from GitHub, Jira, Slack, Gmail, and Calendar. Writes an Obsidian daily note with Tasks-compatible checkboxes.
---

# Daily Standup — Priority List

Build the user's prioritized task list for the day. Run all steps in parallel where possible, then compile into a prioritized Obsidian daily note and a draft standup message.

## Invocation

- **Normal**: `/daily-standup` — looks back 24–48 hours across all sources
- **Extended lookback**: `/daily-standup look back N days` (or `look back 1 week`, `look back 2 weeks`) — expands all lookback windows proportionally, suppresses staleness warnings, and adds a note at the top of the output explaining the extended window

**When an extended lookback is requested:**
- GitHub: search PRs updated in the last N days instead of the default 2
- Jira: expand JQL `updated` filters to `-Nd`
- Slack: scan channels for the last N days instead of 48 hours
- Gmail: expand search to last N days instead of 5
- Obsidian carry-overs: read all daily notes back N days instead of 7
- **Suppress all staleness warnings** (`⏰` stale waiter flags) — the user was away intentionally, not neglecting tickets
- Print at the top: `⚠️ Extended lookback: N days — staleness warnings suppressed`

## Vault configuration

- **Daily notes path**: `~/Documents/Obsidian/Daily/`
- **File format**: `YYYY-MM-DD.md` (e.g. `2026-06-09.md`)
- **Task format**: `- [ ] EMOJI Title #tag1 #tag2` with indented sub-lines for notes/links

## Configuration

Fill in these values to personalize the skill for a new user.

- **Name**: Saxon Unrue
- **GitHub username**: `joeunrue`
- **Jira account ID**: `712020:82b81f60-5b83-4b05-9c32-14e6bc2ef4ea`
- **Atlassian cloud ID**: `beaff86d-1d61-4688-9433-7b94c6fd3b96`
- **Slack user ID**: `U08A24T0789`
- **Email**: `saxon.unrue@callrail.com`

**QA team members** (used for nudge suggestions on stale QA tickets):
- Linh Cao — he/him
- Erica

**Slack channels to watch** (last 48 hours):
- `#team-integrations`
- `#epd-integrations-verticalization`
- `#epd-va-integrations`
- `#development`
- `#callrail`

**Standup channel** (for labeling the draft message at the end — print only, never post): `#team-integrations`

---

## Preflight — Verify all tools before doing anything else

**Run this first, before any other step. Do not proceed if critical tools are failing.**

Check each tool with a minimal call:

| Tool | Check |
|------|-------|
| GitHub CLI | `gh auth status` |
| Google Calendar | Call `mcp__claude_ai_Google_Calendar__list_calendars` |
| Jira | Call `mcp__claude_ai_Atlassian_2__atlassianUserInfo` |
| Slack | Call `mcp__claude_ai_Slack__slack_read_user_profile` with `user_id: "{slack_user_id}"` |
| Gmail | Call `mcp__claude_ai_Gmail__search_threads` with `query: "in:inbox"` |
| Obsidian vault | Check that `~/Documents/Obsidian/Daily/` exists |

Print a preflight report immediately:

```
## Preflight Check

✅ GitHub CLI — authenticated as {github_username}
✅ Google Calendar — connected
✅ Jira — connected
✅ Slack — connected
✅ Gmail — connected
✅ Obsidian vault — ~/Documents/Obsidian/Daily/ found
```

If any tool fails, replace ✅ with ❌ and a short reason (e.g. "needs re-auth", "not connected").

**If any critical tool is failing (GitHub, Jira, Slack, or Google Calendar), stop here.** Print:

```
⛔ Standup aborted — fix the failing tools above and re-run.
```

Do not proceed to the remaining steps. Obsidian vault and Gmail failures are non-critical — note them as degraded but continue.

---

## Step 0 — Calendar & carry-overs (run in parallel with everything else)

**Google Calendar**: Use `mcp__claude_ai_Google_Calendar` to fetch today's events. Surface:
- Any meetings in the next 8 hours and their times
- Any meeting that might need prep (1:1s, planning sessions, demos)
- Total focus time available between meetings

**If Calendar returns an empty events list on a weekday**, do not silently report "no meetings." Flag it explicitly: "⚠️ Calendar returned no events — possible auth issue. Verify manually." An empty result on a weekend is expected; on a weekday it likely means the integration failed silently.

**Obsidian carry-overs**: Read the last 7 daily note files in `~/Documents/Obsidian/Daily/`. Find any `- [ ]` incomplete tasks older than 3 days — these either need to be done today, moved forward, or deleted.

---

## Step 1 — PRs awaiting the user's review

Search GitHub for PRs where the user is in the review queue (directly or via a team):
```
gh api "search/issues?q=is:pr+is:open+review-requested:{github_username}&per_page=50"
```

For each result, fetch the full PR to inspect `requested_reviewers` and `requested_teams`:
```
gh api repos/{repo}/pulls/{num}
```

**Classify each into one of two buckets:**

- **Directly assigned** — `{github_username}` appears in `requested_reviewers`. These are the user's personal queue and are high priority.
- **Team queue** — only a team appears in `requested_teams` (the user is on that team but wasn't personally named). These are lower priority — the user should be aware but they're not blocking on him specifically.

Do not do a broad "no reviews in N days" sweep across repos — that surfaces PRs that have nothing to do with the user. The team queue bucket should only contain PRs where the user's team appears in `requested_teams`.

---

## Step 2 — the user's open PRs with actionable feedback

Search GitHub for the user's open PRs:
```
gh api "search/issues?q=is:pr+is:open+author:{github_username}&per_page=50"
```

For each PR, first fetch Jira status (`fields: ["summary", "status"]`) and CI status (`/repos/{repo}/commits/{sha}/check-runs`) in parallel. If Jira is already "Ready to Ship" and CI is green, **stop there** — classify as 🟢 and skip the comment/review scans entirely. No need to scan for CHANGES_REQUESTED or unresolved threads on a PR that's already cleared QA.

Only if Jira is NOT Ready to Ship, fetch reviews in parallel:
- `/repos/{repo}/pulls/{num}/reviews` — look for CHANGES_REQUESTED

Only fetch PR comments if the PR object shows `comments > 0` or `review_comments > 0` (both are in the search result). If both are 0, skip the comment calls — there's nothing to read:
- `/repos/{repo}/pulls/{num}/comments` — unresolved inline comments
- `/repos/{repo}/issues/{num}/comments` — requests from reviewers

**Jira workflow order** (for classification):
1. Unrefined / Planned — pre-dev. the user can start if assigned and requirements are clear.
2. **In Progress** — the user is actively building.
3. **Peer Review** — the user needs reviewers assigned and 1–2 approvals. the user IS the bottleneck.
4. QA Ready — QA's todo queue. the user is NOT the bottleneck.
5. QA Review — QA actively working. the user is NOT the bottleneck.
6. Product Review — waiting on product sign-off; almost a formality. the user is NOT the bottleneck.
7. **Ready to Ship** — merge the PR. 🟢
8. Shipped / Discontinued — terminal states.
("Buildable" is a legacy status — treat same as Planned if encountered.)

**Before classifying, check for blockers**: Scan the PR body and comments for dependency language ("blocked on", "depends on", "after #X merges", "waiting on #X", "once inti#X ships", etc.). For each referenced PR number, check its state via `gh api repos/{repo}/pulls/{num}` — if `state` is `open`, the PR is blocked. Also check if the PR's branch is behind a dependency branch that hasn't merged. If blocked, classify immediately as **Blocked** — do not proceed to other classification checks.

Classify each PR as one of:
- **Blocked** — has an explicit unmerged upstream dependency (another open PR or ticket it depends on). Set `when: anytime`. Notes should be minimal: just what it's blocked on + PR/Jira links. No action steps — there's nothing to do until the blocker ships.
- **Needs work** — has CHANGES_REQUESTED or unresolved inline comments that were added *after* the user's most recent commit push or re-review request
- **Awaiting re-review** — the user has already pushed commits and re-requested review after the last CHANGES_REQUESTED; now waiting on the reviewer. Not actionable for the user.
- **Ready to merge** — 2+ approvals, CI green, no open comments, AND linked Jira ticket is "Ready to Ship"
- **Approved, awaiting QA** — 2+ approvals and CI green, but Jira is "QA Ready" or "QA Review". the user is not the bottleneck — do not flag as actionable.
- **Awaiting product decision** — Jira is "Product Review". the user is not the bottleneck. Do not flag as actionable; reschedule any existing todo to `anytime`.
- **QA bugs filed** — Jira ticket has child issues in non-Done status filed *after* the PR was approved. The next action is not merging — it's resolving the bugs and moving the parent ticket back to QA Ready. Create a todo titled `🟠 CR-XXXXX — Move back to QA Ready` with the child bug tickets as checklist items.
- **Needs reviewer** — Jira is "Peer Review" but fewer than 2 approvals, no changes requested, **and `requested_reviewers` is empty** (no one assigned yet). If reviewers are already assigned but haven't reviewed yet, classify as **Awaiting review** instead — the user is not the bottleneck.
- **CI failing** — checks are failing, needs investigation
- **Awaiting review** — reviewers are assigned in `requested_reviewers` but haven't submitted a review yet. the user is not the bottleneck.

**Detecting QA bugs**: after identifying a CR number, fetch the Jira ticket with `fields: ["summary", "status", "subtasks", "issuelinks"]`. Check for child issues (subtasks or linked issues with type "is child of" / "QA Bug") that are not in Done/Shipped/Cancelled status. If any exist and were created after the PR's first approval, classify as **QA bugs filed** — not merge-ready.

**To determine "Needs work" vs "Awaiting re-review"**: compare the timestamp of the most recent CHANGES_REQUESTED review against the timestamp of the user's most recent push or review-request event. If the user pushed or re-requested review *after* the CHANGES_REQUESTED, it's "Awaiting re-review".

**To determine Jira status**: look for a CR number (e.g. `CR-12345`) in this order:
1. PR title or body
2. Branch name — fetch via `/repos/{repo}/pulls/{num}` and parse the `head.ref` field (e.g. `saxon/CR-49569_some_description` → `CR-49569`)

If a CR number is found either way, fetch the Jira ticket using `getJiraIssue` with `fields: ["summary", "status"]` only — that's all that's needed to classify the PR. Do not fetch the full issue.

If no CR number can be found in either the PR or the branch name, **do not treat the PR as ready to merge**. Instead, flag it as **Missing Jira ticket** and create a Things todo prompting the user to either link an existing ticket or create a new one before merging. This is a blocker.

---

## Step 3 — Jira tickets in flight

Run all three queries in parallel:

**Query A — Assigned to the user:**
```jql
assignee = currentUser() AND status in ("Unrefined", "Planned", "Buildable", "In Progress", "Peer Review", "QA Ready") AND issuetype != Epic ORDER BY updated DESC
```

**Query B — the user is the Developer (regardless of assignee):**
```jql
"Developer" = currentUser() AND status not in (Done, Shipped, Cancelled, Discontinued) AND issuetype != Epic ORDER BY updated DESC
```
This catches tickets where the user is listed as developer but someone else (e.g. QA) is the assignee. Deduplicate against Query A by ticket key.

**Query C — the user is @mentioned in comments in the last 3 days (regardless of assignee):**
```jql
comment ~ "{user_full_name}" AND updated >= -3d AND issuetype != Epic ORDER BY updated DESC
```
For each result, scan the comments to confirm the user is actually @mentioned (not just a coincidental name match), and check if the mention requires a response. Deduplicate against tickets already surfaced by Queries A or B — if the ticket is already in that set, just ensure the @mention is noted in the existing candidate rather than creating a separate one.

Use cloudId `{atlassian_cloud_id}`. Always pass `fields` as an array — never omit it, as the full issue response is ~100KB.

**Atlassian connector name**: The MCP connector may appear as either `mcp__claude_ai_Atlassian__` or `mcp__claude_ai_Atlassian_2__` depending on the session. Check which one responds during preflight and use that prefix consistently throughout the run. Both connectors expose the same tools — there is no functional difference.

**Atlassian response format**: The Jira MCP sometimes prepends a deprecation notice as the first element of the response array. Always check `.[0].type` — if it's `"text"` and the content starts with `[IMPORTANT:`, the actual data is at `.[1]`. Otherwise data is at `.[0]`. This avoids jq parse errors when processing responses.

Use:
- `searchJiraIssuesUsingJql`: `fields: ["summary", "status", "assignee", "priority", "updated", "parent", "issuetype", "customfield_10050"]` — **do not include `"comment"`** in the initial sweep; fetch comments lazily below
- `getJiraIssue` for detailed inspection (e.g. QA comment scan): `fields: ["summary", "status", "comment", "parent", "issuetype"]`
- `getJiraIssue` for PR classification only (Step 2): `fields: ["summary", "status"]`

**Lazy comment fetching**: After the JQL sweep, identify tickets where `updated >= 3 days ago`. For those tickets only, call `getJiraIssue` with `fields: ["summary", "status", "comment"]` to check for recent QA feedback or @mentions. Skip the comment fetch entirely for tickets with no recent activity — the `updated` timestamp is a reliable proxy.

For each ticket across all three queries, check:
- Any QA feedback or comments in the last 3 days? (Don't just look at status — QA often comments without changing status; use the lazy fetch above)
- Stale with no update in >5 days?
- Linked to a PR that's approved and ready to merge (cross-reference Step 2)?

Group by: **needs investigation** (includes @mentions needing a response), **has PR ready to merge**, **ready to start** (Buildable or Planned — the user has no open PR yet; surface as 🟠 High with a "Start work on CR-XXXXX" todo), **stale/needs update**, **blocked**.

If Query A returns no actionable tickets (or very few), look at the user's assigned epics and browse their child issues for something ready to pick up. The epic itself is never a task — a child ticket would be. Use:
```jql
assignee = currentUser() AND issuetype = Epic AND status != Done
```
Then fetch children via `gh api` or the Jira issue links. Only surface a specific child ticket as a suggestion, not the epic.

---

## Step 4 — Slack

Check the following in parallel:

**Direct messages** — search `to:me` in DMs, last 7 days. Skip bot messages (GitHub, Jira, Google Calendar). Flag anything that looks like it needs a reply.

**Channels to scan** (last 48 hours):
- `#team-integrations`
- `#epd-integrations-verticalization`
- `#epd-va-integrations`
- `#development`
- `#callrail`

For each channel, surface:
- Messages that @mention the user directly
- Technical discussions the user should weigh in on
- Announcements that affect the user's work (deploys, freezes, incidents, etc.)
- Skip social/celebration posts unless the user was called out

For any **open technical discussion** where the user's input is needed (architecture questions, design decisions, open-ended problems): spin off a subagent to research the question and draft a response. The subagent should:
1. Read the full Slack thread for context
2. Look at any referenced PRs, Jira tickets, or code
3. Form a genuine technical opinion — pick a side, don't just list tradeoffs
4. Return the output in this structure:

**the user's take** — written in first person, paste-ready for Slack. 2-4 sentences, clear recommendation, key reason.

**Supporting reasoning** — bullet points: tradeoffs, codebase precedent, failure modes, caveats.

**Verify before posting** — short list of things to double-check before committing to the opinion.

Add this to the todo notes so the user can review, edit, and paste directly to Slack if he agrees. Do not post to Slack automatically.

---

## Step 5 — Gmail

Search Gmail for unread or recent emails from the last 5 days using `mcp__claude_ai_Gmail__search_threads`.

**Skip / treat as low priority:**
- GitHub notification emails (PR comments, CI results) — already covered in Step 2 via API, which is structured and cheaper than parsing HTML email
- Jira bot emails — already covered in Step 3 via API; Jira notification emails are verbose HTML and cost more tokens to parse than a direct API call with field selection
- Automated alerts, marketing, newsletters, HR system emails
- `noreply@` / `no-reply@` addresses from **external** senders (outside callrail.com)

**Flag as actionable:**
- Direct emails from colleagues (`@callrail.com` addresses) that need a response
- Internal CallRail system emails (e.g. `do-not-reply@callrail.com`, `noreply@callrail.com`) — these are legitimate internal notifications (training enrollments, system alerts, etc.) and should be surfaced even though they come from a no-reply address
- Anything that looks like a customer escalation or stakeholder ask
- Calendar invites or meeting changes not already on the calendar

**Authenticity check for internal no-reply emails**: For any email from a `@callrail.com` no-reply sender, do a quick sanity check before surfacing it:
- Does the `mailed-by` domain match `callrail.com` or a known vendor (e.g. `training.knowbe4.com`, `workday.com`)? If the mailed-by domain is unexpected or unrecognized, flag as suspicious.
- Does the `signed-by` / DKIM domain match the expected sender for this type of email? A training email signed by `knowbe4.com` is expected; one signed by a random domain is not.
- Does the subject and content match what the sender would plausibly send (e.g. KnowBe4 sends training enrollments, Workday sends HR notifications)?
- If anything looks off — mismatched signing domain, unexpected sender for the content type, or spoofed display name — flag it explicitly as "⚠️ Possible spoofed email — verify before acting" rather than surfacing it as a normal action item.

Note: Gmail tools are read-only — cannot archive. Surface what needs action; the user handles cleanup manually.

**Known limitation**: GitHub and Jira notification emails are skipped (not archived) because the Gmail integration lacks write access. If inbox clutter is a concern, the cleanest fix is Gmail filters on `notifications@github.com` and Jira's notification sender to auto-archive before this script runs. The script does not rely on these emails for change detection — it queries GitHub and Jira APIs directly.

---

## Step 6 — Compile and add to Things

Synthesize everything into a prioritized task list. Use this priority framework:

| Priority | Emoji | Criteria |
|----------|-------|----------|
| Ship it | 🟢 | the user's own PR where Jira is "Ready to Ship" — just needs a merge |
| Urgent | 🔴 | Blocking someone, QA feedback, direct DM needing reply, direct review request, CI failing on your PR |
| High | 🟠 | CHANGES_REQUESTED on own PR, stale Jira with recent comment |
| Medium | 🟡 | Team queue PRs (not directly assigned), channel discussion to weigh in on, stale Jira no activity |
| Low | ⚪ | FYI items, no action needed today |

**Ready to Ship = 🟢**: When a Jira ticket linked to the user's own PR reaches "Ready to Ship" status, use 🟢 — not 🔴 or 🟠. These are happy, low-friction tasks; the hard work is done. Title format: `🟢 Merge CR-XXXXX — {repo}#{number} (Ready to Ship)`.

**Todo titles = the single next action the user owns**: Never write "Fix X then merge" or any multi-step sequence in a title. The title is only what the user does right now to move the ticket one step forward. Merging is never the user's next action unless QA has already signed off — if there are open QA bugs, the next action is "close bugs and move back to QA Ready" (or similar). The merge todo gets created later, once the ticket reaches Ready to Ship. Example: a PR with QA bugs fixed but not yet re-tested → `🟠 CR-XXXXX — Move back to QA Ready` (closing the child bug tickets is a checklist item, not a separate title action), not `🟠 Fix bugs then merge`. The 🟢 merge todo is for one thing only — merging. Any adjacent work (QA bug to file, follow-up ticket, post-merge investigation) goes in a **separate** todo at whatever priority it warrants. Do not bury follow-up actions inside the merge todo's checklist or notes.

**Directly assigned reviews** (the user named in `requested_reviewers`) → 🔴 Urgent or 🟠 High depending on staleness and whether someone is blocked. If CI is failing, create the todo but mark it as "waiting on CI" — not actionable until checks pass.

**Skip merged PRs**: Before creating any review todo, check `state` on the PR. If `state` is `closed` and `merged_at` is set, the PR is already merged — skip it entirely. No todo needed.

**Exception — many reviewers**: If the user is directly named but there are **5 or more** other reviewers also in `requested_reviewers`, drop the priority to 🟡 Medium — unless someone has @mentioned the user by name in a PR comment or review. Being one of 16 named reviewers is not the same as being personally needed.

**Team queue reviews** (the user's team named but not the user personally) → always 🟡 Medium. Group into a single "team review sweep" todo with a checklist. No pre-review needed. Each PR gets its own checklist item in the format `{repo}#{number} — {title} {url}`, ordered with the most integrations-relevant PRs first. Use `checklist_items` in `add_todo` (not plain text in notes) so they render as interactive checkboxes.

For each task, write a checkbox entry to today's daily note (`~/Documents/Obsidian/Daily/YYYY-MM-DD.md`):

```
- [ ] EMOJI Title #energy #time #context #work
  - Note line 1 (Jira link, PR link, etc.)
  - Note line 2
```

Blocked/anytime tasks go in an `## Anytime / Blocked` section instead of `## Tasks`. Today's actionable tasks go under `## Tasks`.

One task, one todo. Each discrete action gets its own todo — never combine separate PRs, tickets, or actions into a single todo just because they share a theme or belong to the same epic. If each item could stand alone as something to check off, make it its own todo. Checklist items inside a todo are fine for true sub-steps of a single indivisible action only.

**In-progress DRAFT PRs always get a todo**: If the user has an open DRAFT PR with Jira = In Progress (or Unrefined/Buildable with a PR already open), always create a `🟠 CR-XXXXX — Continue building {description}` todo scheduled for `today`, even if there is no blocker or feedback. the user's todo list is their primary memory — active work that isn't on the list gets forgotten. Do not skip these just because there's nothing blocking.

**PR chains**: When multiple PRs belong to the same epic or dependency chain, give each its own todo. Only the first unblocked PR in the chain is actionable today — everything downstream of an open PR is Blocked and goes to `anytime`. Do not roll a chain into a single "manage PR chain" todo. When the blocking PR merges, the next PR in the chain becomes actionable and should be picked up on the next standup run.

**Jira status sanity check**: For every open PR the user authored, cross-reference the linked Jira ticket's status against what the PR state implies:

- PR is open → ticket is at minimum **In Progress**. If Jira shows Unrefined, Planned, or Buildable, that's a mismatch.
- PR is open + not a draft + has at least one reviewer assigned → ticket should be **Peer Review**. If Jira shows anything earlier in the workflow, that's a mismatch.
- PR has 2+ approvals + Jira is **Peer Review** → ticket should be transitioned to **QA Ready**. Create a `🟠 CR-XXXXX — Move to QA Ready` todo.
- PR is merged (`state: closed` and `merged_at` is set) + Jira is **Ready to Ship** → ticket needs to be transitioned to **Shipped**. Flag this as a cleanup task — there are likely missing fields (e.g. story points) that need to be filled before transitioning. Create a `🟢 CR-XXXXX — Fill in points and transition to Shipped` todo.

Flag each mismatch in the standup output so the user can update Jira. Do not auto-update Jira — just surface it.

**Stale waiters**: For any PR or ticket classified as inactionable (Blocked, Approved awaiting QA, Awaiting product decision), check the last activity timestamp — `updated_at` on the GitHub PR, or `updated` on the Jira ticket. If no activity for **more than 2 days**, flag it with ⏰ in the todo notes (e.g. `⏰ No activity since Apr 18 — consider a nudge`). These are not action items, just prompts to check in. Tailor the suggested nudge to the current status — for QA Ready/QA Review, suggest pinging the QA team (see Configuration); for Product Review, suggest checking with product; for Blocked, note which upstream PR is holding it. **Do not comment on reviewer counts for PRs in QA Ready or later** — past Peer Review means code review is done and one approval was sufficient. Collect all stale waiters and surface them in a **Stale waiters** section in the final standup output, after the priority task list.

**Team field check**: For any ticket stuck in QA Ready with no activity for >3 days, fetch the full Jira issue and check `customfield_10001` (the Team field). If it is `null` or empty, the ticket is invisible to QA — this is a known cause of tickets sitting in QA Ready indefinitely. This is **actionable** — create a separate 🟠 Things todo titled `🟠 CR-XXXXX — Set Team: Integrations (QA can't see this ticket)` scheduled for `today`, not just a stale waiter note. Do not suggest pinging QA — the field must be set first or the ping is pointless.

**Subtask caveat**: If the ticket is a subtask (`issuetype.subtask == true`), the Team field must be set on the **parent** ticket — fetch it via the `parent` field and note the parent key in the todo so the user knows where to go.

**Product Manager check**: For any ticket stuck in Product Review with no activity for >3 days, fetch the full Jira issue and check `customfield_10036` (Product Manager). If it is `null` or empty, the ticket is invisible to product — no one knows they're supposed to review it. This is **actionable** — create a separate 🟠 Things todo titled `🟠 CR-XXXXX — Assign Product Manager (stuck in Product Review)` scheduled for `today`. For integrations tickets, the PM is typically Roland Simon. Note: setting the PM field (`customfield_10036`) may trigger Jira automation to also populate `customfield_10048` (QA Engineer) — this is expected.

Also add `customfield_10036` and `customfield_10048` to the field list when fetching stale tickets in Step 3, since these are needed for the PM and QA checks.

**Before writing anything to Things**, do a consolidation pass over all candidate todos gathered from Steps 1–5 in this session. Group candidates that share a CR number or PR number into a single todo — do not create separate todos for the same ticket just because the signals came from different sources (e.g., a PR approval from Step 2 and a Slack message from a QA team member in Step 4 about the same CR). The consolidated todo should:
- Use the highest priority level among the merged items
- Combine all context into the notes (PR status, Jira status, Slack thread link, comment summary)
- Use the title that best describes the action the user needs to take

**Re-verification must use live data, not existing todo notes**: When an existing todo makes a factual claim (e.g. "0 reviewers assigned", "no approvals", "CI failing"), always re-verify that specific claim against GitHub/Jira directly — do not carry it forward as true just because it was written yesterday. For example, if a todo says "needs reviewers," fetch the PR and check `requested_reviewers` before echoing that claim. Stale todo notes are a known source of false positives. This applies at every step — do not echo any cached classification without verifying the live state first.

**Before writing anything to the daily note**, read the following files:
- Today's daily note (`YYYY-MM-DD.md`) — if it exists, scan for `- [ ]` incomplete tasks
- The last 3 daily notes — scan for `- [x]` completed tasks (logbook equivalent)

For each candidate task, find any match by looking for shared identifiers: PR numbers (e.g. `#1251`), CR numbers (e.g. `CR-55517`), or distinctive keywords in the task line. Then apply this logic:

**Match found as incomplete (`- [ ]`) in today's note** → do not add a duplicate. Instead:
1. Determine the current classification based on today's live data — not the existing task's notes.
2. If the current classification is **Approved, awaiting QA** or **Awaiting product decision** → move the task line to the `## Anytime / Blocked` section by editing the file.
3. Otherwise, if there is new activity, append a timestamped note as an indented sub-line under the existing task. If nothing new, leave it alone.

**Match found as completed (`- [x]`) in a recent note** → the task was already closed. Only add a fresh task if there is *genuinely new* activity requiring attention — specifically: a new CHANGES_REQUESTED or new inline comment submitted *after* the user's most recent push. If no new activity, skip entirely.

**No match found** → append the new task to today's daily note as normal.

### Tagging guide

**Energy** — pick one:
- `High` — requires focused thinking: code review, debugging, writing/pushing code, architecture decisions
- `Low` — mechanical or low-stakes: merging an approved PR, assigning reviewers, updating Jira status, a quick DM reply

**Time** — pick the best estimate:
- `5m` — pure mechanical, no thinking required (assign reviewer, flip Jira status)
- `15m` — quick but needs some thought (investigate + reply, merge with a QA note)
- `30m` — moderate (code review of a small PR, substantive Slack discussion)
- `60m` — substantial (complex code review, pushing code changes, debugging)

**Context** — pick one:
- `Computer` — GitHub, Jira, coding work
- `Slack` — DM replies, channel discussions to weigh in on
- `Email` — email action items

Always include the literal tag `"work"` as well so these show up under the Work filter.

---

## Step 6.5 — Friday only: 15five weekly review

**Only run this step if today is Friday.**

15five has no MCP and its API is read-only — submission must be done manually. The goal is to pre-fill the weekly check-in bullets so the user can paste them in and hit submit in under 2 minutes.

**Scan the logbook for this week's work:**
Read the last 7 daily note files in `~/Documents/Obsidian/Daily/`. Collect all `- [x]` completed tasks tagged `#work`. Read all the completed work items, then **group and summarize by initiative or theme** — do NOT list individual tasks. Aim for 3–5 broad bullets that capture what was worked on at a high level. Examples of the right grain:

- "Kicked off Nutshell CRM integration — inti model config, Nutshell feature in monolith, and looky frontend all in flight"
- "Cancel/reschedule appointments feature for Calendly + Google Calendar: proto changes and DB migrations merged, inti and looky tickets in progress"
- "Code review throughput: reviewed 6 PRs across inti, callrail, and looky (JobTread, ingestion_enabled, MMS, ECL)"
- "Merged CR-54946 logging improvements and CR-49569 Salesforce after QA sign-off"

Do not write a bullet per PR or per ticket. If 4 PRs were reviewed, that's one "code review" bullet. If 3 tickets from the same epic moved forward, that's one "Nutshell" bullet.

**Pull next week's plans:**
Look at the highest-priority in-flight items from Steps 2 and 3 (the user's open PRs, active Jira tickets). Write 3–5 broad plan bullets in the same style — what initiatives or themes the user plans to push forward next week.

**Add to today's daily note — always, no dedup:**
Unlike other tasks, **do not deduplicate this one**. Add a fresh task every Friday regardless of whether a previous uncompleted 15five task exists in a recent note — the user explicitly wants duplicates to accumulate until submitted.

Append to today's daily note:
- Task: `- [ ] 📝 Submit 15five weekly review #computer #high #15m #work`
- Followed by the pre-filled bullets as indented sub-lines structured as:

```
## This week
- [broad accomplishment bullet]
- [broad accomplishment bullet]
- [...]

## Next week
- [broad plan bullet]
- [...]

15five: https://callrail.15five.com/actions/my-actions/?page=1&page_size=10&order_by=-activation_ts&action_type=dueThisWeek
```

**Add to output:** Print the pre-filled bullets under a "**15five draft**" header in the standup output (after the priority list, before the standup draft). the user can review, edit, and paste directly.

---

## Step 7 — Draft standup message

Write a short standup update the user can copy-paste into `#team-integrations` if needed. Format:

```
Yesterday:
- [bullet per completed or meaningfully progressed item]

Today:
- [bullet per planned item, drawn from today's priority list]

Blockers:
- [any blockers, or "none"]
```

Keep bullets tight — one line each. This is for the team, so focus on things that affect others (PRs ready for review, things you're waiting on, things others are waiting on you for).

Print this at the end of the summary under a "Standup draft" header. Do not post it to Slack.

---

## Output format

### Terminal output
Print the summary in this order:
1. **Today's schedule** — meetings and focus blocks
2. **Priority task list** — grouped by 🔴 / 🟠 / 🟡 / ⚪
3. **Stale waiters** — inactionable items with no activity for >2 days; format as `⏰ CR-XXXXX — {title} (stuck N days, last activity: {date})`. Omit section if nothing is stale.
4. **Carry-over check** — any old Obsidian tasks to reconsider
5. **Standup draft** — ready to copy-paste

Keep it scannable. This is a morning brief, not a report.

### Daily note written to `~/Documents/Obsidian/Daily/YYYY-MM-DD.md`

If the file doesn't exist, create it with this structure:

```markdown
---
date: YYYY-MM-DD
tags: [daily]
---

# YYYY-MM-DD

## Schedule
- HH:MM — Event name
(one line per meeting)

## Tasks
- [ ] 🟢 Title #work #computer #low #5m
  - Jira: https://...
  - PR: https://...
- [ ] 🔴 Title #work #computer #high #30m
  - context note

## Anytime / Blocked
- [ ] 🟠 CR-XXXXX — blocked on #1234 #work #computer #high #60m
  - Blocked on: PR#1234

## Stale waiters
⏰ CR-XXXXX — stuck 3 days, last activity: Jun 6

## Standup draft
**Yesterday:**
- bullet

**Today:**
- bullet

**Blockers:**
- none
```

If the file already exists (re-run), append new tasks under the existing sections rather than overwriting.
