defmodule DockerClient.Configs do
  defp endpoints do
    quote do
      def post_configs_create(spec) do
        GenServer.call(__MODULE__, %{
          method: :post,
          url: "/configs/create",
          body: %{
            Name: spec.name,
            Data: DockerClient.Configs.encode_value(spec.data)
          },
          status_map: %{}
        })
      end

      def get_configs_id(id) do
        {:ok, config} =
          GenServer.call(__MODULE__, %{
            method: :get,
            url: "/configs/#{id}",
            status_map: %{
              404 => :not_found
            }
          })

        {:ok,
         config
         |> update_in(["Spec", "Data"], &DockerClient.Configs.decode_value/1)}
      end
    end
  end

  def encode_value(value) when is_struct(value) or is_map(value) do
    Jason.encode!(value) |> Base.encode64()
  end

  def decode_value(value) do
    Base.decode64!(value) |> Jason.decode!()
  end

  defmacro __using__(_opts) do
    quote do
      unquote(endpoints())
    end
  end
end
