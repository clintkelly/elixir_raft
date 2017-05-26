defmodule ElixirRaft.Server do
  use GenStateMachine
  alias ElixirRaft.Server
  alias ElixirRaft.ServerData

  # Client

  def start_link do
    GenStateMachine.start_link(Server, {:follower, %ServerData{}})
  end

  # Getter for state (for tests)
  def state(pid) do
    GenStateMachine.call(pid, :get_state)
  end

  # Server (callbacks)

  def handle_event({:call, from}, :get_state, state, data) do
    {:next_state, state, data, [{:reply, from, state}]}
  end

end
