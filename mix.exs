defmodule NervesLivebook.MixProject do
  use Mix.Project

  @app :nerves_livebook
  @version "0.14.0"
  @source_url "https://github.com/nerves-livebook/nerves_livebook"

  @rpi_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :rpi0_2, :rpi5, :frio_rpi4]
  @all_targets @rpi_targets ++
                 [:bbb, :osd32mp1, :x86_64, :npi_imx6ull, :grisp2, :mangopi_mq_pro]

  # See the BlueHeron repository for the boards that it supports.
  @ble_targets [:rpi0, :rpi3, :rpi3a]

  # Instruct the compiler to create deterministic builds to minimize
  # differences between firmware versions. This helps delta firmware update
  # compression.
  System.put_env("ERL_COMPILER_OPTIONS", "deterministic")

  def project do
    [
      app: @app,
      description: "Develop on embedded devices with Livebook and Nerves",
      author: "https://github.com/nerves-livebook/nerves_livebook/graphs/contributors",
      version: @version,
      package: package(),
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: "~> 1.10"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host, "phx.server": :host],
      dialyzer: dialyzer(),
      docs: docs(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
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
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.0"},
      {:ring_logger, "~> 0.9"},
      {:toolshed, "~> 0.4.0"},
      {:jason, "~> 1.2"},
      {:nerves_runtime, "~> 0.13.0"},
      {:livebook, "~> 0.14.0"},
      {:plug, "~> 1.12"},
      {:vintage_net, "~> 0.13"},

      # Pull in commonly used libraries as a convenience to users.
      {:blue_heron, "~> 0.4", targets: @ble_targets},
      {:blue_heron_transport_uart, "~> 0.1.4", targets: @ble_targets},
      {:bmp280, "~> 0.2", targets: @all_targets},
      {:circuits_gpio, "~> 2.0 or ~> 1.0"},
      {:circuits_i2c, "~> 2.0 or ~> 1.0"},
      {:circuits_spi, "~> 2.0 or ~> 1.0"},
      {:circuits_uart, "~> 1.3"},
      {:delux, "~> 0.2"},
      # hts221 needs circuits_i2c dependency bumped
      # {:hts221, "~> 1.0", targets: @all_targets},
      {:input_event, "~> 1.0 or ~> 0.4", targets: @all_targets},
      {:kino, "~> 0.14"},
      {:kino_maplibre, "~> 0.1.0"},
      {:kino_vega_lite, "~> 0.1.1"},
      {:maplibre, "~> 0.1.7"},
      {:nerves_key, "~> 1.0", targets: @all_targets},
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},
      {:nerves_time_zones, "~> 0.3.0", targets: @all_targets},
      {:nx, "~> 0.8.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:pinout, "~> 0.1"},
      {:progress_bar, "~> 3.0"},
      {:ramoops_logger, "~> 0.1", targets: @all_targets},
      {:recon, "~> 2.5"},
      {:req, "~> 0.5"},
      {:scroll_hat, "~> 0.1", targets: @rpi_targets},
      {:stb_image, "~> 0.6.0"},
      {:tflite_elixir, "~> 0.3.6", targets: @all_targets},
      {:vega_lite, "~> 0.1"},
      {:vintage_net_wifi, "~> 0.12.5", targets: @all_targets},
      {:vintage_net_qmi, "~> 0.4.1", targets: @all_targets},

      # Nerves system dependencies
      {:frio_rpi4, path: "../nerves_systems/src/frio_rpi4", runtime: false, targets: :frio_rpi4},


      # Compile-time only
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
      # {:sbom, "~> 0.6", only: :dev, runtime: false}
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
      overwrite: true,
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble, &deterministic_apps/1],
      strip_beams: [keep: ["Docs"]]
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  # TODO: Remove when Elixir 1.18 is released
  defp deterministic_apps(release_config) do
    pattern = Path.join([release_config.path, "**", "ebin", "*.app"])

    Path.wildcard(pattern)
    |> Enum.each(&make_app_deterministic/1)

    release_config
  end

  defp make_app_deterministic(path) do
    # Force the config_mtime so that it's not a random timestamp
    {:ok, [{:application, app, info}]} = :file.consult(path)
    new_info = Keyword.delete(info, :config_mtime)

    File.write!(path, :io_lib.format("~tp.~n", [{:application, app, new_info}]))
  end
end
