# Bullet Train Docs on GitHub Pages: Design

Date: 2026-11-06
Repository: `tujucreative/bullet_train.github.io`

## Goal

Port the Bullet Train developer documentation, which the Rails app serves at `bullettrain.co/docs` (sources: `bullet_train-core` gem docs plus the `tujucreative/bullet_train-demo_site` app that hosts them), into this repository as a static site deployed to GitHub Pages. Rendered pages should read and look like the live site.

## Decisions (agreed with the user)

- **Generator:** a small Ruby build script using Commonmarker (the engine the Rails app uses) and an ERB layout. It is built and deployed by a GitHub Actions workflow. No Jekyll.
- **Look:** a close replica of the live docs layout: blue gradient sidebar menu, white content card with Tailwind Typography prose, and a mobile menu toggle. CSS is compiled at build time with the Tailwind CLI v3.
- **Content:** a vendored snapshot of `bullet_train-core/bullet_train/docs`, pinned to tag `v1.45.1` (commit `8978cfefef27caca382d8df71200217380f0d9ba`, matching `BULLET_TRAIN_VERSION` in `tujucreative/bullet_train` and the demo site), plus a `bin/sync-docs` script to refresh it from any ref.
- **URLs:** project site at `https://tujucreative.github.io/bullet_train.github.io/`. Pages live under `/docs/`, and the base path is configurable so a custom domain can be added later.

## Non-goals

- Search. The live site's Algolia DocSearch index belongs to bullettrain.co, so it is omitted.
- The Showcase engine (`/docs/showcase`) and the marketing home page.
- Editing upstream doc content. Vendored files stay byte-identical to upstream, and every adaptation happens at render time.
- Dark mode toggle, versioned docs.

## Repository layout

```
Gemfile, Gemfile.lock        commonmarker (>= 2.7), nokogiri, minitest, rake, webrick (dev)
package.json, package-lock.json   tailwindcss ^3.4, @tailwindcss/typography, @tailwindcss/forms, @icon/themify-icons
tailwind.config.js           primary/secondary via CSS vars, base = slate (mirrors tailwind.light.config.js)
Rakefile                     `rake test` (default), `rake build`
src/
  docs/                      vendored upstream markdown, verbatim (57 files incl. subdirs)
  UPSTREAM                   repo URL, ref, commit sha of the vendored snapshot
  menu.yml                   sidebar navigation data
  layout.html.erb            page shell (head/meta, sidebar, mobile menu, content card)
  styles.css                 Tailwind input (@tailwind directives + theme color vars + small custom rules)
  menu.js                    tiny vanilla JS for the mobile menu open/close
  assets/
    logo/logo.png, logo/favicon.png       copied from bullet_train-demo_site app/assets/images/logo
    upgrade-images/*.png                   copied from bullet_train-demo_site public/upgrade-images
lib/docs_site/               the builder (plain Ruby, no Rails)
bin/build, bin/sync-docs, bin/serve
test/                        minitest suite
.github/workflows/pages.yml  build + deploy
README.md
```

## Components

Each unit has one job and can be tested on its own.

1. **`DocsSite::Config`** holds `base_path` (default `/bullet_train.github.io`, overridable by `--base-path` or `BASE_PATH`, where `""` is allowed and a trailing slash is stripped), `source_dir`, `out_dir` (default `_site`), and `site_url` (default `https://tujucreative.github.io`, used for `og:url`).

2. **`DocsSite::Renderer`** turns one markdown string into HTML. It replicates the Rails path exactly:
   - Pre-process the source with `.gsub('.md)', ')')`, as in `public/home/docs.html.erb`.
   - Render with the *verbatim* call from `Account::MarkdownHelper#markdown`: `Commonmarker.to_html(string, options: {extensions: {header_ids: true}, plugins: {syntax_highlighter: {theme: "InspiredGitHub"}}, render: {width: 120, unsafe: true}})`, then `.gsub(/&lt;(\/)?script/, '<\\1script')`. (Commonmarker 2.x ignores those nested keys, so the live site gets default heading IDs/anchors and the default `base16-ocean.dark` highlighting. Reproducing the call verbatim reproduces that output.)
   - Source is read as UTF-8.

3. **`DocsSite::LinkRewriter`** post-processes rendered HTML with Nokogiri so it works under the base path:
   - `href` of `/docs` or `/docs/<page>` (optional `.md`, optional `#fragment`) becomes `<base>/docs/` or `<base>/docs/<page>/` with the fragment preserved and `.md` stripped.
   - `https://bullettrain.co/docs/<page>` links become the same local form.
   - `src`/`href` of `https://bullettrain.co/upgrade-images/<file>` become `<base>/upgrade-images/<file>`.
   - Everything else (external links, `#fragment`-only links, `https://bullettrain.co` itself) is left untouched.

4. **`DocsSite::Page`** is a value object for one doc. It holds `slug` (path relative to `src/docs` without `.md`, e.g. `billing/stripe`, `index`), `url` (`<base>/docs/` for `index`, else `<base>/docs/<slug>/`), `output_path` (`docs/index.html` or `docs/<slug>/index.html`), the body HTML, and metadata derived like the live layout:
   - title: first `h1` text, falling back to "Bullet Train Developer Documentation"
   - `<title>`: `"<h1 title> — Bullet Train Developer Documentation"`, or just the site name when the title equals it
   - description: `[preceding h2 text, first paragraph text]` joined with " — ", truncated to 200 characters

5. **`DocsSite::Menu`** loads `src/menu.yml`: sections (`title`), each with items (`label`, `url`, `icon` Themify class, optional `external: true`). Contents are transcribed from `bullet_train/app/views/layouts/docs.html.erb` at v1.45.1, with the same sections, order, labels, URLs and `ti ti-*` icons, minus the disabled `if false` section. Internal URLs (`/docs/...`, `.md` stripped) are resolved against the base path. An item is marked active when its resolved URL equals the current page URL. External items show a `ti-new-window` marker.

