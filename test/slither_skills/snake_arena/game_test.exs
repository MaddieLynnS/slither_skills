defmodule SlitherSkills.SnakeArena.GameTest do
  use ExUnit.Case, async: true

  alias SlitherSkills.SnakeArena.Fruit
  alias SlitherSkills.SnakeArena.Game
  alias SlitherSkills.SnakeArena.Snake

  defp game_with(snakes, fruits \\ %{}, opts \\ []) do
    %Game{
      width: Keyword.get(opts, :width, 7),
      height: Keyword.get(opts, :height, 7),
      snakes: Map.new(snakes, &{&1.id, &1}),
      fruits: fruits,
      fruit_count: Keyword.get(opts, :fruit_count, map_size(fruits)),
      status: if(snakes == [], do: :waiting, else: :running)
    }
  end

  defp snake(id, body, direction \\ :right, color \\ :red) do
    %Snake{id: id, body: body, direction: direction, color: color}
  end

  defp no_fruit(_id, _positions), do: :none

  defp keep_direction(_game, snake, _safe_directions), do: snake.direction

  test "moves a snake head-first and leaves the old game unchanged" do
    original = game_with([snake(:one, [{3, 3}, {2, 3}, {1, 3}])])
    updated = Game.tick(original, &keep_direction/3, &no_fruit/2)

    assert updated.snakes.one.body == [{4, 3}, {3, 3}, {2, 3}]
    assert original.snakes.one.body == [{3, 3}, {2, 3}, {1, 3}]
    assert updated.tick == 1
  end

  test "a snake dies when it reaches the outer border" do
    game = game_with([snake(:one, [{1, 3}, {2, 3}, {3, 3}], :left)])
    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert updated.snakes == %{}
    assert updated.status == :finished
  end

  test "a snake dies when it collides with its own body" do
    body = [{3, 3}, {3, 2}, {2, 2}, {2, 3}, {1, 3}]
    game = game_with([snake(:one, body, :left)])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert updated.snakes == %{}
  end

  test "both snakes die when their heads target the same cell" do
    first = snake(:first, [{3, 3}], :right)
    second = snake(:second, [{5, 3}], :left, :blue)
    game = game_with([first, second])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert updated.snakes == %{}
    assert updated.status == :finished
  end

  test "a snake dies when it hits another snake, but the other survives" do
    first = snake(:first, [{3, 3}], :right)
    second = snake(:second, [{5, 3}, {4, 3}, {5, 2}], :up, :blue)
    game = game_with([first, second])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert Map.has_key?(updated.snakes, :second)
    refute Map.has_key?(updated.snakes, :first)
  end

  test "a departing tail cell is safe to enter" do
    first = snake(:first, [{1, 3}], :right)
    second = snake(:second, [{4, 3}, {3, 3}, {2, 3}], :up, :blue)
    game = game_with([first, second])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert Map.has_key?(updated.snakes, :first)
    assert Map.has_key?(updated.snakes, :second)
  end

  test "a fruit increases length and is replaced" do
    snake = snake(:one, [{3, 3}, {2, 3}, {1, 3}], :right, :red)
    fruit = %Fruit{id: 1, position: {4, 3}, color: :blue}
    game = game_with([snake], %{1 => fruit}, fruit_count: 1)
    replacement = fn 1, [position | _] -> {:green, position} end

    updated = Game.tick(game, &keep_direction/3, replacement)

    assert length(updated.snakes.one.body) == 4
    assert updated.snakes.one.growth_pending == 0
    assert updated.fruits[1].color == :green
    refute updated.fruits[1].position == {4, 3}
  end

  test "a same-color fruit grants two units of growth" do
    snake = snake(:one, [{3, 3}, {2, 3}, {1, 3}], :right, :red)
    fruit = %Fruit{id: 1, position: {4, 3}, color: :red}
    game = game_with([snake], %{1 => fruit}, fruit_count: 1)

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert length(updated.snakes.one.body) == 4
    assert updated.snakes.one.growth_pending == 1
  end

  test "an empty game waits and a game with no survivors finishes" do
    game = Game.new(width: 7, height: 7, fruit_count: 0)
    assert game.status == :waiting
    assert Game.tick(game, &keep_direction/3, &no_fruit/2) == game

    running = Game.add_snake(game, snake(:one, [{1, 3}], :left))
    finished = Game.tick(running, &keep_direction/3, &no_fruit/2)
    assert finished.status == :finished
  end
end
