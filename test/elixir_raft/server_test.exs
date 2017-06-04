defmodule ServerTest do
  use ExUnit.Case
  doctest ElixirRaft
  alias ElixirRaft.Server

  test "a server starts as a follower" do
    {:ok, pid} = Server.start_link
    assert :sys.get_state(pid).role == :follower
  end

  test "a server starts an election timer upon startup" do
    x = self()
    set_timeout = fn _ -> 
      send x, {:election_timeout, 1}
    end
    {:ok, _pid} = Server.start_link(set_timeout)
    assert_received {:election_timeout, 1}
  end

  test "a canceled timer expiring does not change the state of the server" do
    set_timeout = fn _ -> :none end
    {:ok, pid} = Server.start_link(set_timeout)
    send pid, {:election_timeout, :sys.get_state(pid).most_recent_election_timeout_index - 1}
    assert :sys.get_state(pid).role == :follower
  end

  test "an uncanceled timer expiring changes the server to candidate" do
    set_timeout = fn _ -> :none end
    {:ok, pid} = Server.start_link(set_timeout)
    send pid, {:election_timeout, :sys.get_state(pid).most_recent_election_timeout_index}
    assert :sys.get_state(pid).role == :candidate
  end
end
