defmodule BootPreload do
  @moduledoc """
  Experiment: load the modules that are known to be needed during boot up
  front with `:code.ensure_modules_loaded/1`, which reads and prepares them in
  parallel across all schedulers. The module list is captured from a previous
  boot (`:code.all_loaded/0` at the IEx prompt).

  Configuration:

    config :boot_preload, modules_file: "/path/to/list", mode: :sync | :async | :off
  """
  use Application
  require Logger

  @impl Application
  def start(_type, _args) do
    mode = Application.get_env(:boot_preload, :mode, :off)
    file = Application.get_env(:boot_preload, :modules_file)

    case mode do
      :off -> :ok
      :sync -> preload(file)
      :async -> _ = spawn(fn -> preload(file) end)
    end

    Supervisor.start_link([], strategy: :one_for_one, name: BootPreload.Supervisor)
  end

  defp preload(file) do
    {time, result} =
      :timer.tc(fn ->
        file
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.to_atom/1)
        |> :code.ensure_modules_loaded()
      end)

    Logger.warning("boot_preload: #{inspect(result)} in #{div(time, 1000)} ms")
    :ok
  end
end
