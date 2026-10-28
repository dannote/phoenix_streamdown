# Changelog

## Unreleased

### Breaking changes

- `id` is required when `streaming: true`. A generated id changed on every render, so LiveView could not match the existing blocks: `phx-update="ignore"` never applied and the whole markdown subtree was replaced on every chunk. `<.markdown>` now raises with instructions instead of silently losing the optimisation.

### Fixes

- Log the MDEx exception (once per distinct failure and process) instead of silently rendering escaped plain text when a block fails to render
- Keep loose lists, nested lists, list continuation paragraphs and indented code blocks in a single block, so they no longer render as N separate lists or code blocks
- Tighten the `mdex` requirement to `~> 0.11.0`; 0.12 and newer removed the bundled Lumis highlighter, so the default options raise `Lumis is not enabled.` there

## 1.0.0-beta.4

### Fixes

- Fix content loss when a streamed block transitions from active to frozen in a batched LiveView render
- Clean up transition tracking state when explicit-id streams finish
- Avoid transition tracking for generated IDs
- Fix fallback render warning

## 1.0.0-beta.3

### Features

- **Word-level streaming animations** — new `animate` attribute enables per-word fade-in during streaming, inspired by [Vercel's Streamdown](https://github.com/vercel/streamdown). Three built-in animations: `fadeIn`, `blurIn`, `slideUp`. Pure server-side — no JS hooks required.

  ```heex
  <.markdown content={@response} streaming animate="fadeIn" />
  ```

- Ship `priv/static/phoenix_streamdown.css` with animation keyframes. Include in your app:

  ```css
  @import "../../deps/phoenix_streamdown/priv/static/phoenix_streamdown.css";
  ```

### Improvements

- `mix ci` alias: `compile --warnings-as-errors`, `test`, `credo --strict`, `dialyzer`
- `priv/static/` included in hex package

## 1.0.0-beta.2

### Improvements

- `use PhoenixStreamdown` imports `markdown/1` for `<.markdown />` syntax
- Slimmed README — detailed docs moved to HexDocs moduledoc
- Added benchmark data: ~7x less server CPU, ~460x smaller diffs on 56-block documents
- Made `Remend` helper functions private (only `complete/1` is public API)
- Added "Why not just MDEx streaming?" section to docs

## 1.0.0-beta.1

Initial beta release.

### Features

- `PhoenixStreamdown.markdown/1` — LiveView component for streaming markdown
- Block-level memoization via `phx-update="ignore"` on completed blocks
- `PhoenixStreamdown.Remend` — auto-closes incomplete markdown syntax (bold, italic, code fences, inline code, strikethrough, links, images, math blocks)
- `PhoenixStreamdown.Blocks` — splits markdown into independent blocks, merges code fences, math blocks, and HTML blocks that span blank lines
- 100+ syntax highlighting themes via [Lumis](https://lumis.sh)
- GFM extensions enabled by default (strikethrough, tables, autolinks, task lists)
- Deep-mergeable `mdex_opts` for full MDEx control
- Auto-generated unique IDs (stable explicit IDs supported)
