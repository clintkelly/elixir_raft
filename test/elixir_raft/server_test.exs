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
    set_timeout = fn -> 
      send x, :election_timeout
    end
    {:ok, _pid} = Server.start_link(set_timeout)
    assert_received :election_timeout
  end
end
