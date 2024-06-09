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
    mounts_root = Keyword.fetch!(init_args, :mounts_root)
    token = Keyword.fetch!(init_args, :token)

    Logger.debug("Connecting to #{host}.")
    Logger.debug("Mounts root: #{mounts_root}.")

    {:ok, assign(connect!(uri: host), token: token, mounts_root: mounts_root),
     {:continue, :start_ping}}
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
       agent: %Cmd.Join.Agent{version: "v#{Application.spec(:ptah_agent, :vsn)}"},
       mounts_root: socket.assigns[:mounts_root],
       docker: %Cmd.Join.Docker{
         platform: sys_info["Platform"]["Name"],
         version: sys_info["Version"]
       },
       swarm: swarm,
       networks:
         IfConfig.list_interfaces()
         |> Enum.map(fn {name, addresses} ->
           %Cmd.Join.Network{
             name: name,
             ips:
               addresses
               |> Enum.map(fn {version, ip} ->
                 %Cmd.Join.Networks.IP{version: version, address: ip}
               end)
           }
         end)
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
    {:ok, swarm_id} = DockerClient.post_swarm_init(packet)

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

    # TODO: rename SwarmCreated into "swarm updated" so it can be reused on join and swarm creation?
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

      # Creating mounts manually as Docker Desktop doesn't create ones even with CreateMountpoint bind option.
      for mount <- service.service_spec.task_template.container_spec.mounts do
        :ok = File.mkdir_p(mount.source)
      end

      push(socket, %Event.ServiceCreated{
        service_id: service.service_id,
        docker: %{
          service_id: body["ID"]
        }
      })
    end

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.CreateConfig{} = packet, socket) do
    {:ok, body} = DockerClient.post_configs_create(packet)

    push(socket, %Event.ConfigCreated{
      config_id: packet.config_id,
      docker: %{
        config_id: body["ID"]
      }
    })

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.UpdateService{} = packet, socket) do
    {:ok, docker_service} = DockerClient.get_services_id(packet.docker.service_id)

    service_version = docker_service["Version"]["Index"]

    {:ok, _} =
      DockerClient.post_services_id_update(
        packet.docker.service_id,
        service_version,
        packet.service_spec
      )

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.LoadCaddyConfig{} = payload, socket) do
    if Kernel.map_size(payload.config["apps"]["http"]["servers"]) > 0 do
      {:ok, _} = CaddyClient.post_load(payload.config)
    end

    {:noreply, socket}
  end

  @impl PtahProto
  def handle_packet(%Cmd.SelfUpgrade{} = payload, _socket) do
    # TODO: trigger events on start/finish and send the action log.
    # TODO: cleanup old versions. Amount of versions to keep should be configurable.

    Logger.debug("Self upgrade to version #{payload.version} started.")

    Logger.debug("Downloading version...")

    {_, 0} =
      System.cmd(
        "curl",
        [
          "-sSL",
          "https://github.com/ptah-sh/ptah_agent/releases/download/#{payload.version}/ptah_agent_linux_x86_64.tar.xz",
          "-o",
          "/tmp/ptah_agent_#{payload.version}.tar.xz"
        ],
        stderr_to_stdout: true
      )

    Logger.debug("Extracting version...")

    home = Keyword.fetch!(Application.get_env(:ptah_agent, :ptah), :home)

    target_dir = "#{home}/versions/#{payload.version}"

    File.mkdir_p!(target_dir)

    {_, 0} =
      System.cmd(
        "tar",
        [
          "-xJf",
          "/tmp/ptah_agent_#{payload.version}.tar.xz",
          "-C",
          target_dir
        ],
        stderr_to_stdout: true
      )

    Logger.debug("Linking version...")

    {_, 0} = System.cmd("ln", ["-nsf", "#{target_dir}/ptah_agent", "#{home}/current"])

    Logger.debug("Upgrade complete! Shutting down an app.")

    System.stop(0)
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
