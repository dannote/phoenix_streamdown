defmodule Example.LLM.OpenRouter do
  @model "openrouter:anthropic/claude-3.5-sonnet"

  def stream(prompt, pid) do
    model = Application.get_env(:example, :llm_model, @model)

    context = [
      ReqLLM.Context.system("""
      You are a helpful assistant. Respond in markdown.
      Use headings, lists, code blocks, and emphasis where appropriate.
      Keep responses concise but well-formatted.
      """),
      ReqLLM.Context.user(prompt)
    ]

    Task.start(fn ->
      case ReqLLM.stream_text(model, context) do
        {:ok, response} ->
          response
          |> ReqLLM.StreamResponse.tokens()
          |> Enum.each(&send(pid, {:token, &1}))

          send(pid, :stream_done)

        {:error, reason} ->
          send(pid, {:stream_error, reason})
      end
    end)
  end
end
