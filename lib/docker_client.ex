defmodule DockerClient do
  use GenServer

  use DockerClient.Configs
  use DockerClient.Images
  use DockerClient.Networks
  use DockerClient.Nodes
  use DockerClient.Services
  use DockerClient.Swarm
  use DockerClient.System

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(init_args) do
    host = Keyword.fetch!(init_args, :host)
    # unix_socket = Keyword.fetch!(init_args, :unix_socket)

    Logger.debug("Docker host: #{host}")

    {:ok, %{}}
  end

  @impl true
  def handle_call(%{method: method} = request, _from, state) do
    # socket_path = URI.encode_www_form("/var/run/docker.sock")

    Logger.debug("DOCKER REQUEST: #{inspect(request)}")

    req =
      Finch.build(
        method,
        "http://localhost:2375#{request.url}",
        # Headers
        [{"content-type", "application/json"}, {"accept", "application/json"}],
        # Body
        if Map.has_key?(request, :body) do
          request.body |> Jason.encode!()
        else
          nil
        end,
        unix_socket: "/var/run/docker.sock"
      )

    # {:ok, data} =
    #   if Map.has_key?(request, :stream) and request.stream do
    #     req
    #     |> Finch.stream_while(:Finch, nil, fn kv, _acc ->
    #       Logger.emergency("DOCKER RESPONSE: #{inspect(kv)}")

    #       {:cont, kv}
    #     end)
    #   else
    #     req |> Finch.request(:Finch)
    #   end

    {:ok, response} = req |> Finch.request(:Finch)

    Logger.debug(
      "DOCKER RESPONSE: status: #{inspect(response.status)}, body: #{inspect(response.body)}"
    )

    data =
      if Map.has_key?(request, :stream) and request.stream do
        response.body
        |> String.split("\r\n")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&Jason.decode!/1)
      else
        if response.body == "" do
          %{}
        else
          response.body |> Jason.decode!()
        end
      end

    result =
      case response.status do
        _ when response.status in [200, 201] -> {:ok, data}
        other -> {:error, map_status_to_error(other, request), data}
      end

    {:reply, result, state}
  end

  defp map_status_to_error(status, request) do
    status_map =
      Map.merge(
        %{
          400 => :bad_request
        },
        request.status_map
      )

    Map.get(status_map, status, :unknown_error)
  end
end
