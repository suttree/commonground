# Design system

Commonbound's visual language lives in one stylesheet, [`app/assets/stylesheets/application.css`](app/assets/stylesheets/application.css). Every colour, size, space and corner comes from a token declared on `:root` at the top of that file. Use a token instead of typing a value. If no token fits, add one here and in `:root` rather than writing a one-off.

Keep plain wording and the established typography. Marketing retains the original green and cream theme; product pages use the Ink & lime direction documented below.

## Principles

- **One clear next step.** A page has one primary button. Everything else is a quiet link.
- **Show the journey.** Sign-up has four steps; the "Step N of 4" bar keeps people oriented.
- **Plain words.** Say what a button does ("Start the questions"), not what it is ("Submit").
- **Serif for people, sans for interface.** See [Headings](#headings).
- **Accessible by default.** Text meets WCAG AA contrast, controls work with a keyboard and show a visible focus outline.

## Colour

### Core

| Token | Hex | Use |
|---|---|---|
| `--paper` | `#f8f7f0` | Page background |
| `--ink` | `#253d35` | Body text and headings |
| `--muted` | `#59625b` | Supporting text |
| `--green` | `#285543` | Brand, primary buttons, links, panels |
| `--green-dark` | `#203c30` | Hover and pressed states on green |
| `--line` | `#c9cdc1` | Dividers and card borders (decorative only) |
| `--line-strong` | `#7b877a` | Form field borders (3.5:1, meets the 3:1 rule for controls) |
| `--wash` | `#e9eddf` | Soft background panels |
| `--field` | `#fffef9` | Inputs and near-white surfaces |
| `--card` | `#f0f2db` | Project card background |
| `--question` | `#f0f0e4` | Dashboard question panel background |
| `--error` | `#9a3029` | Error text and borders |
| `--focus` | `#ad4c25` | Keyboard focus outline |

### Card fills and edges

Cards cycle through four fills. Each fill has a matching edge colour for its top or left border.

| Fill | Hex | Edge | Hex |
|---|---|---|---|
| `--sky` | `#dceaf2` | `--sky-edge` | `#6f96b2` |
| `--peach` | `#f6d9c9` | `--peach-edge` | `#bc6348` |
| `--citrus` | `#e7edbe` | `--citrus-edge` | `#819947` |
| `--yellow` | `#f5e5a7` | `--yellow-edge` | `#c5a544` |

Edge colours are decorative. Don't use them for text: they don't meet text contrast.

### On green panels

| Token | Value | Use |
|---|---|---|
| `--on-green` | `#ffffff` | Text and button labels on `--green` |
| `--on-green-accent` | `#c9dc86` | Step numbers and small highlights |
| `--on-green-muted` | 80% white | Supporting text |
| `--on-green-line` | 19% white | Dividers |

### Contrast

All text tokens pass WCAG AA (4.5:1) on every background above. The tightest pair is `--muted` on `--peach` at 4.7:1. Text on `--green` is 5.7:1 or better.

### Exceptions

- The 17 official UN SDG colours (`.sdg-color-1` to `.sdg-color-17`) are fixed by the UN and stay as they are.
- `/althomepage` is an isolated experiment with its own theme (`.bauhaus-page`). It doesn't follow this system.

## Typography

Body text uses the system sans-serif (`-apple-system`, `Segoe UI`, …) at `--text-md` (19px), line-height 1.6.

### Headings

| Element | Font | Token | Size (desktop) |
|---|---|---|---|
| Home hero | Serif | `--heading-display` | 42–72px, scales with width |
| `h1` page title | Serif, regular | `--heading-1` | 37–56px, scales with width |
| `h2` section | Sans, semibold | `--heading-2` | 26–35px, scales with width |
| `h3` card title | Sans, semibold | `--heading-3` | 22px |
| `h4` small label | Sans, semibold | `--heading-4` | 18px |

**The serif rule:** every page title (`h1`) is serif. Everything below it is sans. Add the `heading-serif` class to any heading that marks a human, conversational moment, for example "Prefer a conversation?" on quiz results. Use it sparingly, or it stops meaning anything.

One `h1` per page. Don't skip heading levels for size: pick the level by meaning and let the token set the size.

### Text sizes

| Token | Size | Use |
|---|---|---|
| `--text-xs` | 12px | Eyebrows, tiny labels |
| `--text-sm` | 14px | Notes, hints, captions |
| `--text-base` | 16px | Secondary text, small UI |
| `--text-md` | 19px | Body text |
| `--text-lg` | 22px | Emphasised short text |
| `--text-xl` | 28px | Large numbers or statements |
| `--text-lead` | 19–26px, scales with width | Intro paragraphs and pull quotes |

## Spacing

Margins, padding and gaps use an 11-step scale.

| Token | Size | Token | Size |
|---|---|---|---|
| `--space-1` | 4px | `--space-7` | 32px |
| `--space-2` | 8px | `--space-8` | 40px |
| `--space-3` | 12px | `--space-9` | 48px |
| `--space-4` | 16px | `--space-10` | 64px |
| `--space-5` | 20px | `--space-11` | 80px |
| `--space-6` | 24px | | |

Spacing that should grow with the screen may use `clamp()`, and spacing relative to text may use `em`. Everything else uses the scale.

## Corners

Four styles. The leaf, one large rounded corner at the top right, is Commonbound's signature.

| Token | Value | Use |
|---|---|---|
| `--radius` | 4px | Buttons, inputs, tags, small boxes |
| `--leaf-card` | 4px, 24px top-right | Cards: projects, directory, suggestions |
| `--leaf-panel` | 4px, 48px top-right | Large panels and heroes |
| `50%` | circle | Avatars |

Use `0` only where an image must stay square.

## Buttons

| Class | Look | Use |
|---|---|---|
| `.button` | Solid green | The one primary action on a page |
| `.button.secondary` | Green outline | Other actions in a form |
| `.button.secondary.small` | Thin `--line` outline, small text | Header actions such as "Edit profile" and "View profile". Use this, not a text link |
| `.button.ghost.small.back` | No border; `--line` border on hover | Back links such as "← Back to dashboard" and "← All people". Starts with a ←, and `.back` pulls it left so the label lines up with the page edge |

Links that leave the current task open in a new tab: "View profile" from the editor, and a member's own website.

## Patterns

- **Tabs** (`.profile-tabs`): profile editor sections. Plain text on one divider line; the current tab is bold `--ink` with a 3px `--green` underline.

- **Journey checklist** (`.journey`): the new-member dashboard. Done steps show a check, the current step is a green row with the only button, and later steps are muted.
- **Step bar** (`shared/_journey_bar`): "Step N of 4" on the quiz and profile pages during sign-up.
- **Green panel**: `--green` background, `--on-green` text, `--leaf-panel` corner. Used for the current journey step and "Prefer a conversation?".
- **Choice tiles** (`.next-step-tiles`): radio options laid out side by side, stacking on phones.
- **Folded options** (`<details>`): optional edits, such as "Change priorities", stay closed by default.

## Not decided yet

- Where the woven-ribbon illustration should and shouldn't appear. It's currently on eight templates.
- SDG colours and member counts on the goal pages.
- Navigation structure.

## Dashboard: Ink & lime

The dashboard uses `body.dashboard-theme`; discovery, member/company profiles,
project details, joining/editing and goal pages use `ink-lime-theme`. Marketing
retains its existing theme. Current work and availability precede reflection on
the functional dashboard. The community stream remains scoped in `DASHBOARD_ROADMAP.md`.

New root tokens:

| Token | Value | Purpose |
| --- | --- | --- |
| `--dashboard-paper` | `#fafbf8` | Clean page background |
| `--dashboard-surface` | `#ffffff` | Cards and fields |
| `--dashboard-ink` | `#25343b` | Text and actions |
| `--dashboard-muted` | `#56666c` | Secondary text |
| `--dashboard-line` | `#dbe2df` | Decorative separators |
| `--dashboard-field-line` | `#79877f` | Input and answer control boundaries |
| `--dashboard-lime` | `#ddeb91` | Reflection panel |
| `--dashboard-sage` | `#eaf0eb` | Quiet highlights |
| `--dashboard-radius` | `10px` | Dashboard panels |

Use existing spacing and type tokens. Serif question text, neutral project cards,
and a lime reflection panel establish hierarchy. Preserve the official SDG colours;
the dashboard theme does not override those classes. Notes, sharing, question
permalinks, profile switching, and normal form submissions remain available.

## Discovery and member profiles

The approved Ink & lime theme also applies to people/company/project discovery
and profile pages through `ink-lime-theme`. Project details, company profiles,
joining and editing now share this palette; marketing remains deferred.

Discovery preserves the filter sidebar, server-side queries, and pagination.
Search comes first, with result counts and individually removable applied filters
above the cards. Person photos fit a fixed circular crop; absent photos and company
identities use initials. Identity accent colours derive from the persisted profile
ID, so filtering or sorting does not recolour a person. No uploaded company logo
or photograph is required. SDG labels retain official colour markers.

### Personal & editorial member profiles

Member profiles use an editorial identity block, a serif purpose statement, a lime current-project panel and a side-project column. At 650px and below, the content stacks, the portrait reduces to a controlled 76px-wide frame, and contact actions span the width. These rules build on the signed-in mobile navigation and form improvements in PR #16.

Public availability is an optional `profile.availability_status` choice in Basics. Open and occasional-help states use a green dot; unavailable and unset states remain neutral, always with a text label. The legacy `availability` column is not displayed or migrated because it was not explicitly collected for public display. No database migration is needed.

## Project and company details

Use a large editorial title, a nearby introduction and a lime help/current-project panel.
Keep longer narrative content in the main column. The quieter sidebar provides
identity, location, public contact links and UN target colours without a divider
between every item. Initials are a first-class fallback; layouts must work without
photos or company logos. Never substitute private account-owner details for public
company contact information. Empty optional sections disappear.

## Joining, editing and goals

Joining explains required versus optional fields and public versus private data.
Editing follows the ProfileSections order, wraps sections into two columns on
phones, and preserves unsaved-change protection and the mobile save action.
Goal pages show up to three published, discoverable projects; target pages match
the exact target. The browse link explicitly opens the broader parent goal filter.
Keep official UN colours alongside Ink & lime. See DESIGN_QA.md for validation.
