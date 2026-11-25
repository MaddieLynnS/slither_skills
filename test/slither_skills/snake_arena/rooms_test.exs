defmodule SlitherSkills.SnakeArena.RoomsTest do
  use ExUnit.Case, async: false

  alias SlitherSkills.SnakeArena.Game
  alias SlitherSkills.SnakeArena.GameServer
  alias SlitherSkills.SnakeArena.PlayerSupervisor
  alias SlitherSkills.SnakeArena.Rooms

  setup do
    room_id = {:rooms_test, make_ref()}
    on_exit(fn -> Rooms.stop(room_id) end)
    {:ok, room_id: room_id}
  end

  test "starts a room and registers its game process", %{room_id: room_id} do
    {:ok, room_supervisor} =
      Rooms.start(room_id, bot_count: 0, tick_interval: 60_000, game_opts: [fruit_count: 0])

    {:ok, game_pid} = Rooms.lookup(room_id)

    assert is_pid(room_supervisor)
    assert is_pid(game_pid)
    assert GenServer.call(game_pid, :state) == %Game{fruit_count: 0}

    children = Supervisor.which_children(room_supervisor)

    assert Enum.any?(children, fn
             {GameServer, _pid, :worker, _modules} -> true
             _ -> false
           end)

    assert Enum.any?(children, fn
             {PlayerSupervisor, _pid, :supervisor, _modules} ->
               true

             _ ->
               false
           end)

    assert {:ok, %Game{fruit_count: 0}} = Rooms.state(room_id)
  end

  test "state returns not found for a missing room" do
    assert Rooms.state({:missing_room, make_ref()}) == {:error, :not_found}
  end

  test "duplicate room IDs are rejected", %{room_id: room_id} do
    assert {:ok, _room_supervisor} = Rooms.start(room_id, game_opts: [fruit_count: 0])
    assert {:error, _reason} = Rooms.start(room_id, game_opts: [fruit_count: 0])
    assert {:ok, _game_pid} = Rooms.lookup(room_id)
  end

  test "a room restart restarts its game and player siblings", %{room_id: room_id} do
    {:ok, room_supervisor} = Rooms.start(room_id, game_opts: [fruit_count: 0])
    {:ok, old_game_pid} = Rooms.lookup(room_id)
    old_player_pid = child_pid(room_supervisor, PlayerSupervisor)
    game_ref = Process.monitor(old_game_pid)
    player_ref = Process.monitor(old_player_pid)

    Process.exit(old_game_pid, :kill)

    assert_receive {:DOWN, ^game_ref, :process, ^old_game_pid, _reason}
    assert_receive {:DOWN, ^player_ref, :process, ^old_player_pid, _reason}
    _ = :sys.get_state(room_supervisor)

    {:ok, new_game_pid} = Rooms.lookup(room_id)
    new_player_pid = child_pid(room_supervisor, PlayerSupervisor)
    assert new_game_pid != old_game_pid
    assert new_player_pid != old_player_pid
  end

  test "one room can be restarted while another remains available", %{room_id: first_id} do
    second_id = {:rooms_test_second, make_ref()}
    on_exit(fn -> Rooms.stop(second_id) end)

    {:ok, first_supervisor} = Rooms.start(first_id, game_opts: [fruit_count: 0])
    {:ok, first_game} = Rooms.lookup(first_id)
    {:ok, _second_supervisor} = Rooms.start(second_id, game_opts: [fruit_count: 0])
    {:ok, second_game} = Rooms.lookup(second_id)
    second_state = GenServer.call(second_game, :state)

    Process.exit(first_game, :kill)
    _ = :sys.get_state(first_supervisor)

    assert {:ok, _new_first_game} = await_lookup(first_id)
    assert GenServer.call(second_game, :state) == second_state
  end

  test "a game server starts five bots and advances on its tick message", %{room_id: room_id} do
    {:ok, _room_supervisor} =
      Rooms.start(room_id, tick_interval: 60_000, game_opts: [fruit_count: 0])

    {:ok, game_pid} = Rooms.lookup(room_id)
    initial = GenServer.call(game_pid, :state)
    send(game_pid, :tick)
    _ = :sys.get_state(game_pid)
    updated = GenServer.call(game_pid, :state)

    assert map_size(initial.snakes) == 5
    assert initial.status == :running
    assert updated.tick == 1
  end

  test "rooms advance independently", %{room_id: first_id} do
    second_id = {:rooms_test_independent, make_ref()}
    on_exit(fn -> Rooms.stop(second_id) end)

    {:ok, _first_supervisor} = Rooms.start(first_id, tick_interval: 60_000)
    {:ok, first_game} = Rooms.lookup(first_id)
    {:ok, _second_supervisor} = Rooms.start(second_id, tick_interval: 60_000)
    {:ok, second_game} = Rooms.lookup(second_id)

    send(first_game, :tick)
    _ = :sys.get_state(first_game)

    assert GenServer.call(first_game, :state).tick == 1
    assert GenServer.call(second_game, :state).tick == 0
  end

  test "a finished room shuts down after its configurable timeout", %{room_id: room_id} do
    {:ok, _room_supervisor} =
      Rooms.start(
        room_id,
        bot_count: 1,
        tick_interval: 60_000,
        finished_timeout: 10,
        game_opts: [width: 5, height: 5, fruit_count: 0]
      )

    {:ok, game_pid} = Rooms.lookup(room_id)

    {finished_state, _attempts} =
      Enum.reduce_while(1..100, {nil, 0}, fn attempt, {_state, _count} ->
        send(game_pid, :tick)
        _ = :sys.get_state(game_pid)
        state = GenServer.call(game_pid, :state)

        if state.status == :finished do
          {:halt, {state, attempt}}
        else
          {:cont, {state, attempt}}
        end
      end)

    assert finished_state.status == :finished
    assert await_room(room_id, 50) == :error
  end

  defp child_pid(supervisor, child_module) do
    {^child_module, pid, _type, _modules} =
      Enum.find(Supervisor.which_children(supervisor), fn {id, _pid, _type, _modules} ->
        id == child_module
      end)

    pid
  end

  defp await_lookup(room_id, attempts \\ 20)

  defp await_lookup(_room_id, 0), do: :error

  defp await_lookup(room_id, attempts) do
    case Rooms.lookup(room_id) do
      {:ok, _pid} = result ->
        result

      :error ->
        receive do
        after
          10 -> await_lookup(room_id, attempts - 1)
        end
    end
  end

  defp await_room(room_id, attempts) when attempts > 0 do
    case Rooms.lookup(room_id) do
      :error ->
        :error

      {:ok, _pid} ->
        receive do
        after
          10 -> await_room(room_id, attempts - 1)
        end
    end
  end

  defp await_room(_room_id, 0), do: :found
end
