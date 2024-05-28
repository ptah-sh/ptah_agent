defmodule DockerClient.Services do
  defp endpoints do
    quote do
      def post_services_create(spec) do
        %{task_template: task_template, endpoint_spec: endpoint_spec} = spec

        GenServer.call(__MODULE__, %{
          method: "POST",
          url: "/services/create",
          body: %{
            Name: spec.name,
            TaskTemplate: %{
              ContainerSpec: %{
                Image: task_template.container_spec.image,
                Hostname: "#{task_template.container_spec.name}.#{spec.name}"
              },
              Networks:
                Enum.map(task_template.networks, fn network -> %{Target: network.target} end)
            },
            Mode: %{
              Replicated: %{
                Replicas: 3
              }
            },
            EndpointSpec: %{
              Ports:
                Enum.map(endpoint_spec.ports, fn {_name, port} ->
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
