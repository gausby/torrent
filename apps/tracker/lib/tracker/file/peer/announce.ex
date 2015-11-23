defmodule Tracker.File.Peer.Announce do
  use GenServer

  alias Tracker.File.Statistics
  alias Tracker.File.Peer.State

  defstruct(
    info_hash: nil,
    trackerid: nil,
    peer_id: nil,
    ip: nil,
    port: nil,
    status: :incomplete
  )

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
  def init([info_hash: info_hash, trackerid: trackerid]) do
    state = %__MODULE__{info_hash: info_hash, trackerid: trackerid}
    :gproc.reg({:p, :l, {__MODULE__, state.info_hash}}, nil)
    {:ok, state}
  end

  # handle announce
  def handle_call({:announce, %{"event" => "started"} = announce}, _from, state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)
    state = update_announce_state(state, announce)

    Statistics.a_peer_started(state.info_hash)
    set_peer_meta_data(state)

    peer_list = get_peers(self(), state, announce)
    {:reply, peer_list, state}
  end

  def handle_call({:announce, %{"event" => "completed"} = announce}, _from, %{status: :incomplete} = state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)
    state = update_announce_state(state, announce)

    Statistics.a_peer_completed(state.info_hash)

    set_peer_meta_data(state)

    peer_list = get_peers(self(), state, announce)
    {:reply, peer_list, state}
  end

  def handle_call({:announce, %{"event" => "stopped"}}, _from, %{status: :complete} = state) do
    Statistics.a_completed_peer_stopped(state.info_hash)
    {:reply, [], state}
  end
  def handle_call({:announce, %{"event" => "stopped"}}, _from, %{status: :incomplete} = state) do
    Statistics.an_incomplete_peer_stopped(state.info_hash)
    {:reply, [], state}
  end

  def handle_call({:announce, announce}, _from, state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)
    state = update_announce_state(state, announce)

    peer_list = get_peers(self(), state, announce)
    {:reply, peer_list, state}
  end

  #=HELPERS=============================================================
  defp update_announce_state(state, announce) do
    # info_hash + trackerid + peer_id should newer change
    # key should be used and match if ip/port changes
    state
    |> update_announce_ip(announce)
    |> update_announce_port(announce)
    |> update_announce_peer_id(announce)
    |> update_announce_status(announce)
  end

  # todo: update ip (if announce.key = state.key)
  defp update_announce_ip(%__MODULE__{ip: old} = state, %{"ip" => new}) when old != new,
    do: Map.put(state, :ip, new)
  defp update_announce_ip(state, _),
    do: state

  # todo: update port (if announce.key = state.key)
  defp update_announce_port(%__MODULE__{ip: old} = state, %{"port" => new}) when old != new,
    do: Map.put(state, :port, new)
  defp update_announce_port(state, _),
    do: state

  defp update_announce_status(%__MODULE__{status: :incomplete} = state, %{"event" => "completed"}),
    do: Map.put(state, :status, :complete)
  defp update_announce_status(state, _),
    do: state

  defp update_announce_peer_id(%__MODULE__{peer_id: old} = state, %{"peer_id" => new}) when old != new,
    do: Map.put(state, :peer_id, new)
  defp update_announce_peer_id(state, _),
    do: state

  defp set_peer_meta_data(state) do
    formatted_ip =
      case state.ip do
        {a, b, c, d} ->
          "#{a}.#{b}.#{c}.#{d}"

        ip when is_binary(ip) ->
          ip
      end

    data = %{ip: formatted_ip, peer_id: state.peer_id, port: state.port}

    :gproc.set_value({:p, :l, {__MODULE__, state.info_hash}}, {state.status, data})
  end

  defp get_peers(pid, state, announce) do
    # completed peers should get a list of incomplete back (no seeders for seeders)
    interest = if state.status, do: :incomplete, else: :'_'

    key = {:p, :l, {__MODULE__, state.info_hash}}
    match = {key, :'$0', {interest, :'$1'}}
    guard = [{:'=/=', :'$0', pid}] # filter out the calling peer
    format = [:'$1']

    numwant = announce["numwant"] || 35
    case :gproc.select({:l, :p}, [{match, guard, format}], numwant) do
      {peers, _} ->
        cond do
          # opts.compact == true ->
          #   peers
          #   |> Enum.filter_map(&(&1[:compact] != nil), fn %{compact: address} -> address end)
          #   |> to_string

          announce["no_peer_id"] == 1 ->
            peers
            |> Enum.map(fn %{ip: ip, port: port} -> %{ip: ip, port: port} end)

          :otherwise ->
            peers
            |> Enum.map(&(Map.delete(&1, :compact)))
        end

      :"$end_of_table" ->
        []
    end
  end
end
