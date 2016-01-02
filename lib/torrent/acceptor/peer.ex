defmodule Torrent.Acceptor.Peer do
  use GenServer

  require Logger

  alias :gen_tcp, as: TCP

  defstruct socket: nil, peer_id: nil
  alias Torrent.Acceptor.Peer, as: State

  # Client API
  def start_link(accept_socket, peer_id) do
    GenServer.start_link(__MODULE__, [accept_socket, peer_id])
  end

  # Server callbacks
  def init([accept_socket, peer_id]) do
    GenServer.cast(self(), :accept)
    {:ok, %State{socket: accept_socket, peer_id: peer_id}}
  end

  # accept a connection and start a new acceptor
  def handle_cast(:accept, %State{socket: accept_socket, peer_id: peer_id} = state) do
    case TCP.accept(accept_socket) do
      {:ok, socket} ->
        handle_handshake(socket, state)
        |> handle_handshake_result

      _ = message ->
        IO.inspect {:failure_accepting_connection, message}
    end
    {:ok, _pid} = Torrent.Acceptor.start_socket(peer_id)
    {:stop, :normal, state}
  end

  defp handle_handshake(socket, state) do
    # todo, make somekind of throttler so we don't connect to the entire world.
    # thirty-five connected peers should be enough according to the specs.
    with(
      {:ok, {ip, port}} <- :inet.peername(socket),
      {:ok, info_hash, peer_id} <- PeerWire.receive_handshake(socket),
      :ok <- integrity_check(%{peer_id: peer_id, ip: ip, port: port, info_hash: info_hash}, state),
      # spawn a process and complete the handshake
      {:ok, pid} <- Torrent.File.Swarm.start_child(info_hash, {ip, port}),
      :ok <- Torrent.File.Swarm.Peer.forward_socket(info_hash, {ip, port}, socket),
      :ok <- PeerWire.complete_handshake(socket, info_hash, peer_id),
      do: :ok
    )
  end

  defp integrity_check(remote, state) do
    with(
      :ok <- check_info_hash(remote[:info_hash]),
      :ok <- check_peer_id(remote[:peer_id], state.peer_id),
      :ok <- check_ip_and_port({remote[:ip], remote[:port]}),
      # check if ip and port is on the naughty-list
      do: :ok
    )
  end

  defp check_info_hash(info_hash) do
    case :gproc.where({:n, :l, {Torrent.File, info_hash}}) do
      :undefined ->
        {:error, "unknown info_hash"}

      _pid ->
        :ok
    end
  end

  defp check_peer_id(same, same),
    do: {:error, "connecting to self"}
  defp check_peer_id(_, _),
    do: :ok

  defp check_ip_and_port(_addr) do
    :ok
  end

  # Handshake result ===================================================
  defp handle_handshake_result(:ok) do
    :ok
  end
  defp handle_handshake_result({:error, _reason} = error) do
    Logger.info "#{inspect error}"
  end
end