6. **`DocsSite::IndexLayout`** applies the special index treatment from `docs.html.erb`: split the body at the first `<h2>`, render the header, then split the remaining groups into three columns (`xl:grid grid-cols-3 gap-20`) using `in_groups(3)` semantics (fill columns in order, as evenly as possible, with the first columns getting the extra items). Implement this without ActiveSupport.

7. **`DocsSite::Builder`** orchestrates a build. It cleans `out_dir`, renders every `src/docs/**/*.md` through Renderer → LinkRewriter → (IndexLayout for `index`) → `layout.html.erb`, and writes the pages. It copies `src/assets/**` to the out root (`logo/`, `upgrade-images/`), compiled CSS to `assets/site.css`, `menu.js` to `assets/menu.js`, and Themify font files plus CSS to `assets/themify/`. It writes `index.html` at the root (redirect to `<base>/docs/` via meta refresh, canonical link, and a visible fallback link), `404.html` (layout-wrapped "Page not found" with a link to the docs index), and `.nojekyll`. CSS compilation shells out to `npx tailwindcss -c tailwind.config.js -i src/styles.css -o <out>/assets/site.css --minify`, scanning `src/**/*.{erb,yml,js}`, `lib/**/*.rb` and the generated HTML. The build fails loudly (non-zero exit with a message) on a missing source dir, a Tailwind failure, or a rendered internal `/docs/...` link that matches no page (broken-link check).

## Layout (`layout.html.erb`)

A static translation of `docs.html.erb` plus the menu `_section`/`_item` partials from `bullet_train-themes-light`:

- `<html class="theme-blue">`, body background `bg-gradient-to-br from-secondary-200 to-primary-400`, text `text-base-700 text-sm`
- Sidebar (`lg:` and up): `w-64`, `bg-gradient-to-b from-primary-700 to-primary-800`; logo header `bg-blue-700`; section headings and items styled like the light theme (white text, secondary-300 icons, `bg-primary-900` for the active item, hover nudge)
- Mobile: hamburger button opens an overlay copy of the menu, and a close button hides it (`menu.js`, no Stimulus)
- Content: `bg-white rounded-md shadow` card containing `<div class="prose" style="max-width:none" id="bt-docs-content">`
- Head: charset, viewport, title, description, keywords, Twitter and OG tags (image `https://avatars.githubusercontent.com/u/5976880?s=280&v=4`, site name "Bullet Train Developer Documentation", `og:url` = `site_url + page url`), favicon, `assets/site.css`, `assets/themify/themify-icons.css`, Inter font via Google Fonts (`rsms.me/inter` is acceptable instead)
- All asset URLs are prefixed with the base path

Theme colors: `src/styles.css` defines the `--primary-*` and `--secondary-*` vars for `.theme-blue`, copied from `bullet_train-themes-light/app/assets/stylesheets/light/tailwind/colors/blue.css` at v1.45.1.

## Scripts

- `bin/build [--base-path P] [--out DIR]` runs a full build and prints the page count.
- `bin/serve [PORT]` builds with `--base-path ""` into `_site` and serves it with WEBrick (default port 4000).
- `bin/sync-docs [REF]` (default `v1.45.1`) shallow-clones `https://github.com/bullet-train-co/bullet_train-core` at REF into a temp dir, replaces `src/docs` with `bullet_train/docs`, and rewrites `src/UPSTREAM` (repo, ref, sha, sync date). It prints a summary of added, removed and changed files, and warns when the upstream layout's menu has changed (it compares the list of `url:` values in upstream `docs.html.erb` with `menu.yml`).

## Deployment

`.github/workflows/pages.yml` runs on push to `main` and on `workflow_dispatch`. Steps: checkout, `ruby/setup-ruby` (Ruby 3.3, bundler cache), `actions/setup-node` (Node 22, npm cache), `npm ci`, `bundle exec rake test`, `bin/build --base-path "${{ steps.pages.outputs.base_path }}"` (from `actions/configure-pages`), `actions/upload-pages-artifact` (`_site`), then a `deploy` job with `actions/deploy-pages`. Permissions are `pages: write`, `id-token: write`, `contents: read`, with concurrency group `pages`. The README documents the one manual step: Settings → Pages → Source: GitHub Actions.

## Testing

Minitest, run with `bundle exec rake test`:

- Renderer: `.md)` stripping, heading IDs present, a fenced code block gets highlighted `<pre>`, raw HTML passes through, and `&lt;script` is unescaped.
- LinkRewriter: each rewrite rule, including fragments, nested slugs, `/docs` alone and bullettrain.co forms, plus pass-through cases, under base path `""` and `/bullet_train.github.io`.
- Page: slug/url/output_path for `index`, a top-level page and a nested page, plus title/description extraction and fallbacks.
- Menu: loads, resolves URLs, flags the active item, and matches the upstream layout URL list (a fixture-free check: every internal menu URL maps to an existing `src/docs` file).
- IndexLayout: three-column split and `in_groups(3)` distribution.
- Builder (integration, Tailwind step stubbable via an injectable command): builds into a temp dir and asserts every md file has an output page, root redirect, 404, `.nojekyll`, copied assets, no broken internal links, and the base path applied to asset URLs.

## Success criteria

- `bin/build` produces `_site/` with 57 doc pages, all internal links resolving, and images loading.
- The site renders with the blue sidebar, the same menu entries as the live site, and prose content, and the mobile menu works.
- The GitHub Actions workflow is valid and deploys `_site` to Pages.
- `bundle exec rake test` is green.
