defmodule DigitalBlockchain.OSCListener do
  use GenServer
  require Logger

  @port 9010

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true, reuseaddr: true])
    Logger.info("🎛️  OSC Listener started on port #{@port}")
    {:ok, Map.put(state, :socket, socket)}
  end

  def handle_info({:udp, _socket, ip, port, data}, state) do
    case OSCx.decode(data) do
      %OSCx.Message{address: path, arguments: args} ->
        Logger.debug("🎶 OSC #{path} #{inspect(args)} from #{:inet.ntoa(ip)}:#{port}")
        route_osc({path, args})

      _ ->
        Logger.warning("⚠️ Unhandled OSC data  XX: #{inspect(data)}")
    end

    {:noreply, state}
  end
  defp route_osc({"/xy1", [x, y]}) do
    Logger.info("🟢 XY Pad /xy1 => x=#{x}, y=#{y}")
    DigitalBlockchain.RCDaemon.send_to_rcnode("XY #{x} #{y}")
  end

  defp route_osc({"/radial1", [value]}) do
    Logger.info("🎚️ Radial /radial1 => value=#{value}")
    DigitalBlockchain.RCDaemon.send_to_rcnode("RADIAL 1 #{value}")
  end

  defp route_osc({"/radar1", [x, y]}) do
    Logger.info("📡 Radar /radar1 => x=#{x}, y=#{y}")
    DigitalBlockchain.RCDaemon.send_to_rcnode("RADAR 1 #{x} #{y}")
  end

  defp route_osc({"/encoder1", [value]}) do
    Logger.info("🌀 Encoder /encoder1 => value=#{value}")
    DigitalBlockchain.RCDaemon.send_to_rcnode("ENCODER 1 #{value}")
  end

  defp route_osc({"/button1", [value]}) do
    Logger.info("🔘 Button /button1 => value=#{value}")
    DigitalBlockchain.RCDaemon.send_to_rcnode("BUTTON 1 #{value}")
  end

  defp route_osc({path, [value]}) do
    if String.starts_with?(path, "/grid1/") do
      case String.split(path, "/") do
        ["", "grid1", btn] ->
          Logger.info("🟩 Grid dynamic => btn=#{btn}, value=#{value}")
          DigitalBlockchain.RCDaemon.send_to_rcnode("GRID 1 #{btn} #{value}")

        _ ->
          Logger.warning("⚠️ Malformed grid path: #{path}")
      end
    else
      Logger.warning("⚠️ Unhandled OSC msg: #{path} #{inspect([value])}")
    end
  end



  defp route_osc({path, args}) do
    Logger.warning("⚠️  Unhandled OSCListener OSC msg YY: #{path} #{inspect(args)}")
    Logger.warning(inspect(args, label: "args", structs: false, charlists: :as_lists))
  end
end
