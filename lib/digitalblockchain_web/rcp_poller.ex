defmodule Digitalblockchain.RCPoller do
  def poll do
    port =
      Port.open({:spawn_executable, rc_path()}, [
        {:args, ["--poll"]},
        :binary,
        :exit_status,
        :stderr_to_stdout
      ])

    receive_response(port, "")
  end

  defp receive_response(port, acc) do
    receive do
      {^port, {:data, data}} ->
        receive_response(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, code}} ->
        {:error, %{code: code, output: acc}}

    after
      5_000 -> {:error, :timeout}
    end
  end

  defp rc_path do
    System.find_executable("rc") || "/app/bin/rc"
  end
end
