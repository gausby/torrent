defmodule Torrent.PeerDiscovery do
  use Supervisor

  @moduledoc """
  Peer discovery handler.

  Design goals:

    - Should emit peers found on trackers and distributed hash
      tables to the torrent processes
    - Should implement a plugin architecture allowing different
      peer discovery strategies, such as DHTs, HTTP Trackers,
      etc
    - Should be able to start, stop, pause, and resume a given
      discoverer
    - Should have a timeout between requests to trackers
  """

  def start_link(peer_id) do
    Supervisor.start_link(__MODULE__, peer_id, name: via_name(peer_id))
  end

  defp via_name(peer_id),
    do: {:via, :gproc, peer_discovery_name(peer_id)}
  defp peer_discovery_name(peer_id),
    do: {:n, :l, {__MODULE__, peer_id}}

  def init(peer_id) do
    children = [
      worker(Torrent.PeerDiscovery.Server, [peer_id])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(peer_id, info_hash) do
    case :gproc.where(peer_discovery_name(peer_id)) do
      :undefined ->
        {:error, :unknown_peer_discovery}

      pid when is_pid(pid) ->
        Supervisor.start_child(pid, [info_hash])
    end
  end
end
