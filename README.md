# SlitherSkills

To start your Phoenix server:

* Run `mix setup` to install dependencies and build assets (it does not create or migrate a database)
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Brainstorming:
snake has length and color attributes, starts at length 5. if snake collides with fruit, it will grow one in length. Fruit of different colors, and if you eat one that's your same color you grow two. Fruits appear in random locations around play area where there aren't snakes or other fruits. If snake collides with wall or another snake, game ends and asks if user wants to retry. A game ends completely if all snakes die or if mod stops it (kills all processes)
Need: Snake, Fruit, Game, GameArena with dimensions, maybe Player?
