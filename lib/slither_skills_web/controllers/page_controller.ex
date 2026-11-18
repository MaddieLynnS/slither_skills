defmodule SlitherSkillsWeb.PageController do
  use SlitherSkillsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
