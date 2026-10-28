# Compares the render strategies on a synthetic streaming response.
#
#   mix run bench/render_bench.exs
#   ITERS=100 mix run bench/render_bench.exs
#
# "pre-memoization" is what `<.markdown>` did on every token before blocks were
# cached: parse the whole source, then render every block.

defmodule RenderBench do
  @iterations (System.get_env("ITERS") || "30") |> String.to_integer()
  @block_count 56

  def run do
    document = document()

    IO.puts("""
    PhoenixStreamdown render benchmark
      mdex #{Application.spec(:mdex, :vsn)}, phoenix_live_view #{Application.spec(:phoenix_live_view, :vsn)}
      highlighting: #{if highlighting_active?(), do: "Lumis enabled", else: "disabled (run mix phoenix_streamdown.install)"}
      document:   #{block_count(document)} blocks, #{kb(document)} KB
      iterations: #{@iterations} (median per call)
    """)

    for {label, theme} <- [
          {"Lumis enabled (theme \"onedark\")", "onedark"},
          {"no highlighting (theme nil)", nil}
        ] do
      table(label, document, theme)
    end
  end

  defp table(label, document, theme) do
    full = measure(fn -> MDEx.to_html!(document, mdex_opts(theme)) end)
    pre_memo = measure(fn -> render_every_block(document, theme) end)

    cold =
      measure(fn ->
        render(document, "cold-#{System.unique_integer([:positive])}", theme)
      end)

    warm = measure_streaming(document, theme)

    IO.puts("\n#{label}")
    IO.puts(header_row())

    row("MDEx whole document", full, 1, full, pre_memo)
    row("every block, pre-memoization path", pre_memo, block_count(document), full, pre_memo)
    row("<.markdown> first render (cold cache)", cold, block_count(document), full, pre_memo)
    row("<.markdown> per streamed token (warm cache)", warm, 1, full, pre_memo)
  end

  defp header_row do
    "  " <>
      String.pad_trailing("scenario", 44) <>
      String.pad_leading("ms/op", 8) <>
      String.pad_leading("blocks", 8) <>
      String.pad_leading("vs whole", 11) <> String.pad_leading("vs pre-memo", 14)
  end

  defp row(label, ms, blocks, whole_document_ms, pre_memo_ms) do
    IO.puts(
      "  " <>
        String.pad_trailing(label, 44) <>
        String.pad_leading(Float.to_string(Float.round(ms, 1)), 8) <>
        String.pad_leading(Integer.to_string(blocks), 8) <>
        String.pad_leading(ratio(whole_document_ms, ms), 11) <>
        String.pad_leading(ratio(pre_memo_ms, ms), 14)
    )
  end

  defp ratio(baseline_ms, ms), do: Float.to_string(Float.round(baseline_ms / ms, 1)) <> "x"

  defp measure(fun) do
    fun.()
    fun.()

    samples = for _ <- 1..@iterations, do: elem(:timer.tc(fun), 0)
    median(samples)
  end

  defp measure_streaming(document, theme) do
    id = "warm-#{System.unique_integer([:positive])}"
    render(document, id, theme)

    for i <- 1..@iterations do
      content = document <> "\n\nA tail paragraph receiving token #{i}."
      elem(:timer.tc(fn -> render(content, id, theme) end), 0)
    end
    |> median()
  end

  defp median(samples) do
    samples |> Enum.sort() |> Enum.at(div(length(samples), 2)) |> Kernel./(1000)
  end

  defp highlighting_active? do
    "```elixir\nx = 1\n```"
    |> MDEx.to_html!(mdex_opts("onedark"))
    |> String.contains?("<span style=")
  end

  defp render_every_block(document, theme) do
    document
    |> PhoenixStreamdown.Blocks.parse()
    |> Enum.map(&MDEx.to_html!(&1, mdex_opts(theme)))
  end

  defp render(content, id, theme) do
    assigns = %{
      content: content,
      streaming: true,
      id: id,
      theme: theme,
      animate: nil,
      class: nil,
      block_class: nil,
      mdex_opts: [],
      __changed__: %{}
    }

    assigns
    |> PhoenixStreamdown.markdown()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp mdex_opts(theme) do
    base = [
      extension: [strikethrough: true, table: true, autolink: true, tasklist: true],
      auto_close: [links: :text, images: :text]
    ]

    case theme do
      nil ->
        base

      theme ->
        base ++
          [syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: theme}]]]
    end
  end

  defp block_count(document), do: document |> PhoenixStreamdown.Blocks.parse() |> length()
  defp kb(document), do: Float.round(byte_size(document) / 1024, 1)

  defp document do
    Enum.map_join(1..@block_count, "\n\n", fn i -> fragment(i) end)
  end

  defp fragment(i) do
    case rem(i, 4) do
      0 ->
        "## Section #{i}\n\n" <>
          String.duplicate(
            "A typical assistant paragraph arriving token by token with **bold** and `code` in it. ",
            6
          )

      1 ->
        "- first item with **bold**\n- second item with `code`\n- third item"

      2 ->
        "```elixir\ndef hello_#{i}(x) do\n  {:ok, x + 1}\nend\n```"

      3 ->
        "> A quote for section #{i}.\n>\n> Second paragraph with a [link](https://example.com)."
    end
  end
end

RenderBench.run()
