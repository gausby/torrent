defmodule Tracker.Torrent do
  use GenServer

  # Client API
  def create(data) do
    # should be able to handle data from torrent files and urn's
    case Supervisor.start_child(Tracker.Torrent.Supervisor, [data]) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
  end

  def start_link(%{info_hash: info_hash} = metainfo) do
    GenServer.start_link(__MODULE__, metainfo, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, torrent_name(info_hash)}

  defp torrent_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def stop(pid) do
    GenServer.call(pid, :terminate)
  end

  def add_peer(pid, peer) do
    GenServer.call(pid, {:add_peer, peer})
  end

  def list_all_peers(info_hash) do
    match = {{:n, :l, {Tracker.Peer, :'_', info_hash}}, :'$1', :'_'}
    :gproc.select([{match, [], [:'$1']}])
  end

  def get_statistics(pid, info_hash) do
    {info_hash,
     %{incomplete: :gproc.get_value({:c, :l, :incomplete}, pid),
       complete: :gproc.get_value({:c, :l, :complete}, pid),
       downloads: :gproc.get_value({:c, :l, :downloads}, pid)}}
  end

  # Server callbacks
  def init(metainfo) do
    send self, {:register, metainfo}
    {:ok, nil}
  end

  def handle_info({:register, state}, nil) do
    # rebuild state from possibly existing peers
    {complete, incomplete} =
      list_all_peers(state.info_hash)
      |> Enum.partition(&(Tracker.Peer.complete?(&1)))

    # peers downloading, "leeching"
    :gproc.reg({:c, :l, :incomplete}, length(incomplete))

    # peers marked as done, "seeders"
    :gproc.reg({:c, :l, :complete}, length(complete))

    # completed downloads since beginning of time
    :gproc.reg({:c, :l, :downloads}, 0)

    {:noreply, state}
  end

  def handle_call({:add_peer, data}, _from, state) do
    case Tracker.Peer.create(data) do
      {:ok, pid, _trackerid} = result ->
        Tracker.Peer.announce(pid, data)
        {:reply, result, state}
      _ ->
        {:reply, {:error, "failed initializing peer"}, state}
    end
  end

  def handle_call(:terminate, _from, state) do
    :gproc.goodbye()
    for peer_id <- list_all_peers(state.info_hash) do
      Tracker.Peer.stop(peer_id)
    end

    {:stop, :normal, state, state}
  end
end
