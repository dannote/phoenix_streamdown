defmodule Mix.Tasks.PhoenixStreamdown.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixStreamdown.Install

  @mix_exs """
  defmodule Demo.MixProject do
    use Mix.Project

    def project do
      [app: :demo, version: "0.1.0", deps: deps()]
    end

    defp deps do
      [
        {:phoenix, "~> 1.8"},
        {:phoenix_streamdown, "~> 1.0"}
      ]
    end
  end
  """

  describe "patch_deps/1" do
    test "adds the Lumis parser to the deps list" do
      assert {:changed, patched} = Install.patch_deps(@mix_exs)
      assert patched =~ ~s({:lumis_wasm_elixir, "~> 0.26"})
      assert patched =~ ~s({:phoenix, "~> 1.8"})
      assert patched =~ "defp deps do"
    end

    test "keeps a deps list that already has the parser" do
      source =
        String.replace(
          @mix_exs,
          ~s({:phoenix, "~> 1.8"},),
          ~s({:phoenix, "~> 1.8"},\n      {:lumis_wasm_elixir, "~> 0.26"},\n)
        )

      assert {:unchanged, ^source} = Install.patch_deps(source)
    end

    test "reports a mix.exs it cannot patch" do
      assert :error = Install.patch_deps("defmodule Demo.MixProject do\nend\n")
    end
  end

  describe "patch_config/1" do
    test "creates a config file when there is none" do
      assert {:changed, config} = Install.patch_config(nil)
      assert config =~ "import Config"
      assert config =~ "config :mdex_native, syntax_highlighter: :lumis"
    end

    test "appends the highlighter to an existing config" do
      assert {:changed, config} = Install.patch_config("import Config\n")
      assert config =~ "import Config"
      assert config =~ "config :mdex_native, syntax_highlighter: :lumis"
    end

    test "keeps a config that already sets a highlighter" do
      source = "import Config\n\nconfig :mdex_native, syntax_highlighter: :syntect\n"
      assert {:unchanged, ^source} = Install.patch_config(source)
    end
  end
end
