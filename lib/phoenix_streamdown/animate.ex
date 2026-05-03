defmodule PhoenixStreamdown.Animate do
  @moduledoc false

  @skip_tags ~w(code pre svg math annotation)
  @whitespace_re ~r/\s/

  @doc """
  Wraps words in HTML text nodes with `<span data-psd-animate>` for streaming animation.

  Words up to `prev_char_count` get `--psd-dur:0ms` (already visible, no re-animation).
  New words get the configured duration.

  Returns `{animated_html, total_char_count}`.
  """
  @spec animate_words(String.t(), non_neg_integer(), keyword()) :: {String.t(), non_neg_integer()}
  def animate_words(html, prev_char_count, opts \\ []) do
    animation = Keyword.get(opts, :animation, "fadeIn")
    duration = Keyword.get(opts, :duration, 150)
    easing = Keyword.get(opts, :easing, "ease")

    state = %{
      char_count: 0,
      prev_count: prev_char_count,
      animation: animation,
      duration: duration,
      easing: easing,
      skip_depth: 0
    }

    {result, state} = process_tokens(html, state, [])
    {IO.iodata_to_binary(result), state.char_count}
  end

  defp process_tokens("", state, acc), do: {Enum.reverse(acc), state}

  defp process_tokens(<<"<!--", _::binary>> = html, state, acc) do
    case :binary.split(html, "-->") do
      [comment_start, rest] ->
        process_tokens(rest, state, [comment_start <> "-->" | acc])

      [_no_end] ->
        {Enum.reverse([html | acc]), state}
    end
  end

  defp process_tokens(<<"</", _::binary>> = html, state, acc) do
    {tag, rest} = binary_split_inclusive(html, ">")
    tag_name = extract_tag_name(tag)

    state =
      if tag_name in @skip_tags and state.skip_depth > 0 do
        %{state | skip_depth: state.skip_depth - 1}
      else
        state
      end

    process_tokens(rest, state, [tag | acc])
  end

  defp process_tokens(<<"<", _::binary>> = html, state, acc) do
    {tag, rest} = binary_split_inclusive(html, ">")
    tag_name = extract_tag_name(tag)

    state =
      if tag_name in @skip_tags do
        %{state | skip_depth: state.skip_depth + 1}
      else
        state
      end

    process_tokens(rest, state, [tag | acc])
  end

  defp process_tokens(html, state, acc) do
    {text, rest} = binary_split_exclusive(html, "<")

    if state.skip_depth > 0 do
      state = %{state | char_count: state.char_count + String.length(text)}
      process_tokens(rest, state, [text | acc])
    else
      {spans, state} = wrap_words(text, state)
      process_tokens(rest, state, [spans | acc])
    end
  end

  defp binary_split_inclusive(bin, delimiter) do
    case :binary.split(bin, delimiter) do
      [before, after_] -> {before <> delimiter, after_}
      [whole] -> {whole, ""}
    end
  end

  defp binary_split_exclusive(bin, delimiter) do
    case :binary.split(bin, delimiter) do
      [before, after_] -> {before, delimiter <> after_}
      [whole] -> {whole, ""}
    end
  end

  defp extract_tag_name(tag) do
    tag
    |> String.replace_leading("</", "")
    |> String.replace_leading("<", "")
    |> String.split(~r/[\s\/>]/, parts: 2)
    |> List.first("")
    |> String.downcase()
  end

  defp wrap_words(text, state) do
    words = Regex.split(~r/(\s+)/, text, include_captures: true, trim: true)
    {spans, state} = Enum.map_reduce(words, state, &wrap_word/2)
    {IO.iodata_to_binary(spans), state}
  end

  defp wrap_word(word, state) do
    word_len = String.length(word)

    if whitespace_only?(word) do
      {word, %{state | char_count: state.char_count + word_len}}
    else
      dur =
        if state.prev_count > 0 and state.char_count < state.prev_count,
          do: 0,
          else: state.duration

      span =
        "<span data-psd-animate style='--psd-animation:psd-#{state.animation};--psd-dur:#{dur}ms;--psd-easing:#{state.easing}'>#{word}</span>"

      {span, %{state | char_count: state.char_count + word_len}}
    end
  end

  defp whitespace_only?(""), do: true

  defp whitespace_only?(s),
    do: Regex.match?(@whitespace_re, String.first(s)) and String.trim(s) == ""
end
