# Technology approach

Use a basic Ruby on Rails application for the pilot described in [PLAN.md](PLAN.md). Serve plain HTML from Rails templates, with simple CSS. Give text priority throughout the site.

## Rails and HTML

- Use conventional Rails routes, controllers, models and ERB views.
- Render pages on the server and use standard links and HTML form submissions.
- Validate submissions on the server and show useful errors while preserving entered values.
- Keep the application in one Rails codebase. No separate frontend application or API is needed for the pilot.
- Avoid JavaScript frameworks such as React and client-side routing. Core pages and forms must work without JavaScript.
- Add small amounts of JavaScript only when a specific interaction benefits from it. Keep the underlying HTML flow usable without it.

## Semantic and accessible markup

- Choose HTML elements for their meaning. Use page landmarks, a logical heading hierarchy, lists, links for navigation and buttons for actions.
- Prefer native form controls. Give every field a visible label and associate help text and errors with the relevant field.
- Group related controls with fieldsets and legends where appropriate. Mark required fields clearly.
- Make every interaction usable with a keyboard, with visible focus and a logical focus order.
- Make submission confirmations and validation errors clear to screen reader users.
- Use readable contrast. Never rely on colour alone to communicate meaning or state.
- Support browser zoom and narrow screens without clipped text or horizontal page scrolling.

## Typography and layout

- Make the words the main content of each page. Keep decoration secondary to the explanation, questions and next action.
- Use large, legible fonts. Start with a system font stack and a body size of 1.125rem, using relative units so text respects browser settings.
- Give form labels, inputs, help text and errors the same attention as body copy. Do not shrink essential information into small print.
- Use comfortable line spacing, around 1.5, and limit prose to roughly 65 characters per line.
- Use a simple, mostly single-column layout with clear headings and enough space between sections.
- Use plain CSS and responsive layouts. Avoid unnecessary animation, decorative imagery and complex interface components.

## Verification before launch

Check both submission flows with JavaScript disabled, using only a keyboard, and with a screen reader. Check mobile and desktop layouts, enlarged text, browser zoom, contrast, validation errors and confirmation messages.

## Hosting

Host the Rails application on [Fly.io](https://fly.io/rails/).

The pilot uses Rails 8.1.3.1, Ruby 3.4.1 and SQLite on a persistent Fly volume in London. Deploy one application machine so all submissions use the same database. Scheduled volume snapshots have seven-day retention.

The admin area uses plain Rails views protected by HTTP Basic authentication, with credentials stored in Fly secrets. Public applicants do not need an account. See [README.md](README.md) for setup and deployment instructions.
