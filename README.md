# PhoenixStreamdown

Streaming markdown renderer for Phoenix LiveView, optimized for LLM output.

Inspired by [Streamdown](https://streamdown.ai/) and [vue-stream-markdown](https://github.com/jinghaihan/vue-stream-markdown), but built to fully leverage LiveView — server-side rendering, automatic DOM diffing, and zero client-side JavaScript.

## Installation

```elixir
def deps do
  [{:phoenix_streamdown, "~> 1.0.0-beta"}]
end
```

## Usage

```elixir
use PhoenixStreamdown
```

```heex
<.markdown content={@response} streaming={@streaming?} />
```

That's it. Pass `content` as a markdown string, set `streaming` to `true` while tokens are arriving. Completed blocks are frozen with `phx-update="ignore"` — only the last block re-renders on each token.

## How it works

1. **Remend** — auto-closes incomplete syntax (`**bold` → `**bold**`, unclosed fences, partial links)
2. **Blocks** — splits into independent blocks so earlier ones are stable
3. **MDEx** — renders each block to HTML server-side (Rust-backed)
4. **LiveView** — diffs only the active block, skips the rest

On a 56-block document, this is **~7x less server work** and **~460x smaller diffs** per token compared to re-rendering the full document each time.

## Example

A full chat app with [ReqLLM](https://hex.pm/packages/req_llm) streaming is in the [`example/`](example/) directory. Run it:

```bash
cd example
cp .env.example .env  # add your OpenRouter API key
mix setup
mix phx.server
```

## Documentation

**[HexDocs](https://hexdocs.pm/phoenix_streamdown)** — attributes, customization (themes, CSS classes, stable IDs, MDEx options).

## License

MIT
