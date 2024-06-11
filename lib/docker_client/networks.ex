defmodule DockerClient.Networks do
  defp endpoints do
    quote do
      def post_networks_create(spec) do
        GenServer.call(__MODULE__, %{
          method: :post,
          url: "/networks/create",
          body: %{
            Name: spec.name,
            Driver: spec.driver,
            Attachable: spec.attachable,
            Scope: spec.scope
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
