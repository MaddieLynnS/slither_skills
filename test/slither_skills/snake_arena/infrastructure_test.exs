defmodule SlitherSkills.SnakeArena.InfrastructureTest do
  use ExUnit.Case, async: false

  alias SlitherSkills.SnakeArena.GameSupervisor
  alias SlitherSkills.SnakeArena.Registry

  test "the application starts the arena registry and game supervisor" do
    assert Process.whereis(Registry)
    assert Process.whereis(GameSupervisor)
  end

  test "the room registry enforces unique room IDs" do
    room_id = {:infrastructure_test, make_ref()}
    assert {:ok, _value} = Elixir.Registry.register(Registry, room_id, :room)
    assert {:ok, pid} = Registry.lookup(room_id)
    assert pid == self()

    assert {:error, {:already_registered, ^pid}} =
             Elixir.Registry.register(Registry, room_id, :other)

    Elixir.Registry.unregister(Registry, room_id)
  end

  test "the game supervisor can manage independent dynamic children" do
    {:ok, first} = DynamicSupervisor.start_child(GameSupervisor, {Agent, fn -> :first end})
    {:ok, second} = DynamicSupervisor.start_child(GameSupervisor, {Agent, fn -> :second end})

    assert Agent.get(first, & &1) == :first
    assert Agent.get(second, & &1) == :second
    assert DynamicSupervisor.count_children(GameSupervisor).active >= 2

    :ok = DynamicSupervisor.terminate_child(GameSupervisor, first)
    assert Agent.get(second, & &1) == :second
    :ok = DynamicSupervisor.terminate_child(GameSupervisor, second)
  end
end
