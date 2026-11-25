defmodule SlitherSkills.SnakeArena.PlayerSupervisor do
  @moduledoc "Placeholder dynamic supervisor for one room's players and bots."

  use DynamicSupervisor

  @doc false
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
