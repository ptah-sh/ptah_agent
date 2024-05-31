import Config

config :ptah_agent, :docker, host: System.get_env("DOCKER_HOST", "http://localhost:2375")

config :ptah_agent, :ptah,
  host: System.get_env("PTAH_HOST", "ws://localhost:4000/sockets/agent/websocket"),
  token:
    System.get_env(
      "PTAH_TOKEN",
      "SFMyNTY.g2gDYQFuBgCIpIjOjwFiAAFRgA.r1_XeWf2DU_xWM7dIaF_KSfs2nCEqVK10oc-ZvG4EmE"
    )
