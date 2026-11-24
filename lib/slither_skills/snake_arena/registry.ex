defmodule SlitherSkills.SnakeArena.Registry do
  @moduledoc "Registry used to look up rooms by their caller-supplied IDs."

  @name __MODULE__

  @doc "Returns the registered room process for an ID, if one exists."
  @spec lookup(term()) :: {:ok, pid()} | :error
  def lookup(room_id) do
    case Elixir.Registry.lookup(@name, room_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc "Returns the registry name used by the application supervision tree."
  @spec name() :: module()
  def name, do: @name
end
