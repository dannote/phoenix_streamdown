defmodule PhoenixStreamdown do
  @moduledoc """
  Streaming markdown renderer for Phoenix LiveView.

  Renders LLM-streamed markdown with proper handling of incomplete syntax,
  block-level memoization, and minimal DOM updates.

  ## Usage

      <PhoenixStreamdown.markdown
        content={@current_response}
        streaming={@streaming?}
      />

  ## How it works

  1. **Remend** — auto-closes incomplete markdown syntax (`**bold` → `**bold**`)
  2. **Blocks** — splits markdown into independent blocks
  3. **Render** — converts each block to HTML via MDEx
  4. **Diff** — LiveView only patches the last (active) block

  Completed blocks get `phx-update="ignore"` so LiveView skips them entirely.
  """

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
    * `class` — CSS class for the wrapper div
    * `mdex_opts` — options passed to `MDEx.to_html!/2`

  ## Examples

      <PhoenixStreamdown.markdown content="# Hello **world**" />

      <PhoenixStreamdown.markdown
        content={@response}
        streaming={@streaming?}
        class="prose"
      />
  """
  attr :content, :string, default: ""
  attr :streaming, :boolean, default: false
  attr :class, :any, default: nil
  attr :mdex_opts, :list, default: []

  def markdown(assigns) do
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
      |> Enum.map(fn {block, idx} -> {idx, block} end)

    mdex_opts = Keyword.merge(@default_mdex_opts, assigns.mdex_opts)
    last_idx = length(blocks) - 1

    rendered_blocks =
      Enum.map(blocks, fn {idx, block} ->
        {idx, render_block(block, mdex_opts), idx == last_idx}
      end)

    assigns =
      assigns
      |> assign(:rendered_blocks, rendered_blocks)
      |> assign(:last_idx, last_idx)

    ~H"""
    <div class={["phoenix-streamdown", @class]}>
      <div
        :for={{idx, html, is_last} <- @rendered_blocks}
        id={"psd-block-#{idx}"}
        phx-update={unless(is_last and @streaming, do: "ignore")}
      >
        {raw(html)}
      </div>
    </div>
    """
  end

  defp render_block(block, mdex_opts) do
    MDEx.to_html!(block, mdex_opts)
  rescue
    _ -> "<p>#{Phoenix.HTML.html_escape(block)}</p>"
  end
end
