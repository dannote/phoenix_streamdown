defmodule ExampleWeb.ChatLive do
  use ExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Chat",
       messages: [],
       current_response: "",
       streaming?: false,
       form: to_form(%{"prompt" => ""})
     )}
  end

  @impl true
  def handle_event("submit", %{"prompt" => prompt}, socket) when prompt != "" do
    messages = socket.assigns.messages ++ [%{role: :user, content: prompt}]

    Example.LLM.stream(prompt, self())

    {:noreply,
     assign(socket,
       messages: messages,
       current_response: "",
       streaming?: true,
       form: to_form(%{"prompt" => ""})
     )}
  end

  def handle_event("submit", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:token, token}, socket) do
    {:noreply, assign(socket, :current_response, socket.assigns.current_response <> token)}
  end

  def handle_info(:stream_done, socket) do
    messages =
      socket.assigns.messages ++
        [%{role: :assistant, content: socket.assigns.current_response}]

    {:noreply,
     assign(socket,
       messages: messages,
       current_response: "",
       streaming?: false
     )}
  end

  def handle_info({:stream_error, reason}, socket) do
    {:noreply,
     socket
     |> assign(:streaming?, false)
     |> put_flash(:error, "LLM error: #{inspect(reason)}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-8">
      <h1 class="text-2xl font-bold mb-8">PhoenixStreamdown Demo</h1>

      <div id="messages" class="space-y-6 mb-8">
        <div
          :for={{msg, idx} <- Enum.with_index(@messages)}
          class={[
            "rounded-lg px-4 py-3",
            if(msg.role == :user, do: "bg-blue-50 dark:bg-blue-950", else: "bg-gray-50 dark:bg-gray-900")
          ]}
        >
          <div class="text-xs font-medium text-gray-500 mb-2">
            {if msg.role == :user, do: "You", else: "Assistant"}
          </div>
          <div class="prose dark:prose-invert max-w-none">
            <PhoenixStreamdown.markdown content={msg.content} id={"msg-#{idx}"} />
          </div>
        </div>

        <div
          :if={@streaming?}
          class="rounded-lg px-4 py-3 bg-gray-50 dark:bg-gray-900"
        >
          <div class="text-xs font-medium text-gray-500 mb-2">Assistant</div>
          <div class="prose dark:prose-invert max-w-none">
            <PhoenixStreamdown.markdown content={@current_response} streaming id="streaming" />
          </div>
        </div>
      </div>

      <.form for={@form} phx-submit="submit" class="flex gap-3">
        <input
          type="text"
          name="prompt"
          value={@form[:prompt].value}
          placeholder="Ask something..."
          class="flex-1 rounded-lg border border-gray-300 dark:border-gray-700 px-4 py-2 dark:bg-gray-800"
          autofocus
          disabled={@streaming?}
        />
        <button
          type="submit"
          disabled={@streaming?}
          class="rounded-lg bg-blue-600 px-6 py-2 text-white font-medium hover:bg-blue-700 disabled:opacity-50"
        >
          {if @streaming?, do: "Streaming...", else: "Send"}
        </button>
      </.form>
    </div>
    """
  end
end
