defmodule Tracker.File.Peer.Announce do
  use GenServer

  alias Tracker.File.Statistics
  alias Tracker.File.Peer.State

  defstruct info_hash: nil, trackerid: nil, peer_id: nil, ip: nil, port: nil

  @complete? {:p, :l, {__MODULE__, :complete?}}

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
    state =
      %__MODULE__{
        info_hash: info[:info_hash],
        trackerid: info[:trackerid],
        ip: info[:ip],
        port: info[:port]}
    :gproc.reg(@complete?, false)
    {:ok, state}
  end

  # handle announce
  def handle_call({:announce, %{"event" => "started"} = announce}, _from, state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)
    Statistics.a_peer_started(state.info_hash)
    formatted_ip =
      case announce["ip"] do
        {a, b, c, d} ->
          "#{a}.#{b}.#{c}.#{d}"

        ip when is_binary(ip) ->
          ip
      end
    data = %{ip: formatted_ip, peer_id: announce["peer_id"], port: announce["port"]}
    :gproc.reg({:p, :l, state.info_hash}, data)

    peer_list = get_peers(self(), state.info_hash)
    {:reply, peer_list, state}
  end

  def handle_call({:announce, %{"event" => "completed"} = announce}, _from, state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)
    Statistics.a_peer_completed(state.info_hash)
    :gproc.set_value(@complete?, true)

    peer_list = get_peers(self(), state.info_hash)
    {:reply, peer_list, state}
  end

  def handle_call({:announce, %{"event" => "stopped"}}, _from, state) do
    if :gproc.get_value(@complete?) do
      Statistics.a_completed_peer_stopped(state.info_hash)
    else
      Statistics.an_incomplete_peer_stopped(state.info_hash)
    end

    {:reply, [], state}
  end

  def handle_call({:announce, announce}, _from, state) do
    :ok = State.update(state.info_hash, state.trackerid, announce)

    peer_list = get_peers(self(), state.info_hash)
    {:reply, peer_list, state}
  end

  defp get_peers(pid, info_hash, opts \\ [numwant: 35]) do
    key = {:p, :l, info_hash}
    match = {key, :'$0', :'$1'}
    guard = [{:'=/=', :'$0', pid}] # filter out the calling peer
    format = [:'$1']

    case :gproc.select({:l, :p}, [{match, guard, format}], opts[:numwant]) do
      {peers, _} ->
        cond do
          # opts.compact == true ->
          #   peers
          #   |> Enum.filter_map(&(&1[:compact] != nil), fn %{compact: address} -> address end)
          #   |> to_string

          # opts.no_peer_id == true ->
          #   peers
          #   |> Enum.map(fn %{ip: ip, port: port} -> %{ip: ip, port: port} end)

          :otherwise ->
            peers
            |> Enum.map(&(Map.delete(&1, :compact)))
        end

      :"$end_of_table" ->
        []
    end
  end
end
