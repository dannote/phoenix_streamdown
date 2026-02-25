defmodule Example.LLM do
  @moduledoc """
  LLM backend abstraction. Dispatches to real (ReqLLM) or fake backend.
  """

  def stream(prompt, pid) do
    backend = Application.get_env(:example, :llm_backend, Example.LLM.OpenRouter)
    backend.stream(prompt, pid)
  end
end
