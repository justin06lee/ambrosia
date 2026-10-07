# Component library

Every piece of this project's interface ruri has on file: the user's own
name for it, its handle, its files, and a picture. When the user names
something here, this is what they mean — go straight to its files rather
than searching for their words. Before building interface, look here
first and reuse what exists: `ruri show <slug>` reads one with its code,
`ruri add <slug>` copies it into place, `ruri help` says the rest.

ruri maintains this file. Don't edit it by hand; it is rewritten whenever
the library changes.

## design-preview-desktop — the design preview desktop
HTML mock of the whole ambrosia desktop (menu bar, dock, Files + terminal windows, notification, control center, View menu), styled only from dist/web/tokens.css — the visual reference the Linux shell must match. Run `make build` first; D/A keys or ?theme=&accent=&open= switch state.
Its files: preview/index.html, preview/preview.css, preview/preview.js
Reaches into: dist/web/tokens.css, assets/wallpapers/nectar-day.svg, assets/wallpapers/nectar-night.svg
Tags: desktop, preview, glass, dock, menu bar, control center
Screenshot (read it if you need to see it): /Users/huiyunlee/.config/ruri/uploads/c96b837f-b878-48d3-b290-23b45a36c12c-mcp-bridge-blob-1791333821291-68paem.png
