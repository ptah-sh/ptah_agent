defmodule CaddyClient.Config do
  defp endpoints do
    quote do
      def get_config(path) do
        GenServer.call(__MODULE__, %{
          method: :get,
          url: "/config/#{path}",
          status_map: %{}
        })
      end

      def post_config(path, spec) do
        GenServer.call(__MODULE__, %{
          method: :post,
          url: "/config/#{path}",
          body: spec,
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
