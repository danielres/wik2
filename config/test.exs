import Config

config :wik, Oban, testing: :manual
config :error_tracker, enabled: false

config :wik, token_signing_secret: "0RaegrszeoUZf8/Nmq0S/siUPZpCVgvn"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true
config :wik, Utils.Log, error_logging_enabled?: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :wik, Wik.Repo,
  database: Path.expand("../wik_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wik, WikWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zHCoLUmGXLeTDjUvWdXm8s5fvARDuopfD7aNAkI9FhHi82OksTJa7unNsS/vBZeQ",
  server: false

# In test we don't send emails
config :wik, Wik.Mailer, adapter: Swoosh.Adapters.Test

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
