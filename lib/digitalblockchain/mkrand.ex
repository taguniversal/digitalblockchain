defmodule DigitalBlockchain.MKRAND do
  use GenServer
  require Logger

  # Callbacks
  @impl true
  def init(seed) do
    Logger.info("MKRAND init")
    {:ok, seed}
  end

  @impl true
  def handle_call(:rand, _from, _seed) do
    {result, exit_status} = System.cmd("mkrand", ["-f8"])
    result = String.trim(result)
    Logger.info("System call result: #{result}, exit_Status: #{exit_status}")
    {:reply, result, 0}
  end

  def handle_call({:block, seed, num_blocks}, _from, _state) do
    {result, exit_status} = System.cmd("mkrand", ["-f8", "-n#{num_blocks}", "-s#{seed}"])

    Logger.info(
      "System call with seed #{seed} and num_blocks #{num_blocks}: #{result}, exitSttus: #{exit_status}"
    )

    result = String.split(result, "\n")
    result = Enum.map(result, &String.trim/1)
    result = Enum.reject(result, fn x -> String.length(x) < 38 end)

    for r <- result do
      Logger.info(">#{r}")
    end

    Logger.info("MKRAND generated #{Enum.count(result)} blocks")
    {:reply, result, 0}
  end

  # Public API
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
