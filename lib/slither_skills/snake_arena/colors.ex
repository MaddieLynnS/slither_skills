defmodule SlitherSkills.SnakeArena.Colors do
  @moduledoc "The fixed palette shared by snakes and fruits."

  @colors [:pink, :red, :blue, :green, :yellow, :purple, :orange]

  @type color :: :pink | :red | :blue | :green | :yellow | :purple | :orange

  @doc "Returns every color that may be assigned to a snake or fruit."
  @spec all() :: [color()]
  def all, do: @colors
end
