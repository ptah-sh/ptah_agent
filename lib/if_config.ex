defmodule IfConfig do
  @if_re ~r/^(\w+):\sflags=\w+<(.*)>/

  @inet_re ~r/^(inet)\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/

  def list_interfaces() do
    {output, 0} = System.cmd("ifconfig", ["-a"])

    output =
      String.split(output, "\n")
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&String.split(&1, "\t"))

    Enum.map(output, &Enum.at(&1, 0))
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&parse_if_line/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "UP") end)
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "RUNNING") end)
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "BROADCAST") end)
    |> Enum.filter(fn {_, flags} -> !Enum.member?(flags, "LOOPBACK") end)
    |> Enum.reduce(%{}, fn {name, _}, acc -> Map.put(acc, name, parse_if_data(output, name)) end)
    |> Enum.filter(fn {_, data} -> Enum.count(data) > 0 end)
  end

  defp parse_if_line(line) do
    case Regex.run(@if_re, line) do
      [_match, if_name, flags] -> {if_name, String.split(flags, ",")}
      _ -> nil
    end
  end

  defp parse_if_data(output, name) do
    index =
      output
      |> Enum.find_index(fn [if_name | _] -> String.starts_with?(if_name, "#{name}:") end)

    output
    |> Enum.slice((index + 1)..Enum.count(output))
    |> Enum.take_while(fn [if_name | _] -> if_name == "" end)
    |> Enum.map(fn line -> Regex.run(@inet_re, Enum.join(line, "")) end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(fn [_, version, ip] -> {version, ip} end)
  end
end
