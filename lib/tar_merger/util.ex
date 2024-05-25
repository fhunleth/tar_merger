defmodule TarMerger.Util do
  @moduledoc false
  require Logger

  @spec cmd(String.t(), [String.t()]) :: :ok | :error
  def cmd(command, args) do
    Logger.info("Running #{command} #{inspect(args)}")

    case System.cmd(command, args, into: IO.stream()) do
      {_, 0} -> :ok
      _ -> :error
    end
  end
end
