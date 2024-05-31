defmodule PtahClient do
  use Slipstream,
    restart: :temporary

  require Logger

  @topic "agent:daemon"

  use PtahProto, slipstream_topic: @topic
  alias PtahProto.Event
  alias PtahProto.Cmd

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(init_args) do
    host = Keyword.fetch!(init_args, :host)
    token = Keyword.fetch!(init_args, :token)

    Logger.debug("Connecting to #{host}")

    {:ok, assign(connect!(uri: host), :token, token), {:continue, :start_ping}}
  end

  @impl Slipstream
  def handle_connect(socket) do
    {:ok, sys_info} = DockerClient.get_version()

    {:ok, swarm} = get_swarm()

    Logger.debug(
      "Connected to docker host, platform: #{inspect(sys_info["Platform"]["Name"])}, version: #{inspect(sys_info["Version"])}"
    )

    Logger.debug("Connected to host, joining with token: #{socket.assigns[:token]}")

    {:ok,
     push(socket, %Cmd.Join{
       token: socket.assigns[:token],
       agent: %Cmd.Join.Agent{version: "0.0.0"},
       docker: %Cmd.Join.Docker{
         platform: sys_info["Platform"]["Name"],
         version: sys_info["Version"]
       },
       swarm: swarm
     })}
  end

  @impl Slipstream
  def handle_join(@topic, join_response, socket) do
    Logger.debug("Joined, join response: #{inspect(join_response)}")

    {:ok, socket}
  end

  @impl Slipstream
  def handle_continue(:start_ping, socket) do
    timer = :timer.send_interval(1_000, self(), :ping)

    {:noreply, assign(socket, :ping_timer, timer)}
  end

  @impl Slipstream
  def handle_info(:ping, socket) do
    # Disable ping for now
    # {:ok, _ref} = push(socket, @topic, "ping", %{"ping" => "pong"})

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.CreateSwarm{} = packet, socket) do
    # FIXME: this is not a swarm_id, this is the complete description of the swarm.
    {:ok, swarm_id} = DockerClient.post_swarm_init()

    {:ok, _} =
      DockerClient.post_networks_create(%{
        name: "ptah-net",
        attachable: true,
        scope: "swarm",
        driver: "overlay"
      })

    {:ok, info} = DockerClient.get_info()

    # TODO: label current node as caddy data host
    # TODO: install Caddy stack here

    # TODO: rename SwarmCreated into "swarm updated"?
    push(socket, %Event.SwarmCreated{
      swarm_id: packet.swarm_id,
      docker: %Event.SwarmCreated.Docker{
        swarm_id: swarm_id,
        node_id: info["Swarm"]["NodeID"]
      }
    })

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.CreateStack{} = packet, socket) do
    for service <- packet.services do
      {:ok, body} = DockerClient.post_services_create(service.service_spec)

      push(socket, %Event.ServiceCreated{
        service_id: service.service_id,
        docker: %{
          service_id: body["ID"]
        }
      })
    end

    {:noreply, socket}
  end

  def get_swarm() do
    {:ok, info} = DockerClient.get_info()

    case info["Swarm"]["LocalNodeState"] do
      "active" ->
        {:ok,
         %Cmd.Join.Swarm{
           swarm_id: info["Swarm"]["Cluster"]["ID"],
           node_id: info["Swarm"]["NodeID"]
         }}

      _ ->
        {:ok, nil}
    end
  end
end
