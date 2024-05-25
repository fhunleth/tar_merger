defmodule TarMerger.Util do
  @moduledoc false

  @spec cmd(String.t(), [String.t()]) :: :ok | :error
  def cmd(command, args) do
    case System.cmd(command, args, into: IO.stream()) do
      {_, 0} -> :ok
      _ -> :error
    end
  end
end
