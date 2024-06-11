defmodule DockerClient.Nodes do
  defp endpoints do
    quote do
      def get_nodes_id(id) do
        GenServer.call(__MODULE__, %{
          method: :get,
          url: "/nodes/#{id}",
          status_map: %{}
        })
      end

      def post_nodes_id_update(id, node_version, spec) do
        GenServer.call(__MODULE__, %{
          method: :post,
          url: "/nodes/#{id}/update?version=#{node_version}",
          body: %{
            Labels: spec.labels
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
