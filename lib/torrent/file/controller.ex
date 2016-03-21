defmodule Torrent.File.Controller do
  use GenServer

  @moduledoc """
  Process level controller. Should react to events send from the peer controllers.
  """

  # Client API
  def start_link(peer_id, info_hash, meta) do
    GenServer.start_link(__MODULE__, {peer_id, info_hash, meta}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, controller_name(info_hash)}
  defp controller_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  # Server callbacks
  def init({peer_id, info_hash, _} = state) do
    Torrent.PeerDiscovery.add(peer_id, info_hash)
    {:ok, state}
  end
end
