defmodule SlitherSkills.SnakeArena.Fruit do
  @moduledoc "The immutable state for one fruit in the arena."

  alias SlitherSkills.SnakeArena.Colors

  @type coordinate :: {non_neg_integer(), non_neg_integer()}
  @type color :: Colors.color()

  @enforce_keys [:id, :position, :color]
  defstruct id: nil,
            position: nil,
            color: nil

  @type t :: %__MODULE__{
          id: term(),
          position: coordinate(),
          color: color()
        }
end
