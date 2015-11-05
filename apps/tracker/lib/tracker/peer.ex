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

    # Optionally, if the peer specifies an identifier key, this can be
    # used to change the ip and port information later.
    if state.key, do: :gproc.reg(:p, :l, state.key)

    {:ok, state}
  end

  # info
  def handle_info(:timeout, state) do
    Logger.info "#{state.trackerid} (tracking #{state.info_hash}) timed out"
    # kill if the peer has not announced within a given time
    {:noreply, state}
  end

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
