defmodule SlitherSkills.SnakeArena.Bots do
  @moduledoc """
  Bot creation and direction selection for Snake Arena.

  Randomness is supplied as a function so production code can use
  `Enum.random/1`, while tests can provide a deterministic chooser.
  """

  alias SlitherSkills.SnakeArena.Colors
  alias SlitherSkills.SnakeArena.Game
  alias SlitherSkills.SnakeArena.Snake

  @directions [:up, :down, :left, :right]
  @default_bot_count 5

  @type random_fun :: ([term()] -> term())

  @doc "Creates a new game populated with five bot snakes by default."
  @spec new_game(keyword()) :: Game.t()
  def new_game(opts \\ []) do
    bot_count = Keyword.get(opts, :bot_count, @default_bot_count)
    random_fun = Keyword.get(opts, :random_fun, &Enum.random/1)

    opts
    |> Game.new()
    |> add_bots(bot_count, random_fun)
  end

  @doc "Adds as many valid bot snakes as possible to an existing game."
  @spec add_bots(Game.t(), non_neg_integer(), random_fun()) :: Game.t()
  def add_bots(game, count \\ @default_bot_count, random_fun \\ &Enum.random/1) do
    Enum.reduce(1..count, game, fn id, game ->
      case new_snake(game, {:bot, id}, random_fun) do
        {:ok, snake} -> Game.add_snake(game, snake)
        :error -> game
      end
    end)
  end

  @doc "Creates one randomly placed bot snake, or returns `:error` if full."
  @spec new_snake(Game.t(), term(), random_fun()) :: {:ok, Snake.t()} | :error
  def new_snake(game, id, random_fun \\ &Enum.random/1) do
    candidates = starting_positions(game)

    case candidates do
      [] ->
        :error

      _ ->
        {body, direction} = random_fun.(candidates)
        color = random_fun.(Colors.all())
        {:ok, %Snake{id: id, body: body, direction: direction, color: color}}
    end
  end

  @doc "Chooses a random safe direction, or keeps direction when none is safe."
  @spec choose_direction(Game.t(), Snake.t(), [Snake.direction()], random_fun()) ::
          Snake.direction()
  def choose_direction(_game, snake, [], _random_fun), do: snake.direction

  def choose_direction(_game, _snake, safe_directions, random_fun),
    do: random_fun.(safe_directions)

  @doc "Returns a direction-picker callback suitable for `Game.tick/3`."
  @spec direction_picker(random_fun()) :: Game.direction_picker()
  def direction_picker(random_fun \\ &Enum.random/1) do
    fn game, snake, safe_directions ->
      choose_direction(game, snake, safe_directions, random_fun)
    end
  end

  defp starting_positions(game) do
    occupied = occupied_positions(game)

    for head <- playable_positions(game),
        direction <- @directions,
        body = body_for(head, direction),
        Enum.all?(body, &Game.playable_position?(game, &1)),
        Enum.all?(body, &(not MapSet.member?(occupied, &1))),
        do: {body, direction}
  end

  defp playable_positions(game) do
    for x <- 1..(game.width - 2),
        y <- 1..(game.height - 2),
        do: {x, y}
  end

  defp occupied_positions(game) do
    snake_positions =
      game.snakes
      |> Map.values()
      |> Enum.flat_map(& &1.body)

    fruit_positions = Enum.map(Map.values(game.fruits), & &1.position)
    MapSet.new(snake_positions ++ fruit_positions)
  end

  defp body_for({x, y}, :up), do: [{x, y}, {x, y + 1}, {x, y + 2}]
  defp body_for({x, y}, :down), do: [{x, y}, {x, y - 1}, {x, y - 2}]
  defp body_for({x, y}, :left), do: [{x, y}, {x + 1, y}, {x + 2, y}]
  defp body_for({x, y}, :right), do: [{x, y}, {x - 1, y}, {x - 2, y}]
end
