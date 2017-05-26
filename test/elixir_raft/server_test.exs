defmodule ServerTest do
  use ExUnit.Case
  doctest ElixirRaft

  test "we can start a server" do
    {:ok, _pid} = GenStateMachine.start_link(
     ElixirRaft.Server,
     {:dummy_state, :dummy_data}
   )
  end
end
