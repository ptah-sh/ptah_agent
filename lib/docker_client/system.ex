defmodule DockerClient.System do
  defp get_version do
    quote do
      def get_version() do
        GenServer.call(__MODULE__, %{method: "GET", url: "/version"})
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      require Logger
      require Tesla

      unquote(get_version())
    end
  end
end
