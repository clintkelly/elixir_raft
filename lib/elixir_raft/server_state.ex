defmodule ElixirRaft.ServerState do
  # State for a server
  # TODO: Separate persistent data from state-dependent volatile
  # data.
  defstruct(
    # Can be follower, candidate, or leader
    role: :follower,

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

    # Pointer to function used to set election timeouts
    # (Necessary for dependency injection in testing)
    # See http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/ 
    set_timeout_func: :none,

    # Keep track of the index of the most recent election timeout. Ignore any
    # that are not the latest (instead of just canceling).
    most_recent_election_timeout_index: -1,
  )
end
