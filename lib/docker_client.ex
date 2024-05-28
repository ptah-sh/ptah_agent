defmodule DockerClient do
  use GenServer

  use DockerClient.Swarm
  use DockerClient.System

  require Logger

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

    {:ok, %{status: status, body: body}} =
      Tesla.get(state, "http+unix://#{socket_path}#{request.url}")

    result =
      case status do
        200 -> {:ok, body}
        other -> {:error, map_status_to_error(other, request), body}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(%{method: "POST"} = request, _from, state) do
    socket_path = URI.encode_www_form("/var/run/docker.sock")

    {:ok, %{status: status, body: body}} =
      Tesla.post(state, "http+unix://#{socket_path}#{request.url}", request.body)

    result =
      case status do
        200 -> {:ok, body}
        other -> {:error, map_status_to_error(other, request), body}
      end

    {:reply, result, state}
  end

  defp map_status_to_error(status, request) do
    Map.get(request.status_map, status, :unknown_error)
  end
end
