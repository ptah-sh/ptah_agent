defmodule CaddyClient.Load do
  defp endpoints do
    quote do
      def post_load(spec) do
        GenServer.call(__MODULE__, %{
          method: "POST",
          url: "/load",
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
