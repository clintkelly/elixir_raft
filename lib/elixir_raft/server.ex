defmodule ElixirRaft.Server do
  use GenServer
  alias ElixirRaft.ServerState

  # Client

  def start_link do
    GenServer.start_link(__MODULE__, %ServerState{})
  end
end
