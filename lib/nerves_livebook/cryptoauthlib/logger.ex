defmodule NervesLivebook.Cryptoauthlib.Logger do
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_info({:log, message}, state) do
    Logger.info(message)
    {:noreply, state}
  end
end
