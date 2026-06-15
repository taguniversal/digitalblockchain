defmodule DigitalBlockchain.MKSTORM do
  use GenServer
  require Logger
  @mkstorm_storage_path "/tmp/mkstorm"
  # Callbacks
  @impl true
  def init(_state) do
    Logger.info("MKSTORM init")
    {:ok, %{records: []}}
  end

  @impl true
  def handle_call({:ingest, block, long_count, short_count, payload}, from, state) do
    do_ingest(block, long_count, short_count, payload, from, state)
  end

  @impl true
  def handle_call(block, long_count, short_count, payload, from, state) when is_binary(payload) do
    do_ingest(block, long_count, short_count, payload, from, state)
  end

  # Public API
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def ingest(block, long_count, short_count, payload) do
    GenServer.call(__MODULE__, {:ingest, block, long_count, short_count, payload})
  end

  defp store_path do
    System.get_env("MKSTORM_STORE_PATH", @mkstorm_storage_path)
  end

  @impl true
  def handle_call({:query, block}, _from, state) do
    records =
      state.records
      |> Enum.filter(fn record ->
        record["psi"] == block or record["index"] == block
      end)
      |> Enum.reverse()

    {:reply, records, state}
  end

  defp do_ingest(block, long_count, short_count, payload, _from, state) do
    record = %{
      "originator" => "local",
      "psi" => block,
      "index" => block,
      "long_count" => long_count,
      "short_count" => short_count,
      "payload" => payload
    }

    args = [
      "--store",
      store_path(),
      block,
      to_string(long_count),
      to_string(short_count),
      payload
    ]

    Logger.info("MKSTORM ingest args=#{inspect(args)}")

    {result, exit_status} =
      System.cmd("mkstorm", args, stderr_to_stdout: true)

    Logger.info("MKSTORM ingest result=#{inspect(result)} exit_status=#{exit_status}")

    new_state = %{state | records: [record | state.records]}

    {:reply, record, new_state}
  end

  # Public API
  def query(block) do
    GenServer.call(__MODULE__, {:query, block})
  end
end
