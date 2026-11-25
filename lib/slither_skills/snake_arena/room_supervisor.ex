defmodule SlitherSkills.SnakeArena.RoomSupervisor do
  @moduledoc "Supervises the game and player processes belonging to one room."

  use Supervisor

  alias SlitherSkills.SnakeArena.GameServer
  alias SlitherSkills.SnakeArena.PlayerSupervisor

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :transient
    }
  end

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)

    children = [
      {GameServer, Keyword.merge(opts, room_id: room_id, room_supervisor: self())},
      {PlayerSupervisor, [room_id: room_id]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
