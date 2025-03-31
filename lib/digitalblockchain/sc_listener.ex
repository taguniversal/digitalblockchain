defmodule DigitalBlockchain.SCListener do
  use GenServer
  require Logger

  @port 9020  # Different port for SC, adjust as needed

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true, reuseaddr: true])
    Logger.info("🎚️  SuperCollider OSC Listener started on port #{@port}")
    {:ok, Map.put(state, :socket, socket)}
  end

  def handle_info({:udp, _socket, ip, port, data}, state) do
    case OSCx.decode(data) do
      %OSCx.Message{address: path, arguments: args} ->
        Logger.debug("🔊 SC OSC #{path} #{inspect(args)} from #{:inet.ntoa(ip)}:#{port}")
        route_osc({path, args})

      _ ->
        Logger.warn("⚠️ Unhandled SC OSC data: #{inspect(data)}")
    end

    {:noreply, state}
  end


  defp route_osc({"/sc/heartbeat", [timestamp]}) do
    readable =
      case timestamp do
        val when is_binary(val) -> val
        val when is_list(val) -> to_string(val)
        _ -> inspect(timestamp)
      end

    Logger.info("💓 SC heartbeat at #{readable}")
  end


  # Example route handling
  defp route_osc({"/sc/ready", []}) do
    Logger.info("✅ SuperCollider reports ready.")
    # You could notify a process or change a state flag here
  end

  defp route_osc({"/sc/ack", [id]}) do
    Logger.info("📩 SuperCollider acknowledged message with ID: #{id}")
  end

  defp route_osc({"/sc/level", [db]}) do
    Logger.info("📈 Audio level reported: #{db} dB")
  end

  defp route_osc({path, args}) do
    Logger.warning("⚠️  Unhandled SC OSC msg: #{path} #{inspect(args)}")
  end
end
