Notes on sidebar tweak (keep for future)

- Added collapsible drawer logic: `@sidebar_open` assign, toggle event, bound checkbox; drawer now hides on desktop when closed.
- Removed `md:drawer-open` lock; drawer now opens via `drawer-open` + checkbox.
- Mobile/overlay labels flip `toggle_sidebar`; desktop toggle now sits above the sidebar (top-16, left-4, z-[60]) so it stays visible above the "Novo chat" area and over the app header.
- Default open state set true in mount for continuity; adjust if mobile UX needs closed-by-default.
- Mix format skipped (blocked by TCP eperm in sandbox) so file untouched by formatter.
