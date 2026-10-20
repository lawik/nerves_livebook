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
      # handled from the boot script, see `early/1`
      :early -> :ok
      :sync -> preload(file)
      :async -> _ = spawn(fn -> preload(file) end)
    end

    Supervisor.start_link([], strategy: :one_for_one, name: BootPreload.Supervisor)
  end

  @doc """
  Preload from the boot script, before `Config.Provider` runs and before any
  application is started. Only kernel/stdlib code may be relied on here, so
  this avoids Elixir's standard library on purpose.

  The boot script instruction is injected by the release step in mix.exs:

      {apply, {'Elixir.BootPreload', early, ["/etc/boot_modules.txt"]}}
  """
  def early(file) do
    case :file.read_file(file) do
      {:ok, bin} ->
        mods =
          :lists.map(
            &:erlang.binary_to_atom(&1, :utf8),
            :binary.split(bin, "\n", [:global, :trim_all])
          )

        _ = :code.ensure_modules_loaded(mods)
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Start the remaining applications from a background process so that the boot
  script finishes (and the IEx shell starts) before they are up. Injected into
  the boot script by the release step in mix.exs (NERVES_EARLY_IEX=1).
  """
  def start_rest(apps) do
    _ =
      spawn(fn ->
        # Record which modules were needed up to this point (tier 1) so the
        # preload list can be split; the rest can load behind the prompt.
        _ = :file.write_file("/data/boot_modules_tier1.txt", tier1_list())

        # For capturing the prompt working set: hold the deferred apps back so
        # `:code.all_loaded/0` at the first prompt is exactly what the prompt needed.
        case :application.get_env(:boot_preload, :rest_delay_ms) do
          {:ok, ms} when is_integer(ms) and ms > 0 -> :timer.sleep(ms)
          _ -> :ok
        end

        case :file.read_file("/etc/boot_modules_tier2.txt") do
          {:ok, bin} ->
            mods =
              :lists.map(
                &:erlang.binary_to_atom(&1, :utf8),
                :binary.split(bin, "\n", [:global, :trim_all])
              )

            _ = :code.ensure_modules_loaded(mods)

          _ ->
            :ok
        end

        start = :erlang.monotonic_time(:millisecond)

        :lists.foreach(
          fn {app, type} ->
            case :application.start_boot(app, type) do
              :ok -> :ok
              {:error, {:already_started, _}} -> :ok
              {:error, reason} -> :erlang.display({:boot_preload, :start_failed, app, reason})
            end
          end,
          apps
        )

        ms = :erlang.monotonic_time(:millisecond) - start
        :io.format(:user, "boot_preload: rest started (~p apps) in ~p ms~n", [length(apps), ms])
      end)

    :ok
  end

  defp tier1_list() do
    :lists.map(fn {m, _} -> [:erlang.atom_to_binary(m, :utf8), "\n"] end, :code.all_loaded())
  end

  @doc """
  Preload before the kernel application starts, using only erl_prim_loader
  and the load BIFs (no code server yet). `file` holds a term
  `[{Module, "lib/app-vsn/ebin/Module.beam"}]` generated at build time.
  Modules with on_load functions (NIFs) are skipped; they need the code
  server and load on demand later.
  """
  def prim(file) do
    {:ok, [[root]]} = :init.get_argument(:root)
    # file_server is not running yet, so go through the prim loader. read_file/1
    # runs in the caller for the efile loader; get_file/1 would serialize every
    # read through the erl_prim_loader process.
    {:ok, bin} = :erl_prim_loader.read_file(file)

    entries =
      :lists.filter(fn {m, _} -> not :erlang.module_loaded(m) end, :erlang.binary_to_term(bin))

    n = :erlang.system_info(:schedulers_online)
    parent = self()
    t0 = :erlang.monotonic_time(:millisecond)

    workers =
      for i <- 0..(n - 1) do
        slice = every_nth(entries, i, n)

        # Not spawn_link: this runs in the `init` process, which traps exits, and a
        # stray {'EXIT', _, normal} in its mailbox makes the following
        # application_controller start step fail with "normal".
        spawn(fn ->
          prepared =
            :lists.filtermap(
              fn {m, rel} ->
                case :erl_prim_loader.read_file(root ++ ~c"/" ++ rel) do
                  {:ok, beam} ->
                    case :erlang.prepare_loading(m, beam) do
                      {:error, _} ->
                        false

                      prep ->
                        if :erlang.has_prepared_code_on_load(prep),
                          do: false,
                          else: {true, {m, prep}}
                    end

                  _ ->
                    false
                end
              end,
              slice
            )

          send(parent, {self(), prepared})
        end)
      end

    prepared =
      :lists.append(
        for w <- workers do
          receive do
            {^w, p} -> p
          end
        end
      )

    result = :erlang.finish_loading(:lists.map(fn {_, p} -> p end, prepared))
    ms = :erlang.monotonic_time(:millisecond) - t0
    :erlang.display({:boot_preload_prim, length(prepared), result, ms})
    :ok
  end

  defp every_nth(list, i, n) do
    {_, acc} =
      :lists.foldl(
        fn e, {k, acc} -> {k + 1, if(rem(k, n) == i, do: [e | acc], else: acc)} end,
        {0, []},
        list
      )

    :lists.reverse(acc)
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
