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

  describe "list merging" do
    test "keeps a loose bullet list as a single block" do
      input = "- a\n\n- b\n\n- c"
      assert Blocks.parse(input) == [input]
    end

    test "keeps a loose ordered list as a single block" do
      input = "1. a\n\n2. b"
      assert Blocks.parse(input) == [input]
    end

    test "keeps an indented continuation paragraph with its list" do
      input = "- a\n\n  continued\n\n- b"
      assert Blocks.parse(input) == [input]
    end

    test "keeps nested lists with blank lines as a single block" do
      input = "- a\n\n  - a1\n\n  - a2\n\n- b"
      assert Blocks.parse(input) == [input]
    end

    test "keeps items indented differently in the same list" do
      for input <- ["- a\n\n - b", "  - a\n\n- b", "1. a\n\n  2. b"] do
        assert Blocks.parse(input) == [input]
      end
    end

    test "keeps content after a wide item marker together" do
      input = "-     code\n\n  more"
      assert Blocks.parse(input) == [input]
    end

    test "keeps a tab-indented nested list together" do
      input = "- a\n\n\t- b"
      assert Blocks.parse(input) == [input]
    end

    test "does not merge a paragraph after a list" do
      assert Blocks.parse("- a\n\n- b\n\nAfter") == ["- a\n\n- b", "After"]
    end

    test "does not merge a different list type into the previous list" do
      assert Blocks.parse("- a\n\n1. b") == ["- a", "1. b"]
    end

    test "does not merge a list into a preceding paragraph" do
      assert Blocks.parse("Before\n\n- a\n\n- b") == ["Before", "- a\n\n- b"]
    end

    test "does not treat a thematic break as a list item" do
      assert Blocks.parse("---\n\n- a") == ["---", "- a"]
    end
  end

  describe "blockquote boundaries" do
    test "keeps blank-line separated blockquotes separate, as CommonMark does" do
      assert Blocks.parse("> a\n\n> b") == ["> a", "> b"]
    end

    test "keeps a multi-paragraph blockquote as a single block" do
      input = "> a\n>\n> b"
      assert Blocks.parse(input) == [input]
    end

    test "keeps a list inside a blockquote together" do
      input = "> - a\n>\n> - b"
      assert Blocks.parse(input) == [input]
    end
  end

  describe "indented code merging" do
    test "keeps a blank-line separated indented code block as a single block" do
      input = "    code1\n\n    code2"
      assert Blocks.parse(input) == [input]
    end

    test "does not merge an indented code block into a preceding paragraph" do
      assert Blocks.parse("Before\n\n    code") == ["Before", "    code"]
    end
  end

  describe "block boundaries match a full-document render" do
    @cases [
      "- a\n\n- b\n\n- c",
      "1. a\n\n2. b",
      "> a\n\n> b",
      "> a\n>\n> b",
      "- a\n\n- b\n\nAfter",
      "- a\n\n  - a1\n\n  - a2\n\n- b",
      "- a\n\n  continued\n\n- b",
      "1. a\n\n   continued\n\n2. b",
      "1. a\n\n  not a continuation\n\n2. b",
      "- a\n\n - b",
      "  - a\n\n- b",
      "1. a\n\n  2. b",
      "-     code\n\n  more",
      "- a\n\n  1. b",
      "- a\n\n 1. b",
      "- a\n\n\t- b",
      "    code1\n\n    code2",
      "Before\n\n- a\n\n- b",
      "- a\n\n> b",
      "- a\n\n---\n\n- b",
      "- a\n\n- b\n- c",
      "- [ ] a\n\n- [x] b",
      "- a\n\n  ```\n  code\n  ```\n\n- b",
      "# H\n\n- a\n\n- b\n\n```elixir\nx\n```\n\n> q\n\n> q2",
      "<div>\n\n<p>x</p>\n\n</div>"
    ]

    test "rendering each block in isolation produces the same HTML as the whole document" do
      for markdown <- @cases do
        together = render(markdown)
        separately = markdown |> Blocks.parse() |> Enum.map_join(&render/1)

        assert separately == together,
               "block splitting changed the output for #{inspect(markdown)}\n" <>
                 "  blocks: #{inspect(Blocks.parse(markdown))}\n" <>
                 "  whole: #{together}\n" <>
                 "  split: #{separately}"
      end
    end

    defp render(markdown) do
      markdown
      |> MDEx.to_html!(syntax_highlight: nil)
      |> String.replace(~r/>\s*</, "><")
      |> String.trim()
    end
  end

  describe "html block merging" do
    test "keeps multi-line HTML block intact" do
      input = "<div>\n\n<p>content</p>\n\n</div>"
      assert Blocks.parse(input) == [input]
    end
  end
end
