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

      def post_swarm_init(attrs) do
        GenServer.call(__MODULE__, %{
          method: "POST",
          url: "/swarm/init",
          body: %{
            ListenAddr: attrs.listen_addr,
            AdvertiseAddr: attrs.advertise_addr
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
