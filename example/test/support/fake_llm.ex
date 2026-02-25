defmodule Example.LLM.Fake do
  @response """
  # Hello from FakeLLM

  This is a **streaming** response with:

  - Bullet points
  - `inline code`
  - And a code block:

  ```elixir
  IO.puts("Hello, world!")
  ```

  That's all!
  """

  def stream(_prompt, pid) do
    Task.start(fn ->
      @response
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.join/1)
      |> Enum.each(fn chunk ->
        send(pid, {:token, chunk})
        Process.sleep(10)
      end)

      send(pid, :stream_done)
    end)
  end
end
