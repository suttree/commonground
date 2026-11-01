# Dashboard follow-up for Duncan

## Agreed direction

Apply Ink & lime to the currently functional dashboard. Its order is now: current
project and availability, next actions, the reflection question and priorities,
then projects connected to the member's goals. Existing controls are kept. Later, evolve toward the Community living room
layout when there is real community content to support it. The visual prototype
is a direction, not evidence that article sharing or discussions already exist.

Other agreed design decisions: discovery uses a filter sidebar and refreshed
cards; member profiles now use Personal & editorial (previously Work & personality). Both are implemented on
the same design branch alongside the dashboard styling. Marketing is deferred. Next design reviews are project
details and company profiles, then joining and editing; the full mobile and
state review comes last.

## What main already supports

- Current project, drafts/previous work, project editing, and profile switching.
- Up to three discoverable active projects related to selected goals (all goals
  when none are selected), excluding the active profile's own projects.
- People, companies, projects, priorities, and quiz navigation.
- Provocation answers and history, optional notes, optional sharing, shared
  response distributions, and shared notes on question detail pages.
- Consented introductions around provocation answers, plus existing project
  invitations and profile contact flows.

The first audit used the older navigation branch and incorrectly marked notes
and shared reflections as missing. Main already implements those features;
reuse them rather than build a second system.

## Proposed additions, in order

### 1. Share a useful link with context

A member shares a URL, a short explanation of why it matters, and optional goal
associations. Show the author and actual publication time. Provide edit/delete
ownership rules and an explicit audience before publication. Decide whether
publication belongs to an account or its selected personal/company profile.

Start with user-entered title and URL; fetching external previews is optional.
If previews are added, handle URL validation, server-side request safety, failed
fetches, and image quality. A useful text-only item must be the default.

Acceptance: another authorised member can read the contribution and follow its
link; author edits and deletions are reflected; unauthorised readers cannot
access restricted items.

### 2. A small community stream

Combine published contributions with appropriate public projects. Start with a
bounded chronological list, then consider goal filters. Include actual author,
context, and source links. Do not turn private answers, drafts, edits, or contact
requests into activity. Define eligible events explicitly; updated_at alone does
not prove that something meaningful happened.

Acceptance: each item has a real source; visibility changes remove it; pagination
is stable; sparse activity still shows useful project discovery without fake
updates, counts, or recency claims.

### 3. Optional bookmarks

Private save/unsave and a saved-items view. Respect the source's current visibility
when revisiting it. Decide whether saves belong to the account or selected profile.
This is independent of sharing and can ship later.

### 4. Conversations, only when scoped

Existing contact, invitation, and consented-introduction flows are not general
article comment threads. Decide between comments on contributions and contacting
the author. Do not add a misleading 'Join the conversation' button before there
is a destination. Comments would also need ownership, deletion, reporting,
moderation, and a deliberate notification policy.

### 5. "Things I wish existed" (idea, needs definition)

Nika suggested a place where members share things they wish existed or would
like to see happen. Not built. It is captured here so it isn't lost, and it needs
decisions before any design work:

- Posting: who can post, how long a post is, and whether it can be anonymous.
- Discovery: where wishes appear (dashboard, goal pages, a dedicated page) and
  how they are filtered or tied to SDG goals.
- Responses: whether people can reply, say "me too", or offer to help, and what
  that triggers (contact flow, notification, nothing).
- Relationship to projects: whether a wish can become a project, and how credit
  and ownership carry over.
- Moderation, editing, deletion, and when a wish is closed or stale.

Treat it like the community stream: no placeholder feed or non-working buttons
until these are decided.

## When to revisit the dashboard layout

Once published contributions and a usable stream exist, put community content in
the main column. Move current project and the existing reflection experience into
a supporting column. Preserve access to priorities, history, profile management,
and company accounts. Recheck long questions and note/share forms in the narrower
column rather than squeezing them into the mockup's simplified controls.

Validate with real sparse content and real member text. No fake articles, unread
counts, 'caught up' claims, or nonfunctional actions should ship with the styling.
