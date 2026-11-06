# Bullet Train Developer Documentation

A static build of the Bullet Train v1.45.1 developer docs, published on GitHub Pages.

Live site: https://tujucreative.github.io/bullet_train.github.io/docs/

The Markdown sources come from [`bullet_train-core`](https://github.com/bullet-train-co/bullet_train-core) (`bullet_train/docs`, tag `v1.45.1`) and are vendored unmodified in `src/docs`. Logo and image assets come from the Bullet Train demo site. A small plain-Ruby builder renders the pages, rewrites links, and runs Tailwind CSS. There is no Rails or ActiveSupport.

## Prerequisites

- Ruby 3.3
- Node 22

```sh
bundle install
npm install
```

## Commands

```sh
bin/serve              # build with base path "" and serve at http://localhost:4000 (optional PORT argument)
bin/build              # build into _site/ with the default base path /bullet_train.github.io
bin/build --base-path "" --out tmp/site   # custom base path and output directory
bin/build --site-url https://docs.example.com   # origin for og:url and canonical links (or SITE_URL)
bundle exec rake test  # run the test suite (also the default rake task)
bin/sync-docs [REF]    # re-vendor docs from bullet_train-core at REF (default v1.45.1)
```

The output directory is deleted and rebuilt on every build. To protect other files, `bin/build` only replaces a directory that is missing, empty, or a previous build (marked by a `.docs-site-build` file); anything else fails the build.

The build fails if any internal `/docs` link does not resolve to a page, or, under a base path, if any root-relative link or image lacks that prefix. Links to other paths on the live site (such as `/users/sign_up`) are pointed at `https://bullettrain.co`. One known-broken upstream link is corrected in `LinkRewriter::LINK_FIXUPS`.

Testing note: the upstream-layout check in `test/menu_test.rb` is skipped unless `BT_CORE_DIR` points at a `bullet_train-core` checkout.

## Layout

```
bin/            build, serve, sync-docs
lib/docs_site/  builder, renderer, link rewriter, menu, page, layout
src/docs/       vendored upstream Markdown (do not edit by hand)
src/UPSTREAM    upstream repository and ref the docs were synced from
src/menu.yml    sidebar menu
src/layout.html.erb, styles.css, menu.js
src/assets/     static files copied to the site root (logo/, upgrade-images/)
test/           Minitest suite
.github/workflows/pages.yml   deploy workflow
```

## Deployment

Merging to `main` deploys the site (the workflow can also be started manually with `workflow_dispatch`). The workflow installs dependencies, runs the tests, builds with the base path supplied by `actions/configure-pages`, and deploys `_site` to Pages.

One-time repository setting: Settings → Pages → Build and deployment → Source: GitHub Actions.

### Custom domain

Set the custom domain in Settings → Pages. With Actions deploys no `CNAME` file is needed: `actions/configure-pages` reports the domain's origin and an empty base path, and the workflow passes both to `bin/build` (`--site-url` and `--base-path`), so no workflow change is needed.

## License

The documentation content is © Bullet Train, Inc. and licensed under the MIT License (see the upstream `MIT-LICENSE` in `bullet_train-core`).
