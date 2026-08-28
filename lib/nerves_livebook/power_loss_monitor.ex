defmodule NervesLivebook.PowerLossMonitor do
  @moduledoc """
  Detect mains power loss by polling the SuperCAP UPS module's LTC3350.

  The reComputer R22xx's optional SuperCAP UPS (LTC3350, i2c-2 @ 0x09)
  sits between the DC input and the CM5, riding the system through short
  outages. Its PFO alert line's host GPIO routing is undocumented, and
  Seeed's pse-intb KEY_POWER vector is dead while the PSE subsystem is
  unpowered — so this polls the charger's input-voltage measurement
  instead: nominally ~11.4 V here, it collapses on mains loss while the
  supercaps hold the output rails up.

  After `@debounce` consecutive samples below `@threshold_mv` (with a
  healthy reading seen first, so a missing/odd module can never trigger
  it), logs and calls `Nerves.Runtime.poweroff/0`.

  Disable the poweroff (keeping detection logs) with:

      config :nerves_livebook, power_loss_poweroff: false
  """

  use GenServer
  require Logger

  @bus "i2c-2"
  @addr 0x09
  @reg_vin 0x1B
  # LSB is 2.21mV
  @lsb_uv 2210
  @threshold_mv 6_000
  @healthy_mv 8_000
  @poll_ms 1_000
  @debounce 3

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Latest input-voltage sample in millivolts, or nil."
  def vin_mv(), do: GenServer.call(__MODULE__, :vin_mv)

  @impl GenServer
  def init(_opts) do
    state = %{i2c: nil, vin_mv: nil, healthy_seen: false, low_count: 0, errors: 0}
    {:ok, state, {:continue, :open}}
  end

  @impl GenServer
  def handle_continue(:open, state) do
    schedule(@poll_ms)
    {:noreply, open_bus(state)}
  end

  @impl GenServer
  def handle_call(:vin_mv, _from, state), do: {:reply, state.vin_mv, state}

  @impl GenServer
  def handle_info(:poll, %{i2c: nil} = state) do
    schedule(@poll_ms * 10)
    {:noreply, open_bus(state)}
  end

  def handle_info(:poll, state) do
    state =
      case Circuits.I2C.write_read(state.i2c, @addr, <<@reg_vin>>, 2) do
        {:ok, <<lo, hi>>} ->
          mv = div((hi * 256 + lo) * @lsb_uv, 1000)
          handle_sample(%{state | vin_mv: mv, errors: 0}, mv)

        {:error, reason} ->
          errors = state.errors + 1

          if errors == 5 do
            Logger.info(
              "PowerLossMonitor: LTC3350 not responding (#{inspect(reason)}), " <>
                "backing off - is the SuperCAP UPS module installed?"
            )
          end

          %{state | errors: errors}
      end

    schedule(if state.errors >= 5, do: @poll_ms * 30, else: @poll_ms)
    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp handle_sample(state, mv) when mv >= @healthy_mv do
    if not state.healthy_seen do
      Logger.info("PowerLossMonitor: supercap UPS input healthy at #{mv} mV, armed")
    end

    %{state | healthy_seen: true, low_count: 0}
  end

  defp handle_sample(%{healthy_seen: true} = state, mv) when mv < @threshold_mv do
    low_count = state.low_count + 1
    Logger.warning("PowerLossMonitor: input #{mv} mV (#{low_count}/#{@debounce})")

    if low_count >= @debounce do
      if Application.get_env(:nerves_livebook, :power_loss_poweroff, true) do
        Logger.warning("PowerLossMonitor: mains lost - powering off on supercap")
        Nerves.Runtime.poweroff()
      else
        Logger.warning("PowerLossMonitor: mains lost (poweroff disabled by config)")
      end
    end

    %{state | low_count: low_count}
  end

  defp handle_sample(state, _mv), do: %{state | low_count: 0}

  defp open_bus(state) do
    case Circuits.I2C.open(@bus) do
      {:ok, ref} -> %{state | i2c: ref}
      {:error, _} -> state
    end
  end

  defp schedule(ms), do: Process.send_after(self(), :poll, ms)
end
