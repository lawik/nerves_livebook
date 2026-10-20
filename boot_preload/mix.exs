defmodule BootPreload.MixProject do
  use Mix.Project

  def project do
    [app: :boot_preload, version: "0.1.0", elixir: "~> 1.15", deps: []]
  end

  def application do
    [mod: {BootPreload, []}, extra_applications: [:logger]]
  end
end
