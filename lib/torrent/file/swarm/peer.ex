defmodule Torrent.File.Swarm.Peer do
  use Supervisor

  alias Torrent.File.Swarm.Peer.{Pieces, Receiver, Transmitter, Controller}

  def start_link(info_hash, meta, {ip, port} = peer_address) do
    Supervisor.start_link(__MODULE__, [info_hash, peer_address, meta], name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def init([info_hash, peer_address, meta]) do
    children = [
      worker(Pieces, [info_hash, peer_address, Map.get(meta, "length")]),
      worker(Controller, [info_hash, peer_address]),
      worker(Receiver, [info_hash, peer_address]),
      worker(Transmitter, [info_hash, peer_address])
    ]
    supervise(children, strategy: :one_for_all)
  end

  def forward_socket(info_hash, peer, socket) do
    Receiver.hand_socket({info_hash, peer}, socket)
    Transmitter.hand_socket({info_hash, peer}, socket)
    :ok
  end
end
