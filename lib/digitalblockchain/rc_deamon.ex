defmodule DigitalBlockchain.RCDaemon do
  use GenServer
  require Logger
  alias OSCx.Message

  @rc_ip {127, 0, 0, 1}
  @rc_port 9000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Determine project directories
    project_root =
      :code.priv_dir(:digitalblockchain)
      |> to_string()
      |> Path.dirname()
      |> Path.dirname()

    state_path = Path.join(project_root, "state")
    inv_path = Path.join(project_root, "inv")
    rc_executable = Application.get_env(:digitalblockchain, :rc_executable)
    rc_path = System.find_executable(rc_executable) || "/usr/local/bin/#{rc_executable}"

    Logger.info("🚀 Starting rcnode daemon at #{rc_path}")
    Logger.info("📁 Using --state #{state_path} and --inv #{inv_path}")

    # Start the rcnode binary
    Port.open({:spawn_executable, rc_path}, [
      :binary,
      :exit_status,
      :hide,
      args: ["--daemon", "--state", state_path, "--inv", inv_path]
    ])

    # Open UDP socket to rcnode
    {:ok, socket} = :gen_udp.open(0, [:binary])
    :timer.send_interval(500, :poll)

    {:ok, %{osc_socket: socket}}
  end

  def handle_info(:poll, %{osc_socket: socket} = state) do
    msg = Message.new(address: "/poll", arguments: [])
    binary = OSCx.encode(msg)
    :ok = :gen_udp.send(socket, @rc_ip, @rc_port, binary)
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    Logger.info("🟢 rcnode daemon exited cleanly.")
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.error("🔴 rcnode daemon exited with code #{code}")
    {:stop, {:daemon_exit, code}, state}
  end

  def send_to_rcnode(cmd) do
    GenServer.cast(__MODULE__, {:send_cmd, cmd})
  end

  def handle_cast({:send_cmd, cmd}, %{osc_socket: socket} = state) do
    msg = Message.new(address: "/cmd", arguments: [cmd])
    binary = OSCx.encode(msg)
    :ok = :gen_udp.send(socket, @rc_ip, @rc_port, binary)
    {:noreply, state}
  end
end
