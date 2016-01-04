defmodule Torrent.File.Swarm.Peer do
  use Supervisor

  alias Torrent.File.Swarm.Peer.Pieces
  alias Torrent.File.Swarm.Peer.Receiver
  alias Torrent.File.Swarm.Peer.Transmitter

  def start_link(info_hash, {ip, port} = peer_address) do
    Supervisor.start_link(__MODULE__, [info_hash, peer_address], name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def init(opts) do
    children = [
      worker(Pieces, opts),
      worker(Receiver, opts),
      worker(Transmitter, opts)
    ]
    supervise(children, strategy: :one_for_all)
  end

  def forward_socket(info_hash, peer, socket) do
    Receiver.hand_socket({info_hash, peer}, socket)
    Transmitter.hand_socket({info_hash, peer}, socket)
    :ok
  end
end
