defmodule SlitherSkills.SnakeArena.Snake do
  @moduledoc """
  The immutable state for one snake in the arena.

  `body` is always ordered from head to tail. The first coordinate is the
  snake's head, which makes movement and collision checks straightforward.
  Coordinates are `{x, y}` tuples, with `{0, 0}` at the top-left of the board.
  """

  alias SlitherSkills.SnakeArena.Colors

  @type coordinate :: {non_neg_integer(), non_neg_integer()}
  @type color :: Colors.color()
  @type direction :: :up | :down | :left | :right
  @type status :: :alive | :dead

  @base_length 3

  @enforce_keys [:id, :body, :color]
  defstruct id: nil,
            body: [],
            direction: :right,
            color: nil,
            growth_pending: 0,
            status: :alive

  @doc "The minimum number of cells used when creating a new snake."
  @spec base_length() :: pos_integer()
  def base_length, do: @base_length

  @type t :: %__MODULE__{
          id: term(),
          body: [coordinate()],
          direction: direction(),
          color: color(),
          growth_pending: non_neg_integer(),
          status: status()
        }
end
