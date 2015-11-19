defmodule Tracker.File.Peer.State do
  # left
  # downloaded
  # uploaded

  def start_link(trackerid) do
    Agent.start_link(&init/0, name: via_name(trackerid[:info_hash], trackerid[:trackerid]))
  end

  defp via_name(info_hash, trackerid),
    do: {:via, :gproc, peer_name(info_hash, trackerid)}
  defp peer_name(info_hash, trackerid),
    do: {:n, :l, {__MODULE__, {info_hash, trackerid}}}

  def init do
    %{}
  end
end
