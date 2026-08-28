defmodule NervesLivebook.PowerKeyMonitor do
  @moduledoc """
  Gracefully powers off on KEY_POWER from the power/shutdown buttons.

  On the Seeed reComputer R22xx several devices can emit KEY_POWER:

  * the gpio-shutdown overlay's button (GPIO16)
  * the SoC's own pwr_button
  * `gpio-pse-int` — the overlay maps the PSE controller's interrupt line
    to KEY_POWER, intended as supercap-UPS power-loss detection. On
    current hardware that line storms (the kernel disables its IRQ after
    100k interrupts), so its semantics are unproven. Events from it are
    LOGGED but do not power off. Flip @acted_on once validated.

  Input devices appear asynchronously at boot, so subscription must
  never crash the app: init defers to a rescan loop that tolerates
  devices that are missing, unopenable, or gone again.
  """

  use GenServer
  require Logger

  @rescan_ms 5_000
  # Substrings of input device names that KEY_POWER may act on. Anything
  # else emitting KEY_POWER (e.g. "gpio-pse-int") is logged only.
  @acted_on ["pwr_button", "shutdown_button"]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{subscribed: %{}}, {:continue, :scan}}
  end

  @impl GenServer
  def handle_continue(:scan, state), do: {:noreply, scan(state)}

  @impl GenServer
  def handle_info(:scan, state), do: {:noreply, scan(state)}

  def handle_info({:input_event, path, events}, state) do
    down? = Enum.any?(events, &match?({:ev_key, :key_power, 1}, &1))

    if down? do
      name = Map.get(state.subscribed, path, "unknown")

      if Enum.any?(@acted_on, &String.contains?(name, &1)) do
        Logger.warning("PowerKeyMonitor: KEY_POWER from #{name} (#{path}) - powering off")
        Nerves.Runtime.poweroff()
      else
        Logger.warning(
          "PowerKeyMonitor: KEY_POWER from #{name} (#{path}) ignored (not in acted-on list)"
        )
      end
    end

    {:noreply, state}
  end

  def handle_info({:input_event_disconnected, path}, state) do
    {:noreply, %{state | subscribed: Map.delete(state.subscribed, path)}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp scan(state) do
    subscribed =
      try do
        for {path, %InputEvent.Info{} = info} <- InputEvent.enumerate(),
            not Map.has_key?(state.subscribed, path),
            key_power_capable?(info),
            reduce: state.subscribed do
          acc ->
            case InputEvent.start_link(path) do
              {:ok, _pid} ->
                Logger.info("PowerKeyMonitor: watching #{path} (#{info.name})")
                Map.put(acc, path, info.name)

              {:error, reason} ->
                Logger.info("PowerKeyMonitor: cannot watch #{path} yet: #{inspect(reason)}")
                acc
            end
        end
      rescue
        e ->
          Logger.info("PowerKeyMonitor: scan failed: #{inspect(e)}")
          state.subscribed
      end

    Process.send_after(self(), :scan, @rescan_ms)
    %{state | subscribed: subscribed}
  end

  defp key_power_capable?(%InputEvent.Info{report_info: report_info}) do
    Enum.any?(report_info, fn
      {:ev_key, keys} -> :key_power in List.wrap(keys)
      _ -> false
    end)
  end
end
