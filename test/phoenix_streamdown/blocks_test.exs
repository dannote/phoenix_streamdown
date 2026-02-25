defmodule PhoenixStreamdown.BlocksTest do
  use ExUnit.Case, async: true

  alias PhoenixStreamdown.Blocks

  describe "parse/1" do
    test "splits on blank lines" do
      assert Blocks.parse("# Title\n\nParagraph one\n\nParagraph two") ==
               ["# Title", "Paragraph one", "Paragraph two"]
    end

    test "returns empty list for nil" do
      assert Blocks.parse(nil) == []
    end

    test "returns empty list for empty string" do
      assert Blocks.parse("") == []
    end

    test "single block" do
      assert Blocks.parse("just text") == ["just text"]
    end

    test "filters empty blocks" do
      assert Blocks.parse("text\n\n\n\nmore") == ["text", "more"]
    end
  end

  describe "code block merging" do
    test "keeps code block with blank lines as single block" do
      input = "```\nline 1\n\nline 2\n```"
      assert Blocks.parse(input) == [input]
    end

    test "keeps code block with language tag intact" do
      input = "```elixir\ndef hello do\n\n  :world\nend\n```"
      assert Blocks.parse(input) == [input]
    end

    test "separates text before and after code block" do
      input = "Before\n\n```\ncode\n```\n\nAfter"
      assert Blocks.parse(input) == ["Before", "```\ncode\n```", "After"]
    end

    test "handles unclosed code fence as single block" do
      input = "Before\n\n```\ncode\n\nmore code"
      blocks = Blocks.parse(input)
      assert length(blocks) == 2
      assert hd(blocks) == "Before"
    end
  end

  describe "math block merging" do
    test "keeps math block with blank lines as single block" do
      input = "$$\nx^2\n\n+ y^2\n$$"
      assert Blocks.parse(input) == [input]
    end
  end

  describe "html block merging" do
    test "keeps multi-line HTML block intact" do
      input = "<div>\n\n<p>content</p>\n\n</div>"
      assert Blocks.parse(input) == [input]
    end
  end
end
