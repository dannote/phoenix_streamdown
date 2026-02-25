defmodule PhoenixStreamdown.RemendTest do
  use ExUnit.Case, async: true

  alias PhoenixStreamdown.Remend

  describe "complete/1" do
    test "returns empty string for nil" do
      assert Remend.complete(nil) == ""
    end

    test "returns empty string for empty string" do
      assert Remend.complete("") == ""
    end

    test "passes through complete markdown" do
      assert Remend.complete("**bold**") == "**bold**"
    end
  end

  describe "code fences" do
    test "closes unclosed code fence" do
      assert Remend.complete("```elixir\nIO.puts") == "```elixir\nIO.puts\n```"
    end

    test "closes unclosed tilde fence" do
      assert Remend.complete("~~~\ncode") == "~~~\ncode\n~~~"
    end

    test "does not double-close a complete fence" do
      input = "```\ncode\n```"
      assert Remend.complete(input) == input
    end

    test "closes fence with language tag" do
      assert Remend.complete("```python\ndef foo():") == "```python\ndef foo():\n```"
    end
  end

  describe "inline code" do
    test "closes unclosed inline code" do
      assert Remend.complete("here is `code") == "here is `code`"
    end

    test "does not close complete inline code" do
      assert Remend.complete("`code`") == "`code`"
    end

    test "does not close backticks inside code blocks" do
      input = "```\n`partial\n```"
      assert Remend.complete(input) == input
    end
  end

  describe "bold and italic" do
    test "closes unclosed bold" do
      assert Remend.complete("**bold text") == "**bold text**"
    end

    test "closes unclosed italic with asterisk" do
      assert Remend.complete("*italic text") == "*italic text*"
    end

    test "closes unclosed italic with underscore" do
      assert Remend.complete("_italic text") == "_italic text_"
    end

    test "closes unclosed bold italic" do
      assert Remend.complete("***bold italic") == "***bold italic***"
    end

    test "does not close complete bold" do
      assert Remend.complete("**bold**") == "**bold**"
    end

    test "handles escaped markers" do
      assert Remend.complete("\\*not italic") == "\\*not italic"
    end

    test "does not touch markers inside code blocks" do
      input = "```\n**not bold\n```"
      assert Remend.complete(input) == input
    end
  end

  describe "strikethrough" do
    test "closes unclosed strikethrough" do
      assert Remend.complete("~~deleted text") == "~~deleted text~~"
    end

    test "does not close complete strikethrough" do
      assert Remend.complete("~~deleted~~") == "~~deleted~~"
    end
  end

  describe "links and images" do
    test "strips incomplete image" do
      assert Remend.complete("text ![alt](http://exam") == "text "
    end

    test "strips image with incomplete alt" do
      assert Remend.complete("text ![incom") == "text "
    end

    test "shows link text for incomplete link" do
      assert Remend.complete("check [this link](http://exam") == "check this link"
    end

    test "shows text for incomplete link bracket" do
      assert Remend.complete("check [this link") == "check this link"
    end

    test "does not touch complete links" do
      input = "[text](http://example.com)"
      assert Remend.complete(input) == input
    end
  end

  describe "math blocks" do
    test "closes unclosed math block" do
      assert Remend.complete("$$\nx^2 + y^2") == "$$\nx^2 + y^2$$"
    end

    test "does not close complete math block" do
      input = "$$\nx^2\n$$"
      assert Remend.complete(input) == input
    end
  end

  describe "trailing spaces" do
    test "strips single trailing space" do
      assert Remend.complete("text ") == "text"
    end

    test "preserves double trailing space (line break)" do
      assert Remend.complete("text  ") == "text  "
    end
  end
end
