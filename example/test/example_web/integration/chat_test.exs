defmodule ExampleWeb.Integration.ChatTest do
  use PhoenixTest.Playwright.Case

  import PhoenixTest
  alias PhoenixTest.Playwright

  test "renders the chat page", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "PhoenixStreamdown Demo")
    |> assert_has("input[name='prompt']")
    |> assert_has("button", text: "Send")
  end

  test "submits a prompt and displays streaming response", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("body .phx-connected")
    |> Playwright.type("input[name='prompt']", "Hello!")
    |> click_button("Send")
    |> assert_has("div", text: "You")
    |> assert_has("div", text: "Hello!")
    |> assert_has("button", text: "Send", timeout: 10_000)
    |> assert_has("strong", text: "streaming")
    |> assert_has("div", text: "That's all!")
  end

  test "button shows 'Streaming...' while response is in progress", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("body .phx-connected")
    |> Playwright.type("input[name='prompt']", "Hi")
    |> click_button("Send")
    |> assert_has("button", text: "Streaming...")
    |> assert_has("button", text: "Send", timeout: 10_000)
  end

  test "renders code blocks with syntax highlighting", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("body .phx-connected")
    |> Playwright.type("input[name='prompt']", "Show me code")
    |> click_button("Send")
    |> assert_has("button", text: "Send", timeout: 10_000)
    |> assert_has("code", text: "IO.puts")
  end
end
