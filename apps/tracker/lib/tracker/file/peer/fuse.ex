defmodule Tracker.File.Peer.Fuse do
  use GenServer

  # Client API
  def start_link(info) do
    GenServer.start_link(__MODULE__, %{}, name: via_name(info[:info_hash], info[:trackerid]))
  end

  defp via_name(info_hash, trackerid),
    do: {:via, :gproc, peer_name(info_hash, trackerid)}
  defp peer_name(info_hash, trackerid),
    do: {:n, :l, {__MODULE__, {info_hash, trackerid}}}

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  # should kill the Tracker.File.Peer with info_hash and trackerid if it hasen't been pinged within a given time
end
