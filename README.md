# PhoenixStreamdown

Streaming markdown renderer for Phoenix LiveView, optimized for LLM output.

Inspired by [Streamdown](https://streamdown.ai/) and [vue-stream-markdown](https://github.com/jinghaihan/vue-stream-markdown), but built to fully leverage LiveView's architecture — server-side rendering, automatic DOM diffing, and zero client-side JavaScript.

## How It Works

1. **Remend** — auto-closes incomplete markdown syntax (`**bold` → `**bold**`, unclosed code fences, partial links)
2. **Blocks** — splits markdown into independent blocks so only the last one re-renders
3. **MDEx** — converts each block to HTML server-side (Rust-backed, fast)
4. **LiveView** — diffs and patches only what changed over the existing WebSocket

Completed blocks get `phx-update="ignore"` — LiveView skips them entirely. Only the active (last) block gets diffed on each token.

## Installation

```elixir
def deps do
  [
    {:phoenix_streamdown, "~> 0.1.0"},
    {:req_llm, "~> 1.6"} # optional, for the streaming example below
  ]
end
```

## Usage

### Basic

```heex
<PhoenixStreamdown.markdown
  content={@response}
  streaming={@streaming?}
  class="prose dark:prose-invert"
/>
```

### Full Chat with ReqLLM

```elixir
defmodule MyAppWeb.ChatLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      messages: [],
      current_response: "",
      streaming?: false,
      form: to_form(%{"prompt" => ""})
    )}
  end

  def handle_event("submit", %{"prompt" => prompt}, socket) do
    messages = socket.assigns.messages ++ [%{role: :user, content: prompt}]

    context = [
      ReqLLM.Context.system("You are a helpful assistant. Respond in markdown."),
      ReqLLM.Context.user(prompt)
    ]

    {:ok, response} = ReqLLM.stream_text("anthropic:claude-sonnet-4-20250514", context)

    pid = self()

    Task.start(fn ->
      response
      |> ReqLLM.StreamResponse.tokens()
      |> Enum.each(&send(pid, {:token, &1}))

      send(pid, :stream_done)
    end)

    {:noreply, assign(socket,
      messages: messages,
      current_response: "",
      streaming?: true,
      form: to_form(%{"prompt" => ""})
    )}
  end

  def handle_info({:token, token}, socket) do
    {:noreply, assign(socket, :current_response, socket.assigns.current_response <> token)}
  end

  def handle_info(:stream_done, socket) do
    messages = socket.assigns.messages ++ [
      %{role: :assistant, content: socket.assigns.current_response}
    ]

    {:noreply, assign(socket,
      messages: messages,
      current_response: "",
      streaming?: false
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="chat">
      <div :for={msg <- @messages} class={"message #{msg.role}"}>
        <PhoenixStreamdown.markdown content={msg.content} />
      </div>

      <div :if={@streaming?} class="message assistant">
        <PhoenixStreamdown.markdown content={@current_response} streaming />
      </div>

      <.form for={@form} phx-submit="submit">
        <.input field={@form[:prompt]} placeholder="Ask something..." />
        <button type="submit" disabled={@streaming?}>Send</button>
      </.form>
    </div>
    """
  end
end
```

## Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | `string` | `""` | Markdown string to render |
| `streaming` | `boolean` | `false` | Enable incomplete syntax completion |
| `class` | `string` | `nil` | CSS class for the wrapper div |
| `mdex_opts` | `keyword` | `[]` | Options passed to `MDEx.to_html!/2` |

## Why Not Just MDEx Streaming?

MDEx has its own `streaming: true` mode that also handles incomplete syntax. PhoenixStreamdown adds:

- **Block-level memoization** — only the last block re-renders, earlier blocks are frozen with `phx-update="ignore"`
- **A ready-made LiveView component** — drop it in, pass content and streaming flag
- **Remend layer** — handles edge cases like partial links/images (strip rather than render broken HTML)

For simple cases, MDEx streaming alone may be sufficient. PhoenixStreamdown is worth it when rendering long, multi-block LLM responses where you want minimal DOM churn.

## License

MIT
