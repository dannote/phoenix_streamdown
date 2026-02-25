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
    <div class="flex flex-col h-dvh max-w-3xl mx-auto">
      <header class="shrink-0 flex items-center gap-3 px-6 py-4 border-b border-base-200">
        <div class="size-8 rounded-lg bg-primary flex items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-5 text-primary-content">
            <path d="M3.505 2.365A41.369 41.369 0 0 1 9 2c1.863 0 3.697.124 5.495.365 1.247.167 2.18 1.108 2.435 2.268a4.45 4.45 0 0 0-.577-.069 43.141 43.141 0 0 0-4.706 0C9.229 4.696 7.5 6.727 7.5 8.998v2.24c0 1.413.67 2.735 1.76 3.562l-2.98 2.98A.75.75 0 0 1 5 17.25v-3.443c-.501-.07-.987-.174-1.453-.31-1.326-.392-2.234-1.544-2.234-2.953V6.133c0-1.716 1.211-3.206 2.874-3.542.21-.043.422-.08.634-.114l-.316-.045ZM14.5 7.5c.689 0 1.375.013 2.058.038A1.513 1.513 0 0 1 18 9.038v2.006c0 .818-.393 1.544-1 2.005v2.201a.75.75 0 0 1-1.28.53l-1.923-1.923A27.11 27.11 0 0 1 12.5 14c-1.675 0-3.289-.12-4.834-.338L14.5 7.5Z" />
          </svg>
        </div>
        <h1 class="text-lg font-semibold">PhoenixStreamdown Demo</h1>
      </header>

      <div id="messages" class="flex-1 overflow-y-auto px-6 py-6 space-y-5" phx-hook="ScrollBottom">
        <div :if={@messages == [] and not @streaming?} class="flex flex-col items-center justify-center h-full text-center">
          <div class="size-16 rounded-2xl bg-base-200 flex items-center justify-center mb-5">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-8 text-base-content/30">
              <path d="M4.913 2.658c2.075-.27 4.19-.408 6.337-.408 2.147 0 4.262.139 6.337.408 1.922.25 3.291 1.861 3.405 3.727a4.403 4.403 0 0 0-1.032-.211 50.89 50.89 0 0 0-8.42 0c-2.358.196-4.04 2.19-4.04 4.434v4.286a4.47 4.47 0 0 0 2.433 3.984L7.28 21.53A.75.75 0 0 1 6 20.97v-3.845a4.607 4.607 0 0 1-.452-.082C3.896 16.681 2.5 15.158 2.5 13.26V6.385c0-1.789 1.389-3.383 3.163-3.65l-.75-.077Zm6.337 1.592a47.78 47.78 0 0 0-3.903.205c-1.01.131-1.787 1.03-1.846 2.124v4.681c0 1.124.675 2.11 1.696 2.394.434.12.893.208 1.372.263L10.5 14v2.97l1.82-1.82a49.023 49.023 0 0 0 5.18-.28c1.012-.132 1.786-1.03 1.845-2.124V8.064c0-1.124-.674-2.11-1.695-2.394a47.628 47.628 0 0 0-6.4-.42Z" />
            </svg>
          </div>
          <p class="text-base-content/50 text-sm max-w-xs">
            Ask anything — the response streams in real-time with rendered Markdown, code highlighting, and more.
          </p>
        </div>

        <div
          :for={{msg, idx} <- Enum.with_index(@messages)}
          class={["rounded-xl px-5 py-4", message_bg(msg.role)]}
        >
          <div class="flex items-center gap-2 mb-2">
            <div class={["size-5 rounded-full flex items-center justify-center text-[10px] font-bold", avatar_class(msg.role)]}>
              {if msg.role == :user, do: "Y", else: "A"}
            </div>
            <span class="text-xs font-medium text-base-content/50">
              {if msg.role == :user, do: "You", else: "Assistant"}
            </span>
          </div>
          <div class="psd-prose pl-7">
            <PhoenixStreamdown.markdown content={msg.content} id={"msg-#{idx}"} />
          </div>
        </div>

        <div :if={@streaming?} class="rounded-xl px-5 py-4 bg-base-200/50">
          <div class="flex items-center gap-2 mb-2">
            <div class="size-5 rounded-full bg-success/20 text-success flex items-center justify-center text-[10px] font-bold">
              A
            </div>
            <span class="text-xs font-medium text-base-content/50">Assistant</span>
            <span class="flex gap-0.5 ml-1">
              <span class="size-1 rounded-full bg-base-content/30 animate-bounce [animation-delay:0ms]" />
              <span class="size-1 rounded-full bg-base-content/30 animate-bounce [animation-delay:150ms]" />
              <span class="size-1 rounded-full bg-base-content/30 animate-bounce [animation-delay:300ms]" />
            </span>
          </div>
          <div class="psd-prose pl-7">
            <PhoenixStreamdown.markdown content={@current_response} streaming id="streaming" />
          </div>
        </div>
      </div>

      <div class="shrink-0 px-6 py-4 border-t border-base-200 bg-base-100">
        <.form for={@form} phx-submit="submit" class="flex gap-3 items-center">
          <input
            type="text"
            name="prompt"
            value={@form[:prompt].value}
            placeholder="Ask something..."
            class="flex-1 input input-bordered"
            autocomplete="off"
            autofocus
            disabled={@streaming?}
          />
          <button
            type="submit"
            disabled={@streaming?}
            class="btn btn-primary"
          >
            <svg :if={not @streaming?} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-5">
              <path d="M3.105 2.288a.75.75 0 0 0-.826.95l1.414 4.926A1.5 1.5 0 0 0 5.135 9.25h6.115a.75.75 0 0 1 0 1.5H5.135a1.5 1.5 0 0 0-1.442 1.086l-1.414 4.926a.75.75 0 0 0 .826.95 28.897 28.897 0 0 0 15.293-7.154.75.75 0 0 0 0-1.115A28.897 28.897 0 0 0 3.105 2.288Z" />
            </svg>
            <span class="loading loading-spinner loading-sm" :if={@streaming?} />
            {if @streaming?, do: "Streaming...", else: "Send"}
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp message_bg(:user), do: "bg-primary/5"
  defp message_bg(_), do: "bg-base-200/50"

  defp avatar_class(:user), do: "bg-primary/20 text-primary"
  defp avatar_class(_), do: "bg-success/20 text-success"
end
