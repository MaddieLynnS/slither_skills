defmodule SlitherSkills.SnakeArena.GameServer do
  @moduledoc """
  GenServer for one room's running game.

  The process owns the room's random state and schedules pure game ticks. The
  pure `%Game{}` value remains separate from this process state so it can be
  tested without starting a server.
  """

  use GenServer

  alias SlitherSkills.SnakeArena.Bots
  alias SlitherSkills.SnakeArena.Colors
  alias SlitherSkills.SnakeArena.Game
  alias SlitherSkills.SnakeArena.Registry, as: RoomRegistry

  @default_bot_count 5
  @default_tick_interval 100
  @default_finished_timeout 30_000

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    room_supervisor = Keyword.fetch!(opts, :room_supervisor)
    tick_interval = Keyword.get(opts, :tick_interval, @default_tick_interval)
    finished_timeout = Keyword.get(opts, :finished_timeout, @default_finished_timeout)
    bot_count = Keyword.get(opts, :bot_count, @default_bot_count)
    seed = Keyword.get(opts, :seed, default_seed())

    :rand.seed(:exsss, seed_tuple(seed))

    game_opts =
      opts
      |> Keyword.get(:game_opts, [])
      |> Keyword.put(:bot_count, bot_count)
      |> Keyword.put(:fruit_picker, &random_fruit_choice/2)
      |> Keyword.put(:random_fun, &random_choice/1)

    case Elixir.Registry.register(RoomRegistry, room_id, :room) do
      {:ok, _owner} ->
        game = Bots.new_game(game_opts)
        timer_ref = schedule_tick(tick_interval)

        {:ok,
         %{
           room_id: room_id,
           game: game,
           tick_interval: tick_interval,
           timer_ref: timer_ref,
           finished_timeout: finished_timeout,
           finished_timer_ref: nil,
           room_supervisor: room_supervisor
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state.game, state}
  end

  @impl true
  def handle_info(:tick, state) do
    direction_picker = Bots.direction_picker(&random_choice/1)
    game = Game.tick(state.game, direction_picker, &random_fruit_choice/2)

    if game.status == :finished do
      cancel_timer(state.timer_ref)
      finished_timer_ref = Process.send_after(self(), :finished_timeout, state.finished_timeout)
      {:noreply, %{state | game: game, timer_ref: nil, finished_timer_ref: finished_timer_ref}}
    else
      timer_ref = schedule_tick(state.tick_interval)
      {:noreply, %{state | game: game, timer_ref: timer_ref}}
    end
  end

  @impl true
  def handle_info(:finished_timeout, state) do
    _ = Supervisor.stop(state.room_supervisor, :normal)
    {:stop, :normal, state}
  end

  defp schedule_tick(interval) when is_integer(interval) and interval >= 0 do
    Process.send_after(self(), :tick, interval)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref)

  defp random_fruit_choice(_fruit_id, []) do
    :none
  end

  defp random_fruit_choice(_fruit_id, positions) do
    {random_choice(Colors.all()), random_choice(positions)}
  end

  defp random_choice(choices) do
    Enum.at(choices, :rand.uniform(length(choices)) - 1)
  end

  defp default_seed do
    :erlang.unique_integer([:positive])
  end

  defp seed_tuple(seed) when is_integer(seed), do: {seed, seed + 1, seed + 2}
  defp seed_tuple(seed), do: seed
end
