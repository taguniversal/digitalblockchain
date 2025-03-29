defmodule DigitalBlockchain.RC do
  use GenServer
  require Logger
  @moduledoc """
  GenServer wrapper for interacting with the `rc` (Reality Compiler) binary.
  """

  ## Public API

  def start_link(opts \\ []) do
    Logger.info("RC starting")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send a command or source file to the RC compiler.
  """
  def compile(source) do
    GenServer.call(__MODULE__, {:compile, source})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{rc_path: "rc"}}  # Update this path when you know where rc will live
  end

  @impl true
  def handle_call({:compile, source}, _from, state) do
    # Placeholder for future execution logic
    result = {:ok, "Would run RC on: #{source}"}
    {:reply, result, state}
  end
end
