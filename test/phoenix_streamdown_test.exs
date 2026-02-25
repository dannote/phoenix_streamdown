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
  end
end
