defmodule SlitherSkills.SnakeArena.RoomSupervisor do
  @moduledoc "Supervises the game and player processes belonging to one room."

  use Supervisor

  alias SlitherSkills.SnakeArena.GameServer
  alias SlitherSkills.SnakeArena.PlayerSupervisor

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)

    children = [
      {GameServer, Keyword.put(opts, :room_id, room_id)},
      {PlayerSupervisor, [room_id: room_id]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
