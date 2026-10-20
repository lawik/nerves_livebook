# This file is compiled in a separate OS process by the :mix_shim compiler in
# mix.exs (see `Mix.Tasks.Compile.MixShim`) because the real Mix is loaded
# while the project compiles. The resulting Elixir.Mix.beam is placed in the
# nerves_livebook ebin so that it's loaded on demand when a notebook calls
# `Mix.install/2`. Compiling it at build time avoids loading the Elixir and
# Erlang compilers (~60 modules) during boot.
defmodule Mix do
  @moduledoc false

  def install(deps, opts \\ []) when is_list(deps) and is_list(opts) do
    NervesLivebook.MixInstall.install(deps, opts)
  end

  def install_project_dir() do
    NervesLivebook.MixInstall.install_project_dir()
  end
end
