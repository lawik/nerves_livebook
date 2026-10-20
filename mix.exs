# SPDX-FileCopyrightText: None
# SPDX-License-Identifier: CC0-1.0
defmodule NervesLivebook.MixProject do
  use Mix.Project

  @app :nerves_livebook
  @version "0.19.6"
  @source_url "https://github.com/nerves-livebook/nerves_livebook"

  @rpi_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :rpi0_2, :rpi5]
  @all_targets @rpi_targets ++ [:bbb, :trellis, :x86_64, :mangopi_mq_pro, :qemu_aarch64]

  # See the BlueHeron repository for the boards that it supports.
  @ble_targets [:rpi0, :rpi0_2, :rpi3, :rpi3a]

  # Targets where Nx ML deps (NxEigen backend, Axon, Bumblebee) are pulled in.
  # Disable for now due to https://github.com/polvalente/nx_eigen/issues/6
  @ml_targets []

  # Targets with EInk displays that work out-of-the-box. At the moment, this
  # only includes Trellis boards like the Nerves Starter Kit and Goatmire
  # Badge, but there could be Raspberry Pi hats that could work.
  @eink_targets [:trellis]

  # Instruct the compiler to create deterministic builds to minimize
  # differences between firmware versions. This helps delta firmware update
  # compression.
  System.put_env("ERL_COMPILER_OPTIONS", "deterministic")

  def project do
    [
      app: @app,
      compilers:
        Enum.flat_map(Mix.compilers(), fn
          :app -> [:mix_shim, :app]
          c -> [c]
        end),
      description: "Develop on embedded devices with Livebook and Nerves",
      author: "https://github.com/nerves-livebook/nerves_livebook/graphs/contributors",
      version: @version,
      package: package(),
      elixir: "~> 1.18",
      archives: [nerves_bootstrap: "~> 1.10 or ~> 2.0-dev"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs},
      preferred_targets: %{run: :host, test: :host, "phx.server": :host}
    ]
  end

  def application do
    [
      mod: {NervesLivebook.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ex_unit]
    ]
  end

  # The nice part about posting to hex is that documentation links work when you're
  # calling NervesLivebook functions.
  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE",
        "assets",
        "priv"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps do
    [
      # Dependencies for host and target
      {:nerves, "~> 2.0.0-pre.4", runtime: false},
      {:ring_logger, "~> 0.11.7"},
      {:logger_backends, "~> 1.0"},
      {:toolshed, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:nerves_runtime, "~> 0.13.12"},
      {:livebook, "~> 0.19.3"},
      {:plug, "~> 1.12"},
      {:vintage_net, "~> 0.13"},

      # Pull in commonly used libraries as a convenience to users.
      {:blue_heron, "~> 0.5", targets: @ble_targets},
      {:bmp280, "~> 0.2", targets: @all_targets},
      {:circuits_gpio, "~> 2.0 or ~> 1.0"},
      {:circuits_i2c, "~> 2.0 or ~> 1.0"},
      {:circuits_spi, "~> 2.0 or ~> 1.0"},
      {:circuits_uart, "~> 1.3"},
      {:delux, "~> 0.2"},
      {:hts221, "~> 1.1", targets: @all_targets},
      {:egd_text_panel, "~> 0.1.0", targets: @eink_targets},
      {:eink, "~> 0.1.0", targets: @eink_targets},
      {:input_event, "~> 1.0 or ~> 0.4", targets: @all_targets},
      {:kino, "~> 0.14"},
      {:kino_maplibre, "~> 0.1.0"},
      {:kino_vega_lite, "~> 0.1.1"},
      {:maplibre, "~> 0.1.7"},
      {:nerves_hub_link, "~> 2.5"},
      {:nerves_key, "~> 1.0", targets: @all_targets},
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},
      {:nerves_time_zones, "~> 0.3.0", targets: @all_targets},
      {:nx, "~> 0.12.0"},
      {:axon, "~> 0.8", targets: @ml_targets},
      {:bumblebee, "~> 0.7", targets: @ml_targets},
      {:nx_eigen, "~> 0.1", targets: @ml_targets},
      {:nx_signal, "~> 0.2", targets: @ml_targets},
      {:scholar, "~> 0.4", targets: @ml_targets},
      {:phoenix_pubsub, "~> 2.0"},
      {:pinout, "~> 0.1"},
      {:progress_bar, "~> 3.0"},
      {:ramoops_logger, "~> 0.1", targets: @all_targets},
      {:recon, "~> 2.5"},
      {:req, "~> 0.5"},
      {:scroll_hat, "~> 0.1", targets: @rpi_targets},
      {:stb_image, "~> 0.6.0"},
      {:tflite_elixir, "~> 1.0.0", targets: @all_targets},
      {:vega_lite, "~> 0.1"},
      {:vintage_net_wifi, "~> 0.12.5", targets: @all_targets},
      {:vintage_net_qmi, "~> 0.4.1", targets: @all_targets},

      # Pull in libraries that start applications, but don't automatically
      # start the applications. See the release definition below.
      {:mndp, "~> 0.2", runtime: false},

      # Nerves system dependencies
      {:nerves_system_rpi, "~> 2.0", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 2.0", runtime: false, targets: :rpi0},
      {:nerves_system_rpi0_2, "~> 2.0", runtime: false, targets: :rpi0_2},
      {:nerves_system_rpi2, "~> 2.0", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 2.0", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 2.0", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 2.0", runtime: false, targets: :rpi5},
      {:nerves_system_bbb, "~> 2.29", runtime: false, targets: :bbb},
      {:nerves_system_trellis, "~> 0.4", runtime: false, targets: :trellis},
      {:nerves_system_x86_64, "~> 1.33", runtime: false, targets: :x86_64},
      {:nerves_system_mangopi_mq_pro, "~> 0.15", runtime: false, targets: :mangopi_mq_pro},
      {:nerves_system_qemu_aarch64, "~> 0.5", runtime: false, targets: :qemu_aarch64},

      # Boot-time module preloading experiment
      {:boot_preload, path: "boot_preload"},

      # Compile-time only
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp docs do
    [
      assets: %{"assets" => "assets"},
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  def release do
    [
      # In order to get libraries that start code that may not be used, just
      # have the release load them.  These libraries are specified as `runtime:
      # false` above, but the release will contain them since they're marked to
      # be loaded below.
      applications:
        [mndp: :load] ++
          if(System.get_env("NERVES_BOOT_PROFILE"),
            do: [tools: :load],
            else: []
          ),
      overwrite: true,
      include_erts: &Nerves.erts/0,
      steps: [&init_release/1, :assemble],
      strip_beams: if(System.get_env("NERVES_STRIP_DOCS"), do: true, else: [keep: ["Docs"]])
    ]
  end

  # Boot-time module preloading experiment: with NERVES_PRELOAD=early, insert a
  # boot script instruction right before Config.Provider runs so that the
  # modules needed during boot are loaded in parallel before anything needs
  # them. This has to run after :assemble (which generates start.boot) and
  # before Nerves builds the root filesystem.
  defp init_release(release) do
    release = Nerves.init_release(release)

    if System.get_env("NERVES_PRELOAD") in ["early", "prim"] or
         System.get_env("NERVES_EARLY_IEX") != nil or
         System.get_env("NERVES_TRACE_PROCS") != nil do
      steps =
        Enum.flat_map(release.steps, fn
          :assemble -> [:assemble, &inject_boot_tweaks/1]
          step -> [step]
        end)

      %{release | steps: steps}
    else
      release
    end
  end

  defp inject_boot_tweaks(release) do
    boot_path = Path.join(release.version_path, "start.boot")
    {:script, id, instructions} = File.read!(boot_path) |> :erlang.binary_to_term()

    instructions =
      instructions
      |> maybe_inject_early_preload()
      |> maybe_inject_prim_preload(release)
      |> maybe_inject_early_iex()
      |> maybe_inject_proc_trace()

    File.write!(boot_path, :erlang.term_to_binary({:script, id, instructions}))
    release
  end

  # Load the boot module set in parallel before Config.Provider runs.
  defp maybe_inject_early_preload(instructions) do
    if System.get_env("NERVES_PRELOAD") == "early" do
      preload = {:apply, {BootPreload, :early, [~c"/etc/#{module_list_file()}"]}}
      Mix.shell().info("Injecting early module preload into start.boot")

      Enum.flat_map(instructions, fn
        {:apply, {Config.Provider, :boot, []}} = i -> [preload, i]
        i -> [i]
      end)
    else
      instructions
    end
  end

  # Make BootPreload available before the kernel application (and the code
  # server) exist, by primLoading it from the release's ebin like kernel/stdlib.
  defp prim_load_boot_preload(instructions) do
    # Only look before {kernel_load_completed}: every app's modules appear in a
    # later primLoad too, but init skips those in interactive mode.
    pre_kernel = Enum.take_while(instructions, &(&1 != {:kernel_load_completed}))

    if Enum.any?(pre_kernel, &match?({:primLoad, [BootPreload]}, &1)) do
      instructions
    else
      # The release's boot_preload ebin path string, as used in the big {path, ...}
      {:path, all_paths} = Enum.find(instructions, &match?({:path, [_, _, _ | _]}, &1))
      bp_path = Enum.find(all_paths, &(to_string(&1) =~ "boot_preload-"))
      {:path, kernel_paths} = Enum.find(instructions, &match?({:path, [_, _]}, &1))

      Enum.flat_map(instructions, fn
        {:kernel_load_completed} = i ->
          [{:path, kernel_paths ++ [bp_path]}, {:primLoad, [BootPreload]}, i]

        i ->
          [i]
      end)
    end
  end

  # NERVES_TRACE_PROCS=1 (profiling): log process spawns and registrations from
  # the end of kernel code loading until Config.Provider runs.
  defp maybe_inject_proc_trace(instructions) do
    if System.get_env("NERVES_TRACE_PROCS") do
      instructions
      |> prim_load_boot_preload()
      |> Enum.flat_map(fn
        {:kernel_load_completed} = i ->
          [i, {:apply, {BootPreload, :trace_procs, []}}]

        {:apply, {Config.Provider, :boot, []}} = i ->
          [{:apply, {BootPreload, :trace_stop, []}}, i]

        i ->
          [i]
      end)
    else
      instructions
    end
  end

  # NERVES_PRELOAD_TIER1=1 preloads only the modules needed up to the IEx
  # prompt; the rest are loaded by BootPreload.start_rest/1 behind it.
  defp module_list_file() do
    if System.get_env("NERVES_PRELOAD_TIER1"),
      do: "boot_modules_tier1.txt",
      else: "boot_modules.txt"
  end

  # Preload before the kernel application starts. Generates
  # /etc/boot_modules.prim ([{Mod, "lib/app-vsn/ebin/Mod.beam"}]) from the
  # module list, loads BootPreload itself with primLoad while that still
  # works, and applies BootPreload.prim/1 right after the full code path is set.
  defp maybe_inject_prim_preload(instructions, release) do
    if System.get_env("NERVES_PRELOAD") == "prim" do
      mods =
        File.read!("rootfs_overlay/etc/#{module_list_file()}")
        |> String.split("\n", trim: true)
        |> Enum.map(&String.to_atom/1)

      beams =
        Path.wildcard(Path.join(release.path, "lib/*/ebin/*.beam"))
        |> Map.new(fn p ->
          {Path.basename(p, ".beam") |> String.to_atom(), Path.relative_to(p, release.path)}
        end)

      entries = for m <- mods, rel = beams[m], rel != nil, do: {m, String.to_charlist(rel)}
      # generated into the rootfs overlay (gitignored)
      File.write!("rootfs_overlay/etc/boot_modules.prim", :erlang.term_to_binary(entries))
      Mix.shell().info("Prim preload: #{length(entries)} of #{length(mods)} modules resolved")

      instructions
      |> prim_load_boot_preload()
      |> Enum.flat_map(fn
        {:kernelProcess, :heart, _} = i ->
          [{:apply, {BootPreload, :prim, [~c"/etc/boot_modules.prim"]}}, i]

        i ->
          [i]
      end)
    else
      instructions
    end
  end

  # Start everything after the last "essential" application from a background
  # process. The boot script then completes, init reports started, and the
  # IEx shell (which waits for that) comes up while the rest start.
  # NERVES_EARLY_IEX=1 defers everything after :toolshed; NERVES_EARLY_IEX=<app>
  # uses that application as the boundary instead.
  defp early_iex_boundary() do
    case System.get_env("NERVES_EARLY_IEX") do
      "1" -> :toolshed
      app -> String.to_atom(app)
    end
  end

  defp maybe_inject_early_iex(instructions) do
    if System.get_env("NERVES_EARLY_IEX") do
      boundary_app = early_iex_boundary()

      boundary =
        Enum.find_index(
          instructions,
          &match?({:apply, {:application, :start_boot, [^boundary_app, _]}}, &1)
        )

      boundary || Mix.raise("Could not find #{early_iex_boundary()} in start.boot")
      {before, after_boundary} = Enum.split(instructions, boundary + 1)

      {rest_starts, others} =
        Enum.split_with(after_boundary, &match?({:apply, {:application, :start_boot, _}}, &1))

      apps =
        for {:apply, {:application, :start_boot, [app, type]}} <- rest_starts, do: {app, type}

      Mix.shell().info("Deferring #{length(apps)} application starts past the IEx shell")

      # keep {progress, started} last
      {progress, others} = Enum.split_with(others, &match?({:progress, :started}, &1))
      {before, others, extra} = maybe_defer_load(before, others, apps)
      before ++ others ++ [{:apply, {BootPreload, :start_rest, [apps, extra]}}] ++ progress
    else
      instructions
    end
  end

  # NERVES_DEFER_LOAD=1: also move the deferred applications' code path entries
  # and `application:load` of their specs behind the shell. Their config from
  # runtime.exs survives because Config.Provider sets env persistently.
  defp maybe_defer_load(before, others, apps) do
    if System.get_env("NERVES_DEFER_LOAD") do
      deferred = MapSet.new(apps, fn {app, _} -> app end)

      dir_app = fn dir ->
        dir |> to_string() |> Path.dirname() |> Path.basename() |> String.split("-") |> hd()
      end

      deferred_dir? = fn dir ->
        String.contains?(to_string(dir), "/ebin") and
          MapSet.member?(deferred, String.to_atom(dir_app.(dir)))
      end

      {before, dirs} =
        Enum.map_reduce(before, [], fn
          {:path, [_, _, _ | _] = all}, acc ->
            {keep, moved} = Enum.split_with(all, &(not deferred_dir?.(&1)))
            {{:path, keep}, acc ++ moved}

          i, acc ->
            {i, acc}
        end)

      {loads, before} =
        Enum.split_with(before, fn
          {:apply, {:application, :load, [{:application, app, _}]}} ->
            MapSet.member?(deferred, app)

          _ ->
            false
        end)

      specs = for {:apply, {:application, :load, [spec]}} <- loads, do: spec

      Mix.shell().info(
        "Deferring #{length(dirs)} code path entries and #{length(specs)} application loads"
      )

      {before, others, [paths: dirs, specs: specs]}
    else
      {before, others, []}
    end
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end

defmodule Mix.Tasks.Compile.MixShim do
  @moduledoc """
  Compile `lib_shim/mix.ex` into `Elixir.Mix.beam` in the nerves_livebook ebin.

  The shim provides `Mix.install/2` on the device. It has to be compiled in a
  separate OS process since the real Mix is loaded while compiling the
  project. Compiling it ahead of time means that the Elixir and Erlang
  compilers don't need to be loaded at boot just to define this module.
  """
  use Mix.Task.Compiler

  @shortdoc "Compile the on-device Mix shim"

  @impl Mix.Task.Compiler
  def run(_args) do
    if Mix.target() == :host do
      {:noop, []}
    else
      src = Path.expand("lib_shim/mix.ex")
      out = Path.join(Mix.Project.compile_path(), "Elixir.Mix.beam")

      if Mix.Utils.stale?([src, __ENV__.file], [out]) do
        script = """
        Code.put_compiler_option(:ignore_module_conflict, true)
        [{Mix, bin}] = Code.compile_string(File.read!(#{inspect(src)}), #{inspect(src)})
        File.write!(#{inspect(out)}, bin)
        """

        File.mkdir_p!(Path.dirname(out))

        case System.cmd("elixir", ["-e", script], stderr_to_stdout: true) do
          {_, 0} -> {:ok, []}
          {output, code} -> Mix.raise("Compiling the Mix shim failed (#{code}):\n#{output}")
        end
      else
        {:noop, []}
      end
    end
  end

  @impl Mix.Task.Compiler
  def clean() do
    File.rm(Path.join(Mix.Project.compile_path(), "Elixir.Mix.beam"))
    :ok
  end
end
