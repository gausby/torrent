defmodule Torrent.File.Swarm.Peer.Pieces do
  def start_link(info_hash, {ip, port}) do
    Agent.start_link(initial_value(info_hash), name: via_name(info_hash, ip, port))
  end

  defp initial_value(info_hash) do
    fn -> BitFieldSet.new(64, info_hash) end
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}
end
