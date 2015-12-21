defmodule Swarm.Info do
  def start_link(info_hash) do
    Agent.start_link(&init/0, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  defp init do
    %{}
  end
end
