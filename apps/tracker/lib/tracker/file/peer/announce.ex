defmodule Tracker.File.Peer.Announce do
  use GenServer
  @statistics Tracker.File.Statistics

  # Client API
  def start_link(info) do
    GenServer.start_link(__MODULE__, info, name: via_name(info[:info_hash], info[:trackerid]))
  end

  defp via_name(info_hash, trackerid),
    do: {:via, :gproc, peer_name(info_hash, trackerid)}
  defp peer_name(info_hash, trackerid),
    do: {:n, :l, {__MODULE__, {info_hash, trackerid}}}

  def announce(info_hash, trackerid, data) do
    GenServer.call(via_name(info_hash, trackerid), {:announce, data})
  end

  # Server callbacks
  def init(state) do
    @statistics.increment_incomplete(state[:info_hash])
    {:ok, state}
  end

  # handle announce
  def handle_call({:announce, _data}, _from, state) do
    @statistics.a_peer_completed(state[:info_hash])
    {:reply, state, state}
  end
end
