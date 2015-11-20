defmodule Tracker.File.Peer.Announce do
  use GenServer

  defstruct info_hash: nil, left: nil, downloaded: nil, uploaded: nil

  @statistics Tracker.File.Statistics
  @complete? {:p, :l, {__MODULE__, :complete}}

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
  def init(info) do
    state = %__MODULE__{info_hash: info[:info_hash]}
    :gproc.reg(@complete?, false)
    {:ok, state}
  end

  # handle announce
  def handle_call({:announce, %{"event" => "started"}}, _from, state) do
    @statistics.a_peer_started(state.info_hash)
    {:reply, state, state}
  end

  def handle_call({:announce, %{"event" => "completed"}}, _from, state) do
    @statistics.a_peer_completed(state.info_hash)
    :gproc.set_value(@complete?, true)
    {:reply, state, state}
  end

  def handle_call({:announce, %{"event" => "stopped"}}, _from, state) do
    if :gproc.get_value(@complete?) do
      @statistics.a_completed_peer_stopped(state.info_hash)
    else
      @statistics.an_incomplete_peer_stopped(state.info_hash)
    end

    {:reply, state, state}
  end

  def handle_call({:announce, _}, _from, state) do
    {:reply, state, state}
  end

end
