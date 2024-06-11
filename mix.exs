defmodule PtahAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptah_agent,
      version: "1.8.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :finch
      ],
      mod: {PtahAgent.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      # slipstream for phoenix channel connections
      {:slipstream, "~> 1.1"},
      {:finch, "~> 0.18.0"},
      {:jason, ">= 1.0.0"},
      # ptah_proto for ptah. :)
      {:ptah_proto, git: "https://github.com/ptah-sh/ptah_proto.git", branch: "main"}
    ]
  end
end
