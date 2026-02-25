# Changelog

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
