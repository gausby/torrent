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
    status: :incomplete,
    key: nil
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
    state
    |> update_announce_key(announce)
    |> update_announce_ip(announce)
    |> update_announce_port(announce)
    |> update_announce_peer_id(announce)
    |> update_announce_status(announce)
  end

  defp update_announce_key(state, %{"event" => "started", "key" => key}),
    do: Map.put(state, :key, key)
  defp update_announce_key(state, _),
    do: state

  defp update_announce_ip(state, %{"event" => "started", "ip" => ip}),
    do: Map.put(state, :ip, ip)
  defp update_announce_ip(%__MODULE__{ip: old, key: key} = state, %{"ip" => new, "key" => key}) when old != new,
    # only update ip if key is given and matches the one set at the beginning
    do: Map.put(state, :ip, new)
  defp update_announce_ip(state, _),
    do: state

  defp update_announce_port(state, %{"event" => "started", "port" => port}),
    do: Map.put(state, :port, port)
  defp update_announce_port(%__MODULE__{ip: old, key: key} = state, %{"port" => new, "key" => key}) when old != new,
    # only update port if key is given and matches the one set at the beginning
    do: Map.put(state, :port, new)
  defp update_announce_port(state, _),
    do: state

  # after the status has been set to complete it can never go back
  defp update_announce_status(%__MODULE__{status: :incomplete} = state, %{"event" => "completed"}),
    do: Map.put(state, :status, :complete)
  defp update_announce_status(state, _),
    do: state

  # peer_id should only be set once
  defp update_announce_peer_id(%__MODULE__{peer_id: nil} = state, %{"peer_id" => peer_id}),
    do: Map.put(state, :peer_id, peer_id)
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

    # can only make compact versions of ipv4 addresses
    compact = case state.ip do
      {a, b, c, d} ->
        <<a, b, c, d, state.port::size(16)>>

      _ ->
        nil
    end

    data = %{ip: formatted_ip, peer_id: state.peer_id, port: state.port}

    :gproc.set_value({:p, :l, {__MODULE__, state.info_hash}}, {state.status, data, compact})
  end

  defp get_peers(_pid, _state, %{"numwant" => 0} = announce) do
    if announce["compact"] == 1, do: "", else: []
  end
  defp get_peers(pid, state, %{"compact" => 1} = announce) do
    # completed peers should get a list of incomplete back (no seeders for seeders)
    interest = if state.status, do: :incomplete, else: :'_'

    key = {:p, :l, {__MODULE__, state.info_hash}}
    match = {key, :'$0', {interest, :'_', :'$1'}}
    # Filter out the calling peer and peers that does not support compact
    # by checking here we should uphold the numwant number
    guard = [{:'andalso', {:'=/=', :'$0', pid}, {:'=/=', :'$1', nil}}]
    format = [:'$1']

    numwant = announce["numwant"] || 35

    case :gproc.select({:l, :p}, [{match, guard, format}], numwant) do
      {peers, _} ->
        peers
        |> Enum.filter(&(&1))
        |> to_string

      :"$end_of_table" ->
        []
    end
  end
  defp get_peers(pid, state, announce) do
    # completed peers should get a list of incomplete back (no seeders for seeders)
    interest = if state.status, do: :incomplete, else: :'_'

    key = {:p, :l, {__MODULE__, state.info_hash}}
    match = {key, :'$0', {interest, :'$1', :'_'}}
    guard = [{:'=/=', :'$0', pid}] # filter out the calling peer
    format = [:'$1']

    numwant = announce["numwant"] || 35
    case :gproc.select({:l, :p}, [{match, guard, format}], numwant) do
      {peers, _} ->
        cond do
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
