# Design pass verification — 2 November 2026

## Scope and PRs

- PR #16: existing mobile improvements plus editorial project and company pages.
- PR #18 (based on #16): Personal & editorial member profile, optional public
  availability, dashboard priorities, joining/editor polish and goal-based discovery.
- Earlier session work established Ink & lime and two-column discovery.
- Marketing is deferred. Community stream, article sharing, ideas, new project
  joining and matching remain product work in DASHBOARD_ROADMAP.md.

## Automated verification

- Full Rails suite: 172 tests, 3378 assertions, zero failures/errors/skips.
- RuboCop: SDG controller and new goal discovery integration test pass.
- Goal coverage checks publication ordering, exact target matching, completed
  and active projects, empty results, and exclusion of drafts/unpublished owners.
- Existing coverage includes profile updates, public availability validation,
  privacy, project/company content and mobile markup/controls.

## Browser verification

Actual Rails-rendered fixtures with synthetic test data were inspected locally at
320, 375, 768 and 1280 pixels: dashboard, people/project discovery, member profile,
project detail, company full/sparse profiles, profile editor, personal/company
joining, goal and target pages. No document horizontal overflow remained.

Fixed long goal action buttons overflowing narrow screens. Verified that mobile
editor section switching shows the unsaved-changes warning, Keep editing retains
the changed input, and the signed-in mobile menu opens.

## Limits

Browser checks used static rendered fixtures with local scripts, not a deployed
end-to-end session. Form persistence and permissions were exercised by Rails
integration tests. Real-device Safari/Android, production uploads and deployed
email/contact delivery were not tested. No production records were modified.
