defmodule Torrent.PeerDiscovery.Server do
  use GenServer

  @moduledoc """
  Handle communication with a remote tracker.
  """

  # Client API
  def start_link(peer_id, info_hash) do
    GenServer.start_link(__MODULE__, {peer_id, info_hash}, name: via_name(peer_id, info_hash))
  end

  defp via_name(peer_id, info_hash),
    do: {:via, :gproc, discovery_server_name(peer_id, info_hash)}
  defp discovery_server_name(peer_id, info_hash),
    do: {:n, :l, {__MODULE__, peer_id, info_hash}}

  # Server callbacks
  def init(state) do
    {:ok, state}
  end
end
