defmodule DockerClient.Swarm do
  defp endpoints do
    quote do
      def get_swarm() do
        GenServer.call(__MODULE__, %{
          method: "GET",
          url: "/swarm",
          status_map: %{503 => :not_swarm_node}
        })
      end

      def post_swarm_init() do
        GenServer.call(__MODULE__, %{
          method: "POST",
          url: "/swarm/init",
          body: %{
            ListenAddr: "0.0.0.0:2375"
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
