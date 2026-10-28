defmodule PhoenixStreamdownTest do
  use ExUnit.Case, async: true
  use PhoenixStreamdown

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  describe "use PhoenixStreamdown" do
    test "imports markdown/1 for <.markdown /> syntax" do
      html = render_component(&markdown/1, %{content: "**hello**"})

      assert html =~ "<strong>"
      assert html =~ "hello"
    end
  end

  describe "markdown/1" do
    test "renders basic markdown" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Hello",
          streaming: false
        })

      assert html =~ "<h1>"
      assert html =~ "Hello"
    end

    test "renders with streaming flag" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "**incomplete bold",
          streaming: true,
          id: "streaming"
        })

      assert html =~ "<strong>"
      assert html =~ "incomplete bold"
    end

    test "handles empty content" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "",
          streaming: false
        })

      assert html =~ "phoenix-streamdown"
    end

    test "handles nil content" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: nil,
          streaming: false
        })

      assert html =~ "phoenix-streamdown"
    end

    test "applies custom class" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "text",
          streaming: false,
          class: "prose dark:prose-invert"
        })

      assert html =~ "prose dark:prose-invert"
    end

    test "renders multiple blocks" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\nParagraph\n\n- item",
          streaming: false
        })

      assert html =~ "<h1>"
      assert html =~ "Paragraph"
      assert html =~ "<li>"
    end

    test "sets phx-update=ignore on completed blocks during streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\nStill typing",
          streaming: true,
          id: "ignore-check"
        })

      assert html =~ ~s(phx-update="ignore")
    end

    test "renders code blocks with incomplete fence during streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello",
          streaming: true,
          id: "code-stream"
        })

      assert html =~ "<code"
      assert html =~ "language-elixir"
    end

    test "keeps the label of an incomplete link during streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Read [the docs](https://exa",
          streaming: true,
          id: "partial-link"
        })

      assert html =~ "the docs"
      refute html =~ "<a "
      refute html =~ "https://exa"
    end

    test "keeps the alt text of an incomplete image during streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Here ![Chart](https://cdn.exa",
          streaming: true,
          id: "partial-image"
        })

      assert html =~ "Chart"
      refute html =~ "<img"
      refute html =~ "https://cdn.exa"
    end

    test "completes a table row that is still arriving" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "| a | b |\n|---|---|\n| 1",
          streaming: true,
          id: "partial-table"
        })

      assert html =~ "<table>"
      assert html =~ "<td>1</td>"
      assert html =~ "<td></td>"
    end

    test "does not complete anything when not streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Some **bol"
        })

      refute html =~ "<strong>"
      assert html =~ "**bol"
    end

    test "auto-generates an id when not streaming" do
      html1 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello"
        })

      html2 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello"
        })

      [_, id1] = Regex.run(~r/id="(psd-\d+)"/, html1)
      [_, id2] = Regex.run(~r/id="(psd-\d+)"/, html2)
      assert id1 != id2
    end

    test "raises when streaming without an explicit id" do
      assert_raise ArgumentError, ~r/requires an explicit `id`/, fn ->
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello",
          streaming: true
        })
      end
    end

    test "keeps the id stable across streaming renders" do
      html1 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello",
          streaming: true,
          id: "stable"
        })

      html2 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello\n\nWorld",
          streaming: true,
          id: "stable"
        })

      assert html1 =~ ~s(id="stable")
      assert html2 =~ ~s(id="stable")
      assert html2 =~ ~s(id="stable-block-1")
    end

    test "accepts explicit id prefix" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\nParagraph",
          id: "msg-42"
        })

      assert html =~ ~s(id="msg-42")
      assert html =~ ~s(id="msg-42-block-0")
      assert html =~ ~s(id="msg-42-block-1")
    end

    test "applies block_class to each block" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\nParagraph",
          block_class: "mb-4"
        })

      assert length(Regex.scan(~r/class="mb-4"/, html)) == 2
    end

    test "applies syntax highlighting theme" do
      default_html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello)\n```"
        })

      themed_html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello)\n```",
          theme: "dracula"
        })

      assert default_html =~ "<span style="
      assert themed_html =~ "<span style="
      assert default_html != themed_html
    end

    test "renders code blocks without highlighting when theme is nil" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello)\n```",
          theme: nil
        })

      refute html =~ "<span style="
      assert html =~ ~s(<code class="language-elixir")
      assert html =~ "IO.puts"
    end

    test "renders code blocks unhighlighted and warns once when the highlighter is unavailable" do
      render_without_highlighter = fn ->
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello)\n```",
          mdex_opts: [syntax_highlight: [engine: :bogus]]
        })
      end

      logs =
        capture_log(fn ->
          for _ <- 1..2 do
            html = render_without_highlighter.()

            refute html =~ "<span style="
            assert html =~ ~s(<code class="language-elixir")
            assert html =~ "IO.puts"
          end
        end)

      assert logs =~ "without highlighting"
      assert length(String.split(logs, "without highlighting")) == 2
    end

    test "deep-merges mdex_opts with defaults" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "~~deleted~~",
          mdex_opts: [extension: [strikethrough: true]]
        })

      assert html =~ "<del>"
    end
  end

  describe "block transition during streaming" do
    test "previously-last block is not frozen on the render where new block appears" do
      id = "test-transition"

      # Render 1: single block, block-0 is last
      _html1 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello world",
          streaming: true,
          id: id
        })

      # Render 2: content grew AND a new block appeared (simulates batched deltas)
      # Block-0's content changed from "Hello world" to "Hello world extended"
      # Block-1 is now the last block
      html2 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello world extended\n\nSecond paragraph",
          streaming: true,
          id: id
        })

      # Block-0 just transitioned from last to not-last.
      # It MUST NOT have phx-update="ignore" on this render, because
      # its content changed and the client needs to receive the update.
      [block_0_div] = Regex.run(~r/<div[^>]*id="#{id}-block-0"[^>]*>/, html2)

      refute block_0_div =~ ~s(phx-update="ignore"),
             "Block 0 just transitioned from last to not-last; " <>
               "it needs one final update before being frozen"
    end

    test "cleans up transition tracking when explicit-id stream finishes" do
      id = "test-cleanup"

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "Hello",
        streaming: true,
        id: id
      })

      assert {PhoenixStreamdown, :last_idx, id} in transition_tracking_keys()

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "Hello",
        streaming: false,
        id: id
      })

      refute {PhoenixStreamdown, :last_idx, id} in transition_tracking_keys()
    end

    test "block is frozen on the render AFTER it transitions" do
      id = "test-freeze-after"

      # Render 1: single block
      _html1 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello world",
          streaming: true,
          id: id
        })

      # Render 2: new block appears, block-0 transitions
      _html2 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello world extended\n\nSecond paragraph",
          streaming: true,
          id: id
        })

      # Render 3: same block structure, block-0 should now be frozen
      html3 =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "Hello world extended\n\nSecond paragraph continues",
          streaming: true,
          id: id
        })

      [block_0_div] = Regex.run(~r/<div[^>]*id="#{id}-block-0"[^>]*>/, html3)

      assert block_0_div =~ ~s(phx-update="ignore"),
             "Block 0 should be frozen after its transition render"
    end
  end

  describe "render failures" do
    test "logs the error and falls back to escaped text when MDEx raises" do
      log =
        capture_log(fn ->
          html =
            render_component(&PhoenixStreamdown.markdown/1, %{
              content: "**bold** <script>alert(1)</script>",
              mdex_opts: [extension: [table: :invalid]]
            })

          refute html =~ "<strong>"
          assert html =~ "**bold**"
          assert html =~ "&lt;script&gt;"
        end)

      assert log =~ "PhoenixStreamdown"
      assert log =~ "NimbleOptions.ValidationError"
    end

    test "logs a repeated failure only once per process" do
      render_with_bad_opts = fn ->
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "first",
          mdex_opts: [extension: [table: :invalid]]
        })
      end

      first_log = capture_log(render_with_bad_opts)
      second_log = capture_log(render_with_bad_opts)

      assert first_log =~ "NimbleOptions.ValidationError"
      assert second_log == ""
    end
  end

  describe "block memoization" do
    test "reuses the rendered html of a block whose source did not change" do
      id = "cache-reuse"

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "# Title\n\nfirst paragraph",
        streaming: true,
        id: id
      })

      poison_cached_html(id, 0, "REUSED")

      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\nfirst paragraph continues",
          streaming: true,
          id: id
        })

      assert html =~ "REUSED"
      assert html =~ "first paragraph continues"
    end

    test "renders a block again when its source changed" do
      id = "cache-invalidate"

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "# Title\n\nfirst paragraph",
        streaming: true,
        id: id
      })

      poison_cached_html(id, 0, "STALE")

      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Renamed\n\nfirst paragraph",
          streaming: true,
          id: id
        })

      refute html =~ "STALE"
      assert html =~ "Renamed"
    end

    test "re-renders every block when the rendering options change" do
      id = "cache-opts"

      themed =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\n```elixir\nIO.puts(:a)\n```",
          theme: "onedark",
          id: id
        })

      poison_cached_html(id, 0, "STALE")

      dracula =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "# Title\n\n```elixir\nIO.puts(:a)\n```",
          theme: "dracula",
          id: id
        })

      refute dracula =~ "STALE"
      assert themed != dracula
    end

    test "drops cached blocks when the document shrinks" do
      id = "cache-trim"

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "first\n\nsecond\n\nthird",
        streaming: true,
        id: id
      })

      assert map_size(block_cache(id)) == 3

      render_component(&PhoenixStreamdown.markdown/1, %{
        content: "first",
        streaming: true,
        id: id
      })

      assert map_size(block_cache(id)) == 1
    end
  end

  defp block_cache(id) do
    {_mdex_opts, cached} = Process.get({PhoenixStreamdown, :block_html, id})
    cached
  end

  defp poison_cached_html(id, idx, html) do
    key = {PhoenixStreamdown, :block_html, id}
    {mdex_opts, cached} = Process.get(key)

    Process.put(
      key,
      {mdex_opts, Map.update!(cached, idx, fn {block, _html} -> {block, html} end)}
    )
  end

  defp transition_tracking_keys do
    Process.get_keys()
    |> Enum.filter(&match?({PhoenixStreamdown, :last_idx, _id}, &1))
    |> Enum.sort()
  end
end
