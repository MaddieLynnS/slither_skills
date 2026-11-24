defmodule SlitherSkills.SnakeArena.GameSupervisor do
  @moduledoc """
  Dynamic supervisor for independent Snake Arena rooms.

  Each child will eventually be a room supervisor. Keeping rooms underneath a
  dynamic supervisor means one room can fail without taking down other rooms.
  """

  use DynamicSupervisor

  @name __MODULE__

  @doc false
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: @name)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Returns the registered name of the room dynamic supervisor."
  @spec name() :: module()
  def name, do: @name
end
