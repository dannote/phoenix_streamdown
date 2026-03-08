defmodule PhoenixStreamdown.AnimateTest do
  use ExUnit.Case, async: true

  alias PhoenixStreamdown.Animate

  describe "animate_words/3" do
    test "wraps words in spans with animation" do
      {result, count} = Animate.animate_words("<p>Hello world</p>", 0)
      assert result =~ "<span data-psd-animate"
      assert result =~ ">Hello</span>"
      assert result =~ ">world</span>"
      assert result =~ "--psd-dur:150ms"
      assert count == 11
    end

    test "skips animation for already-seen characters" do
      {result, _} = Animate.animate_words("<p>Hello world</p>", 5)
      assert result =~ "Hello</span>"
      # "Hello" (5 chars) should be skipped
      [hello_span] = Regex.run(~r/<span[^>]*>Hello<\/span>/, result)
      assert hello_span =~ "dur:0ms"
      # "world" should animate
      [world_span] = Regex.run(~r/<span[^>]*>world<\/span>/, result)
      assert world_span =~ "dur:150ms"
    end

    test "handles multi-byte characters (°F)" do
      html = "<p>Temperature 55°F (feels like 53°F).</p>"
      {result, _count} = Animate.animate_words(html, 0)
      # The closing </p> must not leak as visible text
      assert result =~ ">53°F).</span></p>"
      refute result =~ "'>p>"
    end

    test "preserves tags without wrapping" do
      html = "<p>Hello <strong>bold</strong> world</p>"
      {result, _} = Animate.animate_words(html, 0)
      assert result =~ "<strong>"
      assert result =~ "</strong>"
      assert result =~ ">bold</span>"
    end

    test "skips code/pre content" do
      html = "<p>Text <code>code here</code> more</p>"
      {result, _} = Animate.animate_words(html, 0)
      assert result =~ "<code>code here</code>"
      refute result =~ "<code><span"
    end

    test "preserves whitespace as-is" do
      html = "<p>Hello   world</p>"
      {result, _} = Animate.animate_words(html, 0)
      assert result =~ "   "
    end

    test "handles links with attributes" do
      html = ~s(<p>Click <a href="https://example.com">here</a> now</p>)
      {result, _} = Animate.animate_words(html, 0)
      assert result =~ ~s(<a href="https://example.com">)
      assert result =~ ">here</span></a>"
    end

    test "handles HTML comments" do
      html = "<p>Before <!-- comment --> after</p>"
      {result, _} = Animate.animate_words(html, 0)
      assert result =~ "<!-- comment -->"
      assert result =~ ">Before</span>"
      assert result =~ ">after</span>"
    end

    test "returns correct char count" do
      {_, count} = Animate.animate_words("<p>Hi there</p>", 0)
      assert count == 8
    end

    test "supports custom animation type" do
      {result, _} = Animate.animate_words("<p>Hello</p>", 0, animation: "blurIn")
      assert result =~ "psd-blurIn"
    end

    test "supports custom duration" do
      {result, _} = Animate.animate_words("<p>Hello</p>", 0, duration: 300)
      assert result =~ "dur:300ms"
    end
  end
end
