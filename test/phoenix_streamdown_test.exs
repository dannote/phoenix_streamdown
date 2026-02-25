defmodule PhoenixStreamdownTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

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

    test "applies custom id prefix" do
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
end
