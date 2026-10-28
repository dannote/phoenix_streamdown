defmodule Mix.Tasks.PhoenixStreamdown.Install do
  @shortdoc "Adds what MDEx needs to syntax highlight code blocks"

  @moduledoc """
  Adds the Lumis highlighter that MDEx needs to highlight code blocks.

      mix phoenix_streamdown.install

  It patches two files:

    * `mix.exs` — adds `{:lumis_wasm_elixir, "~> 0.26"}`, a parser for Elixir code
    * `config/config.exs` — adds `config :mdex_native, syntax_highlighter: :lumis`

  `mdex_native` reads that setting when it is compiled, so run `mix deps.get`
  afterwards and restart your server. Run this task inside the app, not at the
  umbrella root.

  Fenced blocks in other languages need their own parser package, for example
  `{:lumis_wasm_bundle_web, "~> 0.1"}` for CSS, HTML and JavaScript. See the
  [language catalog](https://docs.lumis.sh/reference/languages). To move the
  parser compilation off the first request, call
  `Lumis.Languages.async_load(~w(elixir))` from your application's `start/2`.

  ## Options

    * `--dry-run` — report the changes without writing them
  """

  use Mix.Task

  @parser_dep ~s({:lumis_wasm_elixir, "~> 0.26"})
  @highlighter_config "config :mdex_native, syntax_highlighter: :lumis"

  @impl Mix.Task
  def run(args) do
    {opts, _argv} = OptionParser.parse!(args, strict: [dry_run: :boolean])
    root = project_root!()

    patch(Path.join(root, "mix.exs"), :deps, &patch_deps/1, opts)
    patch(Path.join([root, config_path()]), :config, &patch_config/1, opts)

    info("Run `mix deps.get`, then restart your server.")
  end

  @doc false
  def patch_deps(source) do
    if String.contains?(source, "lumis_wasm_elixir") do
      {:unchanged, source}
    else
      insert_dep(source)
    end
  end

  @doc false
  def patch_config(nil) do
    {:changed, "import Config\n\n#{@highlighter_config}\n"}
  end

  def patch_config(source) do
    if String.contains?(source, "syntax_highlighter") do
      {:unchanged, source}
    else
      {:changed, String.trim_trailing(source) <> "\n\n#{@highlighter_config}\n"}
    end
  end

  defp insert_dep(source) do
    case Regex.run(~r/(defp? deps do\s*\n\s*\[)/, source, return: :index) do
      [{start, length} | _] ->
        insert_at = start + length
        dep = "\n      #{@parser_dep},"

        {:changed,
         String.slice(source, 0, insert_at) <> dep <> String.slice(source, insert_at..-1//1)}

      nil ->
        :error
    end
  end

  defp project_root! do
    Mix.Project.get!()

    if Mix.Project.config()[:apps_path] do
      Mix.raise("Run this task inside an app of the umbrella, not at its root.")
    end

    Mix.Project.project_file() |> Path.dirname()
  end

  defp config_path do
    Mix.Project.config()[:config_path] || "config/config.exs"
  end

  defp patch(path, :deps, patcher, opts) do
    source = if File.exists?(path), do: File.read!(path), else: ""
    apply_patch(path, source, patcher.(source), opts)
  end

  defp patch(path, :config, patcher, opts) do
    source = if File.exists?(path), do: File.read!(path), else: nil
    apply_patch(path, source, patcher.(source), opts)
  end

  defp apply_patch(path, source, result, opts) do
    dry_run? = Keyword.get(opts, :dry_run, false)

    case result do
      {:changed, patched} when dry_run? ->
        info("#{path} would be updated:\n\n#{patched}")

      {:changed, patched} ->
        if source == nil, do: File.mkdir_p!(Path.dirname(path))
        File.write!(path, patched)
        info("Updated #{path}")

      {:unchanged, _patched} ->
        info("#{path} is already set up")

      :error ->
        info("""
        Could not find a `deps/0` function in #{path}.
        Add the parser yourself:

            #{@parser_dep}
        """)
    end
  end

  defp info(message), do: Mix.shell().info(message)
end
