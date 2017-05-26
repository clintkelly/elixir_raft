defmodule ServerTest do
  use ExUnit.Case
  doctest ElixirRaft
  alias ElixirRaft.Server

  test "we can start a server" do
    {:ok, _pid} = GenStateMachine.start_link(
     ElixirRaft.Server,
     {:dummy_state, :dummy_data}
   )
  end

  test "a server starts as a follower" do
    {:ok, pid} = Server.start_link
    assert Server.state(pid) == :follower

  end
end
