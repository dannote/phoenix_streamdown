# Changelog

## Unreleased

### Breaking changes

- `id` is required when `streaming: true`. A generated id changed on every render, so LiveView could not match the existing blocks: `phx-update="ignore"` never applied and the whole markdown subtree was replaced on every chunk. `<.markdown>` now raises with instructions instead of silently losing the optimisation.
- `PhoenixStreamdown.Remend` is gone. MDEx's `auto_close` does the same job in Rust and also completes tables, so the component passes `auto_close: [links: :text, images: :text]` while streaming. Call `MDEx.to_html!/2` with `auto_close: true` if you used `Remend.complete/1` directly, and pass `mdex_opts={[auto_close: false]}` to render the raw source instead.
- `mdex` is now `~> 0.14`. 0.13 and newer no longer bundle the Lumis highlighter, so syntax highlighting is opt-in: configure `mdex_native` with Lumis and add a parser package to keep it. Without it, code blocks render unhighlighted and one warning is logged; pass `theme={nil}` to turn highlighting off explicitly.

### Changed

- Update `phoenix_live_view` to 1.2 and the dev/test tooling to the latest versions
- Render a block only when its source or the rendering options changed, so a streamed token re-renders the last block instead of every block. Completed messages in a list keep their rendered HTML until their content changes.
- Add `mix phoenix_streamdown.install`, which writes the `mdex_native` Lumis config and adds a parser package

### Fixes

- Log the MDEx exception (once per distinct failure and process) instead of silently rendering escaped plain text when a block fails to render
- Keep loose lists, nested lists, list continuation paragraphs and indented code blocks in a single block, so they no longer render as N separate lists or code blocks

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
