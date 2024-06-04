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
    Logger.debug("CADDY REQUEST: #{inspect(request)}")

    {:ok, %{status: status, body: body}} =
      Tesla.get(state, "http://localhost:2019#{request.url}")

    Logger.debug("CADDY RESPONSE: status: #{inspect(status)}, body: #{inspect(body)}")

    result =
      case status do
        200 -> {:ok, body}
        other -> {:error, map_status_to_error(other, request), body}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(%{method: "POST"} = request, _from, state) do
    Logger.debug("CADDY REQUEST: #{inspect(request)}")

    {:ok, %{status: status, body: body}} =
      Tesla.post(state, "http://localhost:2019#{request.url}", request.body)

    Logger.debug("CADDY RESPONSE: status: #{inspect(status)}, body: #{inspect(body)}")

    result =
      case status do
        _ when status in [200, 201] -> {:ok, body}
        other -> {:error, map_status_to_error(other, request), body}
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
