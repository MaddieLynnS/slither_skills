import Config

# Database access is opt-in in tests so game and web logic can be tested
# without a running PostgreSQL server.
config :slither_skills, start_repo: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :slither_skills, SlitherSkillsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "FMeB9A3xCCRhLXDuaWtSqWawCDITXn4Sg8QE1v92rwTiN0KZjYxgB7C/CQgIIlWf",
  server: false

# In test we don't send emails
config :slither_skills, SlitherSkills.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
