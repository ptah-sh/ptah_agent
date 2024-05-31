defmodule DockerClient.System do
  defp get_version do
    quote do
      def get_version() do
        GenServer.call(__MODULE__, %{method: "GET", url: "/version", status_map: %{}})
      end

      def get_info() do
        GenServer.call(__MODULE__, %{method: "GET", url: "/info", status_map: %{}})
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      unquote(get_version())
    end
  end
end
