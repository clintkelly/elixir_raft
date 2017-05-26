defmodule ElixirRaft.ServerData do
  # Data for a server
  # TODO: Separate persistent data from state-dependent volatile
  # data.
  defstruct(
    # Last term the sever has seen
    current_term: 0,

    # Candidate for whom this server voted during the current term
    voted_for: :none,

    # List of log entries (each entry is {command, term})
    # First index is supposed to be "1" (sigh...)
    log: [],

    # Index of highest log entry known to be committed
    commit_index: 0,

    # Index of highest log entry applied to state machine
    last_applied: 0,
  )
end
