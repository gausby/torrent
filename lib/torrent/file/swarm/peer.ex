defmodule Torrent.File.Swarm.Peer do
  use Supervisor

  @moduledoc """
  A supervisor that hold the processes belonging to a remote.

  - **Pieces** is an agent storing information about which pieces the
    remote has and which pieces it does not
  - **Receiver** handles inbound data from the remote.
  - **Transmitter** handle outbound communication, capable of
    communicating using the peer-wire protocol
  - **Controller** should receive and orchestrate orders from the
    outside and communicate with the swarm.
  """

  alias Torrent.File.Swarm.Peer.{Pieces, Receiver, Transmitter, Controller}

  def start_link(info_hash, meta, {ip, port} = peer_address) do
    initial_state = [info_hash, peer_address, meta]
    Supervisor.start_link(__MODULE__, initial_state, name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def init([info_hash, peer_address, meta]) do
    children = [
      worker(Pieces, [info_hash, peer_address, Map.take(meta, ["length", "piece length"])]),
      worker(Receiver, [info_hash, peer_address]),
      worker(Transmitter, [info_hash, peer_address]),
      worker(Controller, [info_hash, peer_address])
    ]
    supervise(children, strategy: :one_for_all)
  end

  def forward_socket(info_hash, peer, socket) do
    :ok = Receiver.hand_socket({info_hash, peer}, socket)
    :ok = Transmitter.hand_socket({info_hash, peer}, socket)
    :ok
  end
end
