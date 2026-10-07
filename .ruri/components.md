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
HTML mock of the whole ambrosia desktop: menu bar, the dock (roomy, ringed, glassy icon rims, badges, a following tooltip), Files + terminal windows, notification, the control center (no panel: capsule modules on a feathered blur, fade choreography measured from macOS), View menu and right-click context menu (both snap open). Styled only from dist/web/tokens.css; run make build first; D/A keys or ?theme=&accent=&open= switch state.
Also called: control center
Its files: preview/index.html
Reaches into: dist/web/tokens.css, assets/wallpapers/nectar-day.svg, assets/wallpapers/nectar-night.svg
Tags: desktop, preview, glass, dock, menu bar, control center
Screenshots, newest first (read them if you need to see it): /Users/huiyunlee/.config/ruri/uploads/434af6ce-267b-4897-97b3-2dd0d6ed6ee0-mcp-bridge-blob-1791343118180-207jfi.png, /Users/huiyunlee/.config/ruri/uploads/11b616fd-cdf0-426e-942c-93307dd52e07-mcp-bridge-blob-1791341648980-ipz08i.png, /Users/huiyunlee/.config/ruri/uploads/1c4d9e3d-afa9-4cc2-8b84-c41a45a5a00c-mcp-bridge-blob-1791341481579-oy3f5g.png, /Users/huiyunlee/.config/ruri/uploads/78733591-788e-4eab-8ef1-97af7b3f009f-mcp-bridge-blob-1791339962005-hkc7oc.png, /Users/huiyunlee/.config/ruri/uploads/6552624f-e736-4293-9154-7c93fafb0bea-mcp-bridge-blob-1791339158628-er4goe.png, /Users/huiyunlee/.config/ruri/uploads/7f4a8699-0a5e-4746-b589-2c794d18ca4e-mcp-bridge-blob-1791337341039-ucycqv.png

## design-review-site — the design review site
Review site for the design: one section per DESIGN.md chapter and DECISIONS.md entry, with live examples built from the real tokens, a verdict control and a notes thread per section that saves to design/review.json (`bun run review`, port 4747). Static copy in dist/site keeps notes in localStorage instead.
Its files: site/index.html, site/main.ts, site/specimens.ts, site/content.ts, site/review.ts, site/dom.ts, site/site.css, site/server.ts, site/build.ts
Reaches into: dist/web/tokens.css, preview/glass.css, preview/index.html, design/DESIGN.md, design/DECISIONS.md, design/review.json
Tags: site, review, docs, glass, specimens
Screenshot (read it if you need to see it): /Users/huiyunlee/.config/ruri/uploads/9696513f-6d94-44fb-a522-ec1136e186b8-mcp-bridge-blob-1791334760389-1vai1t.png
Its code has changed since that picture — if you change it, `ruri edit design-review-site --shot <new picture>`
