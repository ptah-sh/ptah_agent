defmodule IfConfig do
  require Logger
  @space_re ~r/\s+/

  @flags_re ~r/^flags=\w+<(.*)>$/

  @inet_re ~r/^(inet)\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/

  def list_interfaces() do
    {output, 0} = System.cmd("ifconfig", ["-a"])

    output =
      String.split(output, "\n")
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&Regex.split(@space_re, &1))

    output
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&parse_if_line/1)
    |> Enum.reject(&(&1 == nil))
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "UP") end)
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "RUNNING") end)
    |> Enum.filter(fn {_, flags} -> Enum.member?(flags, "BROADCAST") end)
    |> Enum.filter(fn {_, flags} -> !Enum.member?(flags, "LOOPBACK") end)
    |> Enum.reduce(%{}, fn {name, _}, acc -> Map.put(acc, name, parse_if_data(output, name)) end)
    |> Enum.filter(fn {_, data} -> Enum.count(data) > 0 end)
  end

  defp parse_if_line(line) do
    [maybe_if_name, maybe_flags | _] = line

    if String.ends_with?(maybe_if_name, ":") do
      case Regex.run(@flags_re, maybe_flags) do
        [_match, flags] ->
          {maybe_if_name, String.split(flags, ",")}

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp parse_if_data(output, name) do
    index =
      output
      |> Enum.find_index(fn [if_name | _] -> if_name == name end)

    output
    |> Enum.slice((index + 1)..Enum.count(output))
    |> Enum.take_while(fn [if_name | _] -> if_name == "" end)
    |> Enum.map(fn line -> Regex.run(@inet_re, String.trim(Enum.join(line, " "))) end)
    |> Enum.reject(&(&1 == nil))
    |> Enum.map(fn [_, version, ip] -> {version, ip} end)
  end
end
