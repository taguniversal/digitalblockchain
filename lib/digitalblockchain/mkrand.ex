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
    seed =
      DateTime.utc_now()
      |> DateTime.to_iso8601()

    {result, exit_status} =
      System.cmd(
        "mkrand",
        ["--format", "psi", "--seed", seed]
      )

    result = String.trim(result)

    Logger.info("MKRAND seed=#{seed} result=#{result} exit_status=#{exit_status}")

    {:reply, result, 0}
  end

  def handle_call({:block, seed, num_blocks}, _from, _state) do
    {result, exit_status} = System.cmd("mkrand", ["--format", "psi", "-n","#{num_blocks}", "-s","#{seed}"])

    Logger.info(
      "System call with seed #{seed} and blocks #{num_blocks}: #{result}, exitSttus: #{exit_status}"
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
