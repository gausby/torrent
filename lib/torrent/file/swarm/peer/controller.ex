defmodule Torrent.File.Swarm.Peer.Controller do
  require Logger

  use GenServer

  alias Torrent.File.Swarm.Peer.Transmitter
  alias __MODULE__, as: State

  defstruct(
    info_hash: nil,
    transmitter: nil,
    address: nil,
    identifier: nil
  )

  # Client API
  def start_link(info_hash, {ip, port}) do
    identifier = "#{Tuple.to_list(ip) |> Enum.join(".")}:#{port}"
    initial_state =
      %State{info_hash: info_hash, address: {ip, port}, identifier: identifier}

    GenServer.start_link(__MODULE__, initial_state, name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  # Server callbacks
  def init(state) do
    send self, :after_init
    {:ok, state}
  end

  def handle_info(:after_init, %State{info_hash: info_hash, address: {ip, port}} = state) do
    {transmitter_pid, _} = :gproc.await({:n, :l, {Transmitter, info_hash, ip, port}}, 300)

    {:noreply, %State{state|transmitter: transmitter_pid}}
  end

  # decode message and dispatch package
  def handle_info({:receive, package}, state) do
    IO.inspect package
    state = handle_package(state, PeerWire.decode_message(package))
    {:noreply, state}
  end

  # react to the incoming messages
  def handle_package(state, :keep_alive) do
    Logger.info "alive", [peer: state.identifier]
    state
  end

  def handle_package(state, :choke) do
    Logger.info "being choked by remote peer", [peer: state.identifier]
    state
  end

  def handle_package(state, :unchoke) do
    Logger.info "stopped getting choked by remote peer", [peer: state.identifier]
    state
  end

  def handle_package(state, :interested) do
    Logger.info "remote is interested", [peer: state.identifier]
    state
  end

  def handle_package(state, :not_interested) do
    Logger.info "remote is not interested", [peer: state.identifier]
    state
  end

  def handle_package(state, {:have, piece}) do
    Logger.info "remote peer has a new piece", [peer: state.identifier, piece: piece]
    state
  end

  def handle_package(state, {:bitfield, bitfield}) do
    Logger.info "remote send its bitfield information", [peer: state.identifier]
    # overwrite local bit field set
    state
  end

  # todo, piece, request, and cancel
  def handle_package(state, package) do
    Logger.warn "Unknown package type: #{inspect package}", [peer: state.identifier]
    state
  end
end
