defmodule SlitherSkills.SnakeArena.Game do
  @moduledoc """
  The immutable state and pure rules for one Snake Arena game.

  Snake bodies are ordered from head to tail. Coordinates on the outer border
  are invalid, so the playable cells are `1..width - 2` by `1..height - 2`.
  """

  alias SlitherSkills.SnakeArena.Colors
  alias SlitherSkills.SnakeArena.Fruit
  alias SlitherSkills.SnakeArena.Snake

  @directions [:up, :down, :left, :right]
  @default_fruit_count 20

  @type coordinate :: Snake.coordinate()
  @type direction :: Snake.direction()
  @type status :: :waiting | :running | :paused | :finished
  @type direction_picker ::
          (t(), Snake.t(), [direction()] -> direction())
  @type fruit_picker ::
          (term(), [coordinate()] -> {Colors.color(), coordinate()} | :none)

  defstruct width: 40,
            height: 40,
            snakes: %{},
            fruits: %{},
            fruit_count: @default_fruit_count,
            tick: 0,
            status: :waiting

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          snakes: %{optional(term()) => Snake.t()},
          fruits: %{optional(term()) => Fruit.t()},
          fruit_count: non_neg_integer(),
          tick: non_neg_integer(),
          status: status()
        }

  @doc "Creates a game and fills it with as many fruits as possible."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    defaults = %__MODULE__{}
    width = Keyword.get(opts, :width, defaults.width)
    height = Keyword.get(opts, :height, defaults.height)
    fruit_count = Keyword.get(opts, :fruit_count, defaults.fruit_count)
    fruit_picker = Keyword.get(opts, :fruit_picker, &default_fruit_choice/2)

    game = %__MODULE__{width: width, height: height, fruit_count: fruit_count}
    %{game | fruits: replenish_fruits(game, %{}, fruit_count, fruit_picker)}
  end

  @doc "Adds a snake and moves an empty game from `:waiting` to `:running`."
  @spec add_snake(t(), Snake.t()) :: t()
  def add_snake(%__MODULE__{status: :finished} = game, _snake), do: game

  def add_snake(%__MODULE__{} = game, %Snake{} = snake) do
    %{game | snakes: Map.put(game.snakes, snake.id, snake), status: :running}
  end

  @doc "Returns the directions that avoid the current walls and snake bodies."
  @spec safe_directions(t(), Snake.t()) :: [direction()]
  def safe_directions(%__MODULE__{} = game, %Snake{} = snake) do
    @directions
    |> Enum.reject(&(&1 == opposite(snake.direction)))
    |> Enum.filter(fn direction ->
      destination = move_head(snake, direction)

      in_playable_area?(game, destination) and
        not occupied_by_current_bodies?(game, destination)
    end)
  end

  @doc "Returns whether a coordinate is inside the playable part of the arena."
  @spec playable_position?(t(), coordinate()) :: boolean()
  def playable_position?(%__MODULE__{} = game, position),
    do: in_playable_area?(game, position)

  @doc """
  Advances every living snake by one cell.

  The direction picker receives the game, snake, and directions that are safe
  on the current board. The fruit picker receives a fruit ID and available
  positions and returns `{color, position}` or `:none`. Both callbacks are
  injected so tests can remain deterministic.
  """
  @spec tick(t(), direction_picker(), fruit_picker()) :: t()
  def tick(%__MODULE__{status: status} = game, _direction_picker, _fruit_picker)
      when status in [:waiting, :finished],
      do: game

  def tick(%__MODULE__{} = game, direction_picker, fruit_picker) do
    game = remove_dead_snakes(game)

    if map_size(game.snakes) == 0 do
      %{game | status: :finished, tick: game.tick + 1}
    else
      advance_tick(game, direction_picker, fruit_picker)
    end
  end

  defp advance_tick(%__MODULE__{} = game, direction_picker, fruit_picker) do
    living_snakes = living_snakes(game)

    directions =
      Map.new(living_snakes, fn {id, snake} ->
        safe = safe_directions(game, snake)
        chosen = direction_picker.(game, snake, safe)
        {id, valid_direction(chosen, snake.direction)}
      end)

    proposed_heads =
      Map.new(living_snakes, fn {id, snake} ->
        {id, move_head(snake, Map.fetch!(directions, id))}
      end)

    projected_bodies =
      Map.new(living_snakes, fn {id, snake} ->
        growth_now = if snake.growth_pending > 0, do: 1, else: 0
        {id, projected_body(snake, Map.fetch!(proposed_heads, id), growth_now)}
      end)

    collision_ids = collision_ids(game, proposed_heads, projected_bodies)

    survivors =
      living_snakes
      |> Enum.reject(fn {id, _snake} -> MapSet.member?(collision_ids, id) end)
      |> Map.new(fn {id, snake} ->
        head = Map.fetch!(proposed_heads, id)
        fruit = fruit_at(game.fruits, head)
        fruit_growth = growth_for(snake, fruit)
        available_growth = snake.growth_pending + fruit_growth
        growth_now = min(available_growth, 1)
        growth_pending = available_growth - growth_now

        {id,
         %{snake | body: projected_body(snake, head, growth_now), growth_pending: growth_pending}}
      end)

    dead_snakes =
      living_snakes
      |> Enum.filter(fn {id, _snake} -> MapSet.member?(collision_ids, id) end)
      |> Map.new(fn {id, snake} -> {id, %{snake | status: :dead}} end)

    next_snakes =
      game.snakes
      |> Map.merge(dead_snakes)
      |> Map.merge(survivors)

    eaten_ids =
      survivors
      |> Enum.flat_map(fn {_id, snake} ->
        case fruit_at(game.fruits, hd(snake.body)) do
          %Fruit{id: fruit_id} -> [fruit_id]
          nil -> []
        end
      end)
      |> MapSet.new()

    remaining_fruits = Map.drop(game.fruits, MapSet.to_list(eaten_ids))
    fruit_count = max(game.fruit_count, map_size(remaining_fruits))
    fruits = replenish_fruits(game, remaining_fruits, fruit_count, fruit_picker, eaten_ids)

    %{
      game
      | snakes: next_snakes,
        fruits: fruits,
        fruit_count: fruit_count,
        tick: game.tick + 1,
        status: :running
    }
  end

  defp remove_dead_snakes(%__MODULE__{} = game) do
    %{game | snakes: Map.filter(game.snakes, fn {_id, snake} -> snake.status != :dead end)}
  end

  defp living_snakes(%__MODULE__{snakes: snakes}) do
    Enum.filter(snakes, fn {_id, snake} -> snake.status == :alive end)
  end

  defp collision_ids(game, proposed_heads, projected_bodies) do
    out_of_bounds =
      proposed_heads
      |> Enum.filter(fn {_id, position} -> not in_playable_area?(game, position) end)
      |> Enum.map(&elem(&1, 0))

    self_collisions =
      projected_bodies
      |> Enum.filter(fn {id, body} -> Map.fetch!(proposed_heads, id) in tl(body) end)
      |> Enum.map(&elem(&1, 0))

    body_collisions =
      for {id, head} <- proposed_heads,
          {other_id, body} <- projected_bodies,
          id != other_id,
          head in body,
          do: id

    head_collisions =
      proposed_heads
      |> Enum.group_by(fn {_id, position} -> position end, &elem(&1, 0))
      |> Enum.flat_map(fn {_position, ids} -> if length(ids) > 1, do: ids, else: [] end)

    MapSet.new(out_of_bounds ++ self_collisions ++ body_collisions ++ head_collisions)
  end

  defp projected_body(%Snake{body: body}, head, growth) do
    keep_count = max(length(body) - 1 + growth, 0)
    [head | Enum.take(body, keep_count)]
  end

  defp growth_for(_snake, nil), do: 0
  defp growth_for(%Snake{color: color}, %Fruit{color: color}), do: 2
  defp growth_for(%Snake{}, %Fruit{}), do: 1

  defp fruit_at(fruits, position) do
    Enum.find_value(fruits, fn {_id, fruit} -> if fruit.position == position, do: fruit end)
  end

  defp replenish_fruits(game, fruits, target_count, fruit_picker, recycled_ids \\ MapSet.new()) do
    needed = max(target_count - map_size(fruits), 0)
    recycled = Enum.filter(MapSet.to_list(recycled_ids), &is_nil(Map.get(fruits, &1)))
    new_ids = Stream.iterate(next_fruit_id(fruits), &(&1 + 1))
    ids = recycled ++ Enum.take(new_ids, max(needed - length(recycled), 0))

    Enum.reduce_while(ids, fruits, fn id, acc ->
      positions = available_positions(game, acc)

      case fruit_picker.(id, positions) do
        {color, position} ->
          if color in Colors.all() and position in positions do
            fruit = %Fruit{id: id, color: color, position: position}
            {:cont, Map.put(acc, id, fruit)}
          else
            {:halt, acc}
          end

        _ ->
          {:halt, acc}
      end
    end)
  end

  defp next_fruit_id(fruits) do
    fruits
    |> Map.keys()
    |> Enum.filter(&is_integer/1)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp available_positions(game, fruits) do
    occupied =
      game.snakes
      |> Map.values()
      |> Enum.flat_map(& &1.body)
      |> Kernel.++(Enum.map(Map.values(fruits), & &1.position))
      |> MapSet.new()

    for x <- 1..(game.width - 2),
        y <- 1..(game.height - 2),
        {x, y} not in occupied,
        do: {x, y}
  end

  defp occupied_by_current_bodies?(game, position) do
    Enum.any?(game.snakes, fn {_id, snake} ->
      body_without_tail = Enum.drop(snake.body, -1)
      position in body_without_tail
    end)
  end

  defp in_playable_area?(game, {x, y}),
    do: x > 0 and x < game.width - 1 and y > 0 and y < game.height - 1

  defp move_head(%Snake{body: [{x, y} | _]}, :up), do: {x, y - 1}
  defp move_head(%Snake{body: [{x, y} | _]}, :down), do: {x, y + 1}
  defp move_head(%Snake{body: [{x, y} | _]}, :left), do: {x - 1, y}
  defp move_head(%Snake{body: [{x, y} | _]}, :right), do: {x + 1, y}

  defp valid_direction(direction, current) do
    if direction in @directions and direction != opposite(current) do
      direction
    else
      current
    end
  end

  defp opposite(:up), do: :down
  defp opposite(:down), do: :up
  defp opposite(:left), do: :right
  defp opposite(:right), do: :left

  defp default_fruit_choice(id, positions) do
    case positions do
      [] -> :none
      [position | _] -> {Enum.at(Colors.all(), rem(id, length(Colors.all()))), position}
    end
  end
end
