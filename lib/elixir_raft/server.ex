defmodule ElixirRaft.Server do
  use GenServer
  alias ElixirRaft.ServerState
  alias ElixirRaft.Server

  @election_timeout_ms 300

  # Client

  def start_link(set_timeout_func \\ &Server.set_timeout/1) do
    GenServer.start_link(__MODULE__, %ServerState{set_timeout_func: set_timeout_func})
  end

  # Server

  def init(state = %ServerState{ most_recent_election_timeout_index: index }) do
    _ref = state.set_timeout_func.(index)
    {:ok, %ServerState{state | most_recent_election_timeout_index: index+1} }
  end

  def set_timeout(index) do
    Process.send_after(self(), {:election_timeout, index}, @election_timeout_ms)
  end

  def handle_info(
    {:election_timeout, index},
    state = %ServerState{most_recent_election_timeout_index: most_recent_index}
  ) when most_recent_index > index do
    # Just do nothing
    {:noreply, state}
  end

  def handle_info(
    {:election_timeout, index},
    state = %ServerState{most_recent_election_timeout_index: most_recent_index}
  ) when most_recent_index == index do
    change_to_candidate_state(state)
  end

  def change_to_candidate_state(state) do
    new_state = %ServerState{state | role: :candidate}
    {:noreply, new_state}
  end
end
