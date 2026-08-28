defmodule NervesLivebook.PowerKeyMonitor do
  @moduledoc """
  Gracefully powers off when a KEY_POWER input event arrives.

  On the Seeed reComputer R22xx two device tree sources emit KEY_POWER:
  the gpio-shutdown overlay (front power button on GPIO16) and the
  overlay's pse-intb line, which the PSE power-monitoring circuit pulls
  on mains loss so the supercapacitor UPS can carry a clean shutdown.

  Both arrive as gpio-keys devices. This process subscribes to every
  input device that can produce KEY_POWER and calls
  `Nerves.Runtime.poweroff/0` on the first key-down.
  """

  use GenServer
  require Logger

  @key_power 116

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    devices =
      for {path, %InputEvent.Info{} = info} <- InputEvent.enumerate(),
          {:ev_key, keys} <- info.report_info,
          :key_power in List.wrap(keys) do
        {:ok, _pid} = InputEvent.start_link(path)
        Logger.info("PowerKeyMonitor: watching #{path} (#{info.name})")
        path
      end

    if devices == [] do
      Logger.info("PowerKeyMonitor: no KEY_POWER-capable input devices found")
    end

    {:ok, %{devices: devices}}
  end

  @impl GenServer
  def handle_info({:input_event, path, events}, state) do
    down? =
      Enum.any?(events, fn
        {:ev_key, :key_power, 1} -> true
        {:ev_key, @key_power, 1} -> true
        _ -> false
      end)

    if down? do
      Logger.warning("PowerKeyMonitor: KEY_POWER from #{path} - powering off")
      Nerves.Runtime.poweroff()
    end

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}
end
