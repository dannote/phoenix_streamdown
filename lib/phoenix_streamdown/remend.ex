defmodule PhoenixStreamdown.Remend do
  @moduledoc """
  Completes incomplete markdown syntax during streaming.

  When LLMs stream markdown token-by-token, you get partial formatting:
  unclosed `**bold`, half-open code fences, partial `[links](`. This module
  auto-closes those constructs so the markdown parser produces valid output.

  Operates on raw strings before they reach the parser — no AST, no dependencies.
  """

  @doc """
  Completes incomplete markdown syntax in the given text.

      iex> PhoenixStreamdown.Remend.complete("**bold text")
      "**bold text**"

      iex> PhoenixStreamdown.Remend.complete("```elixir\\nIO.puts")
      "```elixir\\nIO.puts\\n```"
  """
  @spec complete(String.t()) :: String.t()
  def complete(text) when is_binary(text) and byte_size(text) > 0 do
    text
    |> strip_trailing_single_space()
    |> complete_code_fences()
    |> complete_inline_code()
    |> complete_math_blocks()
    |> complete_links_and_images()
    |> complete_bold_italic()
    |> complete_strikethrough()
  end

  def complete(_), do: ""

  # Don't strip double spaces (markdown line breaks)
  defp strip_trailing_single_space(text) do
    if String.ends_with?(text, " ") and not String.ends_with?(text, "  ") do
      String.trim_trailing(text, " ")
    else
      text
    end
  end

  defp complete_code_fences(text) do
    fence_count =
      text
      |> String.split("\n")
      |> Enum.count(fn line ->
        trimmed = String.trim_leading(line)
        String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
      end)

    if rem(fence_count, 2) == 1 do
      fence_char = if String.contains?(text, "~~~"), do: "~~~", else: "```"
      text <> "\n" <> fence_char
    else
      text
    end
  end

  defp complete_inline_code(text) do
    if within_code_block?(text), do: text, else: do_complete_inline_code(text)
  end

  defp do_complete_inline_code(text) do
    count =
      text
      |> strip_fenced_blocks()
      |> String.graphemes()
      |> count_unescaped_backticks(0, false)

    if rem(count, 2) == 1, do: text <> "`", else: text
  end

  defp count_unescaped_backticks([], count, _escaped), do: count

  defp count_unescaped_backticks(["\\", _ | rest], count, _escaped) do
    count_unescaped_backticks(rest, count, false)
  end

  defp count_unescaped_backticks(["`" | rest], count, _escaped) do
    count_unescaped_backticks(rest, count + 1, false)
  end

  defp count_unescaped_backticks([_ | rest], count, _escaped) do
    count_unescaped_backticks(rest, count, false)
  end

  defp complete_math_blocks(text) do
    if within_code_block?(text), do: text, else: do_complete_math_blocks(text)
  end

  defp do_complete_math_blocks(text) do
    count = count_double_dollars(text, 0, 0)
    if rem(count, 2) == 1, do: text <> "$$", else: text
  end

  defp count_double_dollars(text, pos, count) when pos >= byte_size(text) - 1, do: count

  defp count_double_dollars(text, pos, count) do
    case binary_part(text, pos, 2) do
      "$$" -> count_double_dollars(text, pos + 2, count + 1)
      _ -> count_double_dollars(text, pos + 1, count)
    end
  end

  defp complete_links_and_images(text) do
    if within_code_block?(text), do: text, else: do_complete_links_and_images(text)
  end

  defp do_complete_links_and_images(text) do
    cond do
      # Incomplete image: ![alt](url  or  ![alt]( or ![alt or ![
      Regex.match?(~r/!\[[^\]]*\]\([^\)]*$/, text) ->
        # Strip the entire incomplete image — can't render partial images
        Regex.replace(~r/!\[[^\]]*\]\([^\)]*$/, text, "")

      Regex.match?(~r/!\[[^\]]*$/, text) ->
        Regex.replace(~r/!\[[^\]]*$/, text, "")

      # Incomplete link: [text](url  — show just the text
      Regex.match?(~r/\[[^\]]*\]\([^\)]*$/, text) ->
        Regex.replace(~r/\[([^\]]*)\]\([^\)]*$/, text, "\\1")

      # Incomplete link text: [text
      Regex.match?(~r/\[[^\]\[]*$/, text) ->
        Regex.replace(~r/\[([^\]\[]*$)/, text, "\\1")

      true ->
        text
    end
  end

  defp complete_bold_italic(text) do
    if within_code_block?(text), do: text, else: do_complete_bold_italic(text)
  end

  defp do_complete_bold_italic(text) do
    text
    |> close_marker("***")
    |> close_marker("**")
    |> close_marker("*")
    |> close_marker("___")
    |> close_marker("__")
    |> close_marker("_")
  end

  defp close_marker(text, marker) do
    count = count_outside_code(text, marker)

    if rem(count, 2) == 1 do
      text <> marker
    else
      text
    end
  end

  defp count_outside_code(text, marker) do
    # Split by inline code spans, only count markers in non-code parts
    parts = Regex.split(~r/`[^`]*`/, text)

    parts
    |> Enum.map(fn part -> count_marker_occurrences(part, marker) end)
    |> Enum.sum()
  end

  defp count_marker_occurrences(text, marker) do
    # For emphasis markers, only count those at word boundaries
    # Skip escaped markers
    marker_len = String.length(marker)

    text
    |> String.split(marker)
    |> length()
    |> Kernel.-(1)
    |> max(0)
    |> then(fn count ->
      # Subtract escaped occurrences
      escaped = count_escaped(text, marker, marker_len)
      max(count - escaped, 0)
    end)
  end

  defp count_escaped(text, marker, _marker_len) do
    ("x" <> text)
    |> String.split("\\" <> marker)
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp complete_strikethrough(text) do
    if within_code_block?(text), do: text, else: do_complete_strikethrough(text)
  end

  defp do_complete_strikethrough(text) do
    close_marker(text, "~~")
  end

  # Removes content inside complete fenced code blocks so inline
  # analysis (backtick counting, marker counting) ignores them.
  defp strip_fenced_blocks(text) do
    Regex.replace(~r/(```|~~~).*?\1/s, text, "")
  end

  defp within_code_block?(text) do
    text
    |> String.split("\n")
    |> Enum.reduce(false, fn line, in_block ->
      trimmed = String.trim_leading(line)

      if String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~") do
        not in_block
      else
        in_block
      end
    end)
  end
end
