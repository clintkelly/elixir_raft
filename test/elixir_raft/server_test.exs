defmodule ServerTest do
  use ExUnit.Case
  doctest ElixirRaft
  alias ElixirRaft.Server

  test "a server starts as a follower" do
    {:ok, pid} = Server.start_link
    assert :sys.get_state(pid).role == :follower
  end
end
