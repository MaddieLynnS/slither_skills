defmodule SlitherSkills.SnakeArena.Rooms do
  @moduledoc "Public room lifecycle operations."

  alias SlitherSkills.SnakeArena.GameSupervisor
  alias SlitherSkills.SnakeArena.Registry
  alias SlitherSkills.SnakeArena.RoomSupervisor

  @doc "Starts a room with the caller-supplied ID."
  @spec start(term(), keyword()) :: DynamicSupervisor.on_start_child()
  def start(room_id, opts \\ []) do
    child_opts = Keyword.put(opts, :room_id, room_id)
    DynamicSupervisor.start_child(GameSupervisor, {RoomSupervisor, child_opts})
  end

  @doc "Looks up a room process by its ID."
  @spec lookup(term()) :: {:ok, pid()} | :error
  def lookup(room_id), do: Registry.lookup(room_id)

  @doc "Stops a room by its ID."
  @spec stop(term()) :: :ok | {:error, term()}
  def stop(room_id) do
    case lookup(room_id) do
      {:ok, game_pid} ->
        case room_supervisor_for(game_pid) do
          nil -> {:error, :room_supervisor_not_found}
          room_pid -> DynamicSupervisor.terminate_child(GameSupervisor, room_pid)
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp room_supervisor_for(game_pid) do
    GameSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.find_value(fn {_id, room_pid, :supervisor, _modules} ->
      child_pids =
        room_pid
        |> Supervisor.which_children()
        |> Enum.map(fn {_id, child_pid, _type, _modules} -> child_pid end)

      if game_pid in child_pids, do: room_pid
    end)
  end
end
