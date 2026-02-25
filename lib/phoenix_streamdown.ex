defmodule PhoenixStreamdown do
  @moduledoc """
  Streaming markdown renderer for Phoenix LiveView.

  Renders LLM-streamed markdown with proper handling of incomplete syntax,
  block-level memoization, and minimal DOM updates.

  ## Usage

      use PhoenixStreamdown

      <.markdown content={@response} streaming={@streaming?} />

  Or without importing:

      <PhoenixStreamdown.markdown content={@response} streaming={@streaming?} />

  ## How it works

  1. `PhoenixStreamdown.Remend` — auto-closes incomplete markdown syntax
     (`**bold` → `**bold**`, unclosed code fences, partial links)
  2. `PhoenixStreamdown.Blocks` — splits markdown into independent blocks
  3. [MDEx](https://hex.pm/packages/mdex) — renders each block to HTML server-side (Rust-backed)
  4. LiveView — diffs only the active block, skips the rest

  Completed blocks get `phx-update="ignore"` so LiveView skips them entirely.
  On a 56-block document, this means **~7x less server CPU** and **~460x smaller
  diffs** per token compared to re-rendering the full document each time.

  ## Customization

  ### Syntax highlighting theme

      <.markdown content={@md} theme="catppuccin_mocha" />

  Available themes: `onedark` (default), `dracula`, `github_dark`, `github_light`,
  `catppuccin_mocha`, `nord`, `tokyonight_night`, `vscode_dark`, and
  [100+ more](https://lumis.sh).

  ### CSS classes

      <.markdown content={@md} class="prose" block_class="mb-4" />

  ### Stable IDs

  Each component auto-generates a unique `id`. For completed messages in a list,
  pass a stable ID to preserve frozen blocks across re-renders:

      <.markdown content={msg.content} id={"msg-\#{msg.id}"} />

  The streaming component doesn't need an explicit `id` — it's ephemeral.

  ### MDEx options

  Options are deep-merged with defaults, so you only override what you need:

      <.markdown content={@md} mdex_opts={[extension: [shortcodes: true]]} />

  ## Why not just MDEx streaming?

  MDEx has its own `streaming: true` mode. PhoenixStreamdown adds:

  - **Block-level memoization** — only the last block re-renders per token
  - **Ready-made LiveView component** — drop in, pass content and streaming flag
  - **Remend** — strips partial links/images instead of rendering broken HTML
  """

  @doc """
  Imports the `markdown/1` component for use as `<.markdown />`.

      defmodule MyAppWeb.ChatLive do
        use MyAppWeb, :live_view
        use PhoenixStreamdown

        def render(assigns) do
          ~H\"\"\"
          <.markdown content={@response} streaming={@streaming?} />
          \"\"\"
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      import PhoenixStreamdown, only: [markdown: 1]
    end
  end

  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  alias PhoenixStreamdown.Blocks
  alias PhoenixStreamdown.Remend

  @default_mdex_opts [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      tasklist: true
    ]
  ]

  @doc """
  Renders markdown content with streaming support.

  ## Attributes

    * `content` — the markdown string to render
    * `streaming` — whether content is still being streamed (enables incomplete syntax completion)
    * `class` — CSS class for the wrapper `<div>`
    * `block_class` — CSS class for each block `<div>`
    * `id` — unique ID prefix (auto-generated; pass explicitly for stable IDs across re-renders)
    * `theme` — syntax highlighting theme name (default: `"onedark"`)
    * `mdex_opts` — options passed to `MDEx.to_html!/2` (merged with defaults)

  ## Examples

      <PhoenixStreamdown.markdown content="# Hello **world**" />

      <PhoenixStreamdown.markdown
        content={@response}
        streaming={@streaming?}
        class="prose"
        theme="github_dark"
      />
  """
  attr :content, :string, default: ""
  attr :streaming, :boolean, default: false
  attr :class, :any, default: nil
  attr :block_class, :any, default: nil
  attr :id, :string
  attr :theme, :string, default: "onedark"
  attr :mdex_opts, :list, default: []

  def markdown(assigns) do
    assigns = assign_new(assigns, :id, fn -> "psd-#{System.unique_integer([:positive])}" end)

    completed =
      if assigns.streaming do
        Remend.complete(assigns.content || "")
      else
        assigns.content || ""
      end

    blocks =
      completed
      |> Blocks.parse()
      |> Enum.with_index()

    mdex_opts = build_mdex_opts(assigns.mdex_opts, assigns.theme)
    last_idx = length(blocks) - 1

    rendered_blocks =
      Enum.map(blocks, fn {block, idx} ->
        {idx, render_block(block, mdex_opts), idx == last_idx}
      end)

    assigns =
      assigns
      |> assign(:rendered_blocks, rendered_blocks)
      |> assign(:last_idx, last_idx)

    ~H"""
    <div class={["phoenix-streamdown", @class]} id={@id}>
      <div
        :for={{idx, html, is_last} <- @rendered_blocks}
        id={"#{@id}-block-#{idx}"}
        class={@block_class}
        phx-update={unless(is_last and @streaming, do: "ignore")}
      >
        {raw(html)}
      </div>
    </div>
    """
  end

  defp build_mdex_opts(user_opts, theme) do
    theme_opts = [
      syntax_highlight: [
        formatter: {:html_inline, [theme: theme]}
      ]
    ]

    @default_mdex_opts
    |> deep_merge(theme_opts)
    |> deep_merge(user_opts)
  end

  defp deep_merge(base, override) do
    Keyword.merge(base, override, fn _key, v1, v2 ->
      if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end

  defp render_block(block, mdex_opts) do
    MDEx.to_html!(block, mdex_opts)
  rescue
    _ -> "<p>#{Phoenix.HTML.html_escape(block)}</p>"
  end
end
