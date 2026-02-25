defmodule PhoenixStreamdown.Blocks do
  @moduledoc """
  Splits markdown into independent blocks for incremental rendering.

  Earlier blocks are stable — they won't change as new tokens arrive.
  Only the last block needs re-rendering on each update.
  """

  @doc """
  Splits markdown into a list of block strings.

      iex> PhoenixStreamdown.Blocks.parse("# Title\\n\\nParagraph one\\n\\nParagraph two")
      ["# Title", "Paragraph one", "Paragraph two"]
  """
  @spec parse(String.t()) :: [String.t()]
  def parse(markdown) when is_binary(markdown) do
    markdown
    |> split_on_blank_lines()
    |> merge_code_fences()
    |> merge_math()
    |> merge_html()
    |> Enum.reject(&empty?/1)
  end

  def parse(_), do: []

  defp split_on_blank_lines(text) do
    Regex.split(~r/\n{2,}/, text)
  end

  # --- Code fences ---

  defp merge_code_fences(blocks) do
    {merged, acc, _inside} =
      Enum.reduce(blocks, {[], [], false}, fn block, {merged, acc, inside} ->
        if inside do
          new_acc = [block | acc]

          has_closing =
            block
            |> String.split("\n")
            |> Enum.any?(fn l ->
              t = String.trim(l)
              t == "```" or t == "~~~"
            end)

          if has_closing do
            {merged ++ [join_acc(new_acc)], [], false}
          else
            {merged, new_acc, true}
          end
        else
          if rem(fence_line_count(block), 2) == 1 do
            {merged, [block], true}
          else
            {merged ++ [block], [], false}
          end
        end
      end)

    flush_acc(merged, acc)
  end

  defp fence_line_count(block) do
    block
    |> String.split("\n")
    |> Enum.count(fn line ->
      trimmed = String.trim_leading(line)
      String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
    end)
  end

  # --- Math blocks ---

  defp merge_math(blocks) do
    {merged, acc, _inside} =
      Enum.reduce(blocks, {[], [], false}, fn block, {merged, acc, inside} ->
        dd_count = dollar_pair_count(block)

        if inside do
          new_acc = [block | acc]

          if dd_count > 0 do
            {merged ++ [join_acc(new_acc)], [], false}
          else
            {merged, new_acc, true}
          end
        else
          if dd_count > 0 and rem(dd_count, 2) == 1 do
            {merged, [block], true}
          else
            {merged ++ [block], [], false}
          end
        end
      end)

    flush_acc(merged, acc)
  end

  defp dollar_pair_count(text) do
    Regex.scan(~r/\$\$/, text) |> length()
  end

  # --- HTML blocks (tag-aware) ---

  defp merge_html(blocks) do
    {merged, acc, _tag} =
      Enum.reduce(blocks, {[], [], nil}, fn block, {merged, acc, tracked_tag} ->
        if tracked_tag do
          new_acc = [block | acc]

          if closes_tag?(block, tracked_tag) do
            {merged ++ [join_acc(new_acc)], [], nil}
          else
            {merged, new_acc, tracked_tag}
          end
        else
          case unclosed_html_tag(block) do
            nil -> {merged ++ [block], [], nil}
            tag -> {merged, [block], tag}
          end
        end
      end)

    flush_acc(merged, acc)
  end

  defp unclosed_html_tag(block) do
    opens =
      Regex.scan(~r/<(\w+)[\s>]/, block)
      |> Enum.map(fn [_, tag] -> String.downcase(tag) end)

    closes =
      Regex.scan(~r/<\/(\w+)\s*>/, block)
      |> Enum.map(fn [_, tag] -> String.downcase(tag) end)

    unclosed = opens -- closes

    case unclosed do
      [tag | _] -> tag
      [] -> nil
    end
  end

  defp closes_tag?(block, tag) do
    Regex.match?(~r/<\/#{Regex.escape(tag)}\s*>/i, block)
  end

  # --- Helpers ---

  defp join_acc(acc), do: acc |> Enum.reverse() |> Enum.join("\n\n")

  defp flush_acc(merged, []), do: merged
  defp flush_acc(merged, acc), do: merged ++ [join_acc(acc)]

  defp empty?(block), do: String.trim(block) == ""
end
