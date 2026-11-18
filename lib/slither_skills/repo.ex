defmodule SlitherSkills.Repo do
  use Ecto.Repo,
    otp_app: :slither_skills,
    adapter: Ecto.Adapters.Postgres
end
