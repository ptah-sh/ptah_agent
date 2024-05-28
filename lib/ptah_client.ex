defmodule PtahClient do
  use Slipstream,
    restart: :temporary

  require Logger

  @topic "agent:daemon"

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
     join(socket, @topic, %{
       token: socket.assigns[:token],
       agent: %{version: "0.0.0"},
       docker: %{platform: sys_info["Platform"]["Name"], version: sys_info["Version"]},
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

  @impl Slipstream
  def handle_message(_topic, "swarm:create", payload, socket) do
    {:ok, swarm_id} = DockerClient.post_swarm_init()

    {:ok, _} =
      DockerClient.post_networks_create(%{
        name: "ptah-net",
        attachable: true,
        scope: "swarm",
        driver: "overlay"
      })

    # TODO: label current node as caddy data host
    # TODO: install Caddy stack here

    push(socket, @topic, "swarm:created", %{
      meta: %{
        swarm_id: payload["meta"]["swarm_id"]
      },
      data: %{
        swarm_id: swarm_id
      }
    })

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(_topic, "stack:create", stack_template, socket) do
    for %{name: name, template: template} <- stack_template["services"] do
      {:ok} = DockerClient.post_services_create(Map.merge(template, %{name: name}))
    end

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(topic, event, message, socket) do
    Logger.debug("Unhandled message: #{inspect({topic, event, message})}")

    {:noreply, socket}
  end

  def get_swarm() do
    case DockerClient.get_swarm() do
      {:ok, swarm} -> {:ok, swarm}
      {:error, :not_swarm_node, _res} -> {:ok, nil}
      {:error, other, _res} -> {:error, other, %{}}
    end
  end

  # def try_stack_create() do
  #   DockerClient.post_services_create(%{
  #     name: "test-stack",
  #     task_template: %{
  #       container_spec: %{
  #         name: "nginx",
  #         image: "nginx:latest"
  #       },
  #       networks: [%{target: "ptah-net"}]
  #     },
  #     mode: %{replicated: %{replicas: 3}},
  #     endpoint_spec: %{
  #       ports: %{
  #         "web" => %{
  #           protocol: "tcp",
  #           target_port: 80,
  #           published_port: 80,
  #           published_mode: "ingress"
  #         }
  #       }
  #     }
  #   })
  # end
end
