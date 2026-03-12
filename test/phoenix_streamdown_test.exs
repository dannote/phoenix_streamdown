defmodule PhoenixStreamdownTest do
  use ExUnit.Case, async: true
  use PhoenixStreamdown

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
          streaming: true
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
          streaming: true
        })

      assert html =~ ~s(phx-update="ignore")
    end

    test "renders code blocks with incomplete fence during streaming" do
      html =
        render_component(&PhoenixStreamdown.markdown/1, %{
          content: "```elixir\nIO.puts(:hello",
          streaming: true
        })

      assert html =~ "<code"
      assert html =~ "language-elixir"
    end

    test "auto-generates unique id" do
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
end
