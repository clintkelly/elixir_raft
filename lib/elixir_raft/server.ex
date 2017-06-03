defmodule ElixirRaft.Server do
  use GenServer
  alias ElixirRaft.ServerState
  alias ElixirRaft.Server

  # Client

  def start_link(set_timeout_func \\ &Server.set_timeout/0) do
    GenServer.start_link(__MODULE__, %ServerState{set_timeout_func: set_timeout_func})
  end

  def init(state) do
    state.set_timeout_func.()
    {:ok, state}
  end

  def set_timeout do
  end
end
