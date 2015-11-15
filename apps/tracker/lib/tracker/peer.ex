defmodule Tracker.Peer do
  use GenServer
  require Logger
  import UUID, only: [uuid4: 0]

  @announce_timeout :infinity

  # Client API
  def start_link(peer) do
    GenServer.start_link(__MODULE__, peer, name: via_name(peer))
  end

  defp via_name(peer) do
    {:via, :gproc, peer_name(peer)}
  end

  defp peer_name(%{:trackerid => trackerid,
                   :info_hash => <<info_hash::binary-size(20)>>}) do
    {:n, :l, {Tracker.Peer, trackerid, info_hash}}
  end

  def create(%{info_hash: _info_hash} = torrent) do
    trackerid = uuid4
    torrent = Map.put(torrent, :trackerid, trackerid)
    key = peer_name(torrent)

    # todo, could die
    {:ok, pid} = Supervisor.start_child(Tracker.Peer.Supervisor, [torrent])
    # todo, could time out
    :gproc.await(key, 2000)

    {:ok, pid, trackerid}
  end

  def stop(pid) do
    GenServer.call(pid, :terminate)
  end

  def announce(pid, status) do
    GenServer.cast(pid, {:announce, status})
  end

  def complete?(pid) do
    GenServer.call(pid, :complete?)
  end

  def get_peers(pid, opts \\ %{}) do
    defaults = %{no_peer_id: false, numwant: 35, compact: false}
    GenServer.call(pid, {:get_peers, Map.merge(defaults, opts)})
  end

  # Server callbacks
  def init(%{info_hash: info_hash, trackerid: trackerid} = opts) do
    Logger.info "#{trackerid} is registering with #{info_hash}"
    state = %Tracker.Peer.State{
      info_hash: info_hash,
      trackerid: trackerid,
      #key: opts.key,
      peer_id: opts.peer_id,
      ip: opts.ip,
      port: opts.port,
      downloaded: 0,
      uploaded: 0,
      left: 0,
      complete: false
    }

    # ip and port notes {ip, port}
    # ip4_address() = {0..255, 0..255, 0..255, 0..255}
    # ip6_address() = {0..65535, 0..65535, 0..65535, 0..65535,
    #                  0..65535, 0..65535, 0..65535, 0..65535}
    # port() = 0..65535
    formatted_ip =
      case state.ip do
        {a, b, c, d} ->
          "#{a}.#{b}.#{c}.#{d}"

        ip when is_binary(ip) ->
          ip
      end
    status = if state.complete, do: :complete, else: :incomplete
    compact = case state.ip do
      {a, b, c, d} ->
        <<a, b, c, d, state.port::size(16)>>

      _ ->
        nil
    end
    data = %{ip: formatted_ip, peer_id: state.peer_id, port: state.port, compact: compact}
    :gproc.reg({:p, :l, info_hash}, {status, data})

    # Optionally, if the peer specifies an identifier key, this can be
    # used to change the ip and port information later.
    if state.key, do: :gproc.reg({:p, :l, state.key})

    {:ok, state}
  end

  # info
  def handle_info(:timeout, state) do
    Logger.info "#{state.trackerid} (tracking #{state.info_hash}) timed out"
    # kill if the peer has not announced within a given time
    {:noreply, state}
  end

  # cast
  def handle_cast({:announce, %{event: "started"} = status}, state) do
    Logger.info "#{state.trackerid} is now tracking #{state.info_hash}"
    tracker_pid = :gproc.where({:n, :l, {Tracker.Torrent, state.info_hash}})
    :gproc.update_counter({:c, :l, :incomplete}, tracker_pid, 1)

    {:noreply, update_state(state, status), @announce_timeout}
  end
  def handle_cast({:announce, %{event: nil} = status}, state) do
    Logger.info "#{state.trackerid} announced to #{state.info_hash}"
    {:noreply, update_state(state, status), @announce_timeout}
  end
  def handle_cast({:announce, %{event: "completed"} = status}, state) do
    Logger.info "#{state.trackerid} marked #{state.info_hash} as completed"

    status_key = {:p, :l, state.info_hash}
    status_update = put_elem(:gproc.get_value(status_key), 0, :complete)
    :gproc.set_value(status_key, status_update)

    tracker_pid = :gproc.where({:n, :l, {Tracker.Torrent, state.info_hash}})
    :gproc.update_counter({:c, :l, :incomplete}, tracker_pid, -1)
    :gproc.update_counter({:c, :l, :complete}, tracker_pid, 1)
    :gproc.update_counter({:c, :l, :downloads}, tracker_pid, 1)

    {:noreply, update_state(state, status), @announce_timeout}
  end
  def handle_cast({:announce, %{event: "stopped"} = status}, %{complete: true} = state) do
    Logger.info "#{state.trackerid} stopped tracking #{state.info_hash}"
    tracker_pid = :gproc.where({:n, :l, {Tracker.Torrent, state.info_hash}})
    :gproc.update_counter({:c, :l, :complete}, tracker_pid, -1)
    final_state = update_state(state, status)
    {:stop, :normal, final_state}
  end
  def handle_cast({:announce, %{event: "stopped"} = status}, state) do
    Logger.info "#{state.trackerid} stopped tracking #{state.info_hash}"
    tracker_pid = :gproc.where({:n, :l, {Tracker.Torrent, state.info_hash}})
    :gproc.update_counter({:c, :l, :incomplete}, tracker_pid, -1)
    final_state = update_state(state, status)
    {:stop, :normal, final_state}
  end

  # call
  def handle_call({:get_peers, %{numwant: 0}}, _from, state),
    do: {:reply, [], state}
  def handle_call({:get_peers, req}, _from, state) do
    # completed peers should not get seeders, only incomplete peers
    interest = if state.complete, do: :incomplete, else: :'_'

    key = {:p, :l, state.info_hash}
    match = {key, :'$0', {interest, :'$1'}}
    guard = [{:'=/=', :'$0', self()}] # filter out the calling peer
    format = [:'$1']
    peers =
      case :gproc.select({:l, :p}, [{match, guard, format}], req.numwant) do
        {peers, _} ->
          cond do
            req.compact == true ->
              peers
              |> Enum.filter_map(&(&1[:compact] != nil), fn %{compact: address} -> address end)
              |> to_string

            req.no_peer_id == true ->
              peers
              |> Enum.map(fn %{ip: ip, port: port} -> %{ip: ip, port: port} end)

            :otherwise ->
              peers
              |> Enum.map(&(Map.delete(&1, :compact)))
          end

        :"$end_of_table" ->
          []
      end

    {:reply, peers, state}
  end

  def handle_call(:complete?, _from, state) do
    {:reply, state.complete, state}
  end

  def handle_call(:terminate, _from, state) do
    Logger.info "#{state.trackerid} is terminating"
    :gproc.goodbye()
    {:stop, :normal, state, state}
  end

  # helpers
  defp update_state(state, status) do
    %Tracker.Peer.State{
      state |
      complete: state.complete || status.event == "completed",
      uploaded: status.uploaded,
      downloaded: status.downloaded,
      left: status.left
    }
  end
end
