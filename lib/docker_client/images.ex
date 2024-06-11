defmodule DockerClient.Images do
  require Logger

  defp endpoints do
    quote do
      def post_images_create(spec) do
        GenServer.call(
          __MODULE__,
          %{
            method: :post,
            stream: true,
            url: "/images/create?fromImage=#{spec.from_image}",
            body: %{},
            status_map: %{}
          }
        )
      end

      def get_images_name_json(name) do
        GenServer.call(__MODULE__, %{method: :get, url: "/images/#{name}/json", body: %{}})
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
