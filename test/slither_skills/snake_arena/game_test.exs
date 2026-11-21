defmodule SlitherSkills.SnakeArena.GameTest do
  use ExUnit.Case, async: true

  alias SlitherSkills.SnakeArena.Fruit
  alias SlitherSkills.SnakeArena.Bots
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
    dead = Game.tick(game, &keep_direction/3, &no_fruit/2)
    updated = Game.tick(dead, &keep_direction/3, &no_fruit/2)

    assert updated.snakes == %{}
    assert updated.status == :finished
    assert dead.snakes.one.status == :dead
  end

  test "a snake dies when it collides with its own body" do
    body = [{3, 3}, {3, 2}, {2, 2}, {2, 3}, {1, 3}]
    game = game_with([snake(:one, body, :left)])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert updated.snakes.one.status == :dead
    assert Game.tick(updated, &keep_direction/3, &no_fruit/2).snakes == %{}
  end

  test "both snakes die when their heads target the same cell" do
    first = snake(:first, [{3, 3}], :right)
    second = snake(:second, [{5, 3}], :left, :blue)
    game = game_with([first, second])

    dead = Game.tick(game, &keep_direction/3, &no_fruit/2)
    updated = Game.tick(dead, &keep_direction/3, &no_fruit/2)

    assert updated.snakes == %{}
    assert updated.status == :finished
    assert dead.snakes.first.status == :dead
    assert dead.snakes.second.status == :dead
  end

  test "a snake dies when it hits another snake, but the other survives" do
    first = snake(:first, [{3, 3}], :right)
    second = snake(:second, [{5, 3}, {4, 3}, {5, 2}], :up, :blue)
    game = game_with([first, second])

    updated = Game.tick(game, &keep_direction/3, &no_fruit/2)

    assert Map.has_key?(updated.snakes, :second)
    assert updated.snakes.first.status == :dead

    cleaned = Game.tick(updated, &keep_direction/3, &no_fruit/2)
    refute Map.has_key?(cleaned.snakes, :first)
    assert Map.has_key?(cleaned.snakes, :second)
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
    dead = Game.tick(running, &keep_direction/3, &no_fruit/2)
    finished = Game.tick(dead, &keep_direction/3, &no_fruit/2)
    assert finished.status == :finished
  end

  test "adding a snake to a waiting game starts it" do
    game = Game.new(width: 7, height: 7, fruit_count: 0)
    updated = Game.add_snake(game, snake(:one, [{3, 3}]))

    assert updated.status == :running
    assert Map.has_key?(updated.snakes, :one)
  end

  test "adding a snake to a finished game has no effect" do
    game = Game.new(width: 7, height: 7, fruit_count: 0)
    finished = Map.put(game, :status, :finished)
    updated = Game.add_snake(finished, snake(:one, [{3, 3}]))

    assert updated == finished
  end

  test "a finished game does not advance" do
    game = Game.new(width: 7, height: 7, fruit_count: 0)
    finished = Map.put(game, :status, :finished)

    assert Game.tick(finished, &keep_direction/3, &no_fruit/2) == finished
  end

  test "an invalid reverse direction falls back to the current direction" do
    game = game_with([snake(:one, [{3, 3}, {2, 3}, {1, 3}], :right)])
    reverse = fn _game, _snake, _safe_directions -> :left end
    updated = Game.tick(game, reverse, &no_fruit/2)

    assert updated.snakes.one.body == [{4, 3}, {3, 3}, {2, 3}]
  end

  test "a bot keeps its direction when no safe direction exists" do
    game = game_with([snake(:one, [{1, 1}], :up)], %{}, width: 3, height: 3)
    picker = Bots.direction_picker(fn _choices -> flunk("should not choose a direction") end)

    dead = Game.tick(game, picker, &no_fruit/2)

    assert dead.snakes.one.status == :dead
  end

  test "a new bot game contains five non-overlapping bots" do
    choose_first = fn choices -> hd(choices) end
    game = Bots.new_game(random_fun: choose_first)
    snakes = Map.values(game.snakes)
    body_cells = Enum.flat_map(snakes, & &1.body)

    assert game.status == :running
    assert length(snakes) == 5
    assert Enum.uniq(body_cells) == body_cells
    assert Enum.all?(snakes, &(&1.color in SlitherSkills.SnakeArena.Colors.all()))
  end

  test "twenty bots can be added without crashing" do
    choose_first = fn choices -> hd(choices) end
    game = Bots.new_game(bot_count: 20, random_fun: choose_first)

    assert map_size(game.snakes) == 20
  end

  test "a deterministic bot simulation advances many ticks" do
    choose_first = fn choices -> hd(choices) end
    game = Bots.new_game(random_fun: choose_first)
    direction_picker = Bots.direction_picker(choose_first)

    simulated =
      Enum.reduce(1..50, game, fn _, game ->
        Game.tick(game, direction_picker, &no_fruit/2)
      end)

    assert simulated.tick > 0
    assert simulated.tick <= 50
    assert simulated.status in [:running, :finished]
  end
end
