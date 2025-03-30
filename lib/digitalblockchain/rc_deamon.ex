defmodule DigitalBlockchain.RCDaemon do
  use GenServer
  require Logger

  @rc_ip {127, 0, 0, 1}
  @rc_port 9000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Launch rc binary (daemon mode)
    project_root =
      :code.priv_dir(:digitalblockchain)
      |> to_string()
      |> Path.dirname()
      |> Path.dirname()

    state_path = Path.join(project_root, "state")
    inv_path = Path.join(project_root, "inv")

    rc_path = System.find_executable("digitalblockchain") || "/usr/local/bin/digitalblockchain"

    Logger.info("Starting digitalblockchain daemon at #{rc_path}")
    Logger.info("With --state #{state_path} and --inv #{inv_path}")

    Port.open({:spawn_executable, rc_path}, [
      :binary,
      :exit_status,
      :hide,
      args: ["--daemon", "--state", state_path, "--inv", inv_path]
    ])

    # Start OSC client
    {:ok, client} = ExOSC.Client.start_link(ip: @rc_ip, port: @rc_port)

    # Schedule polling
    :timer.send_interval(500, :poll)

    {:ok, %{osc_client: client}}
  end

  def handle_info(:poll, %{osc_client: client} = state) do
    msg = %OSC.Message{path: "/poll", args: []}
    Logger.info("Pollingy.")
    :ok = ExOSC.Client.send_message(client, msg)
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    Logger.info("digitalblockchain daemon exited cleanly.")
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.error("digitalblockchain daemon exited with code #{code}")
    {:stop, {:daemon_exit, code}, state}
  end
end
