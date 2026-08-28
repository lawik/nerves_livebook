defmodule NervesLivebook.UI do
  @moduledoc """
  Log connection status changes

  Livebook, of course, is the main UI. This module used to drive a status
  LED via delux; on the reComputer R22xx branch delux is dropped, so it
  just logs connection changes. The R22xx's RGB LED is available under
  /sys/class/leds (led-red/led-green/led-blue) for notebooks to play with.
  """
  use GenServer
  require Logger

  @doc """
  Start the UI GenServer

  Options:
    * None
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    VintageNet.subscribe(["connection"])
    {:ok, :no_state}
  end

  @impl GenServer
  def handle_info({VintageNet, ["connection"], _old, value, _meta}, state) do
    Logger.info("Connection status: #{inspect(value)}")
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
