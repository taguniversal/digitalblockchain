defmodule DigitalblockchainWeb.MetricsController do
  use DigitalblockchainWeb, :controller
  require Logger

  def index(conn, _params) do
    tmpfile = "/tmp/rc_poll_output.json"
    rc_path =  rc_path() #System.find_executable("rc") || "/usr/local/bin/rc"
    Logger.info("Runing rc at #{rc_path}")
    # Execute rc and redirect output
    {_, exit_code} = System.cmd(rc_path, ["--poll"], stderr_to_stdout: false, into: File.stream!(tmpfile))
    Logger.info("Exit code: #{exit_code}")
    if exit_code == 0 do
      case File.read(tmpfile) do
        {:ok, json} ->
          case Jason.decode(json) do
            {:ok, decoded} -> json(conn, decoded)
            {:error, _} -> json(conn, %{error: "Failed to decode JSON", raw: json})
          end

        {:error, reason} ->
          json(conn, %{error: "Failed to read file", reason: inspect(reason)})
      end
    else
      json(conn, %{error: "rc --poll failed", code: exit_code})
    end
  end

  defp rc_path do
    # Direct path to avoid symlink weirdness
    "/Users/eflores/src/rc/build/rc"
  end


end
