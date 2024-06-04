defmodule DockerClient.Services do
  defp endpoints do
    quote do
      def post_services_create(spec) do
        GenServer.call(__MODULE__, %{
          method: "POST",
          url: "/services/create",
          body: %{
            Name: spec.name,
            TaskTemplate: %{
              ContainerSpec: %{
                Image: spec.task_template.container_spec.image,
                Hostname: spec.task_template.container_spec.hostname,
                Env:
                  Enum.map(spec.task_template.container_spec.env, fn env ->
                    "#{env.name}=#{env.value}"
                  end),
                Mounts:
                  Enum.map(spec.task_template.container_spec.mounts, fn mount ->
                    %{
                      Target: mount.target,
                      Source: mount.source,
                      Type: mount.type,
                      BindOptions: %{
                        CreateMountpoint: mount.bind_options.create_mountpoint
                      }
                    }
                  end)
              },
              Placement: %{
                Constraints: spec.task_template.placement.constraints
              },
              Networks:
                Enum.map(spec.task_template.networks, fn network ->
                  %{Target: network.target, Aliases: network.aliases}
                end)
            },
            Mode: %{
              Replicated: %{
                Replicas: spec.mode.replicated.replicas
              }
            },
            EndpointSpec: %{
              Ports:
                Enum.map(spec.endpoint_spec.ports, fn port ->
                  %{
                    Protocol: port.protocol,
                    TargetPort: port.target_port,
                    PublishedPort: port.published_port,
                    PublishedMode: port.published_mode
                  }
                end)
            }
          },
          status_map: %{}
        })
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      unquote(endpoints())
    end
  end
end
