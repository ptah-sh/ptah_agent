defmodule DockerClient do
  use GenServer

  use DockerClient.System

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(init_args) do
    host = Keyword.fetch!(init_args, :host)

    Logger.debug("Connecting to #{host}")

    {:ok, client(host)}
  end

  def client(_host) do
    middleware = [
      # {Tesla.Middleware.BaseUrl, host},
      Tesla.Middleware.JSON
    ]

    Tesla.client(
      middleware,
      Tesla.Adapter.Hackney
    )
  end

  @impl true
  def handle_call(%{method: "GET"} = request, _from, state) do
    socket_path = URI.encode_www_form("/var/run/docker.sock")

    {:ok, %{body: body}} =
      Tesla.get(state, "http+unix://#{socket_path}#{request.url}")

    {:reply, body, state}
  end
end
