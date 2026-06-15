defmodule DigitalBlockchain.MKSTORM do
  use GenServer
  require Logger

  # Callbacks
  @impl true
  def init(state) do
    Logger.info("MKSTORM init")
    {:ok, state}
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

  @impl true
  def handle_call({:query, block}, _from, state) do
    {result, exit_status} =
      System.cmd(
        "mkstorm",
        ["--store",
        System.get_env("MKSTORM_STORE_PATH", "/data"),"--query", block]
      )

    Logger.info("MKSTORM query block=#{block} exit_status=#{exit_status}")

    records =
      result
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case Jason.decode(line) do
          {:ok, json} -> json
          {:error, _} -> %{"raw" => line}
        end
      end)

    {:reply, records, state}
  end

  defp do_ingest(block, long_count, short_count, payload, _from, state) do
    {result, exit_status} =
      System.cmd("mkstorm", [
        "--store",
        System.get_env("MKSTORM_STORE_PATH", "/data"),
        block,
        to_string(long_count),
        to_string(short_count),
        payload
      ])

    Logger.info("MKSTORM block=#{block} payload=#{payload} exit_status=#{exit_status}")

    lines =
      result
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    parsed =
      Enum.reduce(lines, %{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [key, value] ->
            Map.put(acc, String.trim(key), String.trim(value))

          _ ->
            acc
        end
      end)

    record = %{
      originator: Map.get(parsed, "originator"),
      index: Map.get(parsed, "index"),
      long_count: parsed |> Map.get("long_count", "0") |> String.to_integer(),
      short_count: parsed |> Map.get("short_count", "0") |> String.to_integer(),
      payload: Map.get(parsed, "payload")
    }

    {:reply, record, state}
  end

  # Public API
  def query(block) do
    GenServer.call(__MODULE__, {:query, block})
  end
end
