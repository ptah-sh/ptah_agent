import Config

config :ptah_agent, :docker, host: System.get_env("DOCKER_HOST", "http://localhost:2375")

config :ptah_agent, :caddy, host: System.get_env("CADDY_HOST", "http://caddy.ptah:2019")

config :ptah_agent, :ptah,
  home: System.get_env("PTAH_HOME", "/Users/bohdan/Projects/Personal/ptah-ex/agent_test"),
  host: System.get_env("PTAH_HOST", "ws://localhost:4000/sockets/agent/websocket"),
  mounts_root: System.get_env("PTAH_MOUNTS_ROOT", "/Users/bohdan/Projects/Personal/ptah-ex/data"),
  token:
    System.get_env(
      "PTAH_TOKEN",
      "SFMyNTY.g2gDYQFuBgAMU1XijwFiAAFRgA.YfvvErqXiBqmv_k0yA5b1OrA6sSwnvtuVIwQRc-x1Is"
    )
