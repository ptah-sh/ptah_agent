import Config

config :ptah_agent, :docker, host: System.get_env("DOCKER_HOST", "http://localhost:2375")

config :ptah_agent, :ptah,
  host: System.get_env("PTAH_HOST", "ws://localhost:4000/sockets/agent/websocket"),
  mounts_root: System.get_env("PTAH_MOUNTS_ROOT", "/Users/bohdan/Projects/Personal/ptah-ex/data"),
  token:
    System.get_env(
      "PTAH_TOKEN",
      "SFMyNTY.g2gDYQFuBgC5Gk7ZjwFiAAFRgA.EKSwtMEWi-dRCM3vR1GELXwbfz5bwOpu01igXFxLwOI"
    )
