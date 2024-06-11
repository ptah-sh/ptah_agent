defmodule CaddyClient do
  use GenServer

  use CaddyClient.Config
  use CaddyClient.Load

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(init_args) do
    host = Keyword.fetch!(init_args, :host)

    Logger.debug("Caddy host: #{host}")

    {:ok, %{host: host}}
  end

  @impl true
  def handle_call(%{method: method} = request, _from, state) do
    Logger.debug("CADDY REQUEST: #{inspect(request)}")

    req =
      Finch.build(
        method,
        "#{state.host}#{request.url}",
        # Headers
        [{"content-type", "application/json"}, {"accept", "application/json"}],
        # Body
        if Map.has_key?(request, :body) do
          request.body |> Jason.encode!()
        else
          nil
        end
      )

    {:ok, response} = req |> Finch.request(:Finch)

    Logger.debug(
      "CADDY RESPONSE: status: #{inspect(response.status)}, body: #{inspect(response.body)}"
    )

    data = response.body |> Jason.decode!()

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
