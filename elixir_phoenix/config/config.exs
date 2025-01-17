# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir_phoenix,
  ecto_repos: [ElixirPhoenix.Repo],
  generators: [timestamp_type: :timestamptz],
  dashboard_event_key: "dashboard_events",
  dashboard_event_topic: "dashboard-events:updates",
  webauthn_origin: "http://localhost:4000",
  webauthn_rp_id: "localhost",
  webauthn_timeout_ms: 60000

# Configures the endpoint
config :elixir_phoenix, ElixirPhoenixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ElixirPhoenixWeb.ErrorHTML, json: ElixirPhoenixWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ElixirPhoenix.PubSub,
  live_view: [signing_salt: "ozO1R7FG"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :elixir_phoenix, ElixirPhoenix.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  elixir_phoenix: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  elixir_phoenix: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :joken,
  default_signer: [
    signer_alg: "HS512",
    key_octet: "ouni#9HTi*sa<R!x0xtU4cg}4g$iH^JoEbu4D*n="
  ]

# TODO: Does this do anything at all?
config :wax_,
  update_metadata: true

config :elixir_phoenix, Oban,
  engine: Oban.Engines.Basic,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", ElixirPhoenix.Workers.SampleEventPublisher}
     ]}
  ],
  queues: [default: 10],
  repo: ElixirPhoenix.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
