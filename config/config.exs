import Config

# The library's own dev/test builds enable the Lumis highlighter so that syntax
# highlighting is covered by the test suite. Dependencies do not evaluate this
# file: consumers opt in with `config :mdex_native, syntax_highlighter: :lumis`
# plus a parser package such as `:lumis_wasm_elixir`.
config :mdex_native, syntax_highlighter: :lumis
