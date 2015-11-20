defmodule Tracker.File.Peer do
  use Supervisor

  def start_link(info_hash, trackerid) do
    Supervisor.start_link(__MODULE__, [info_hash: info_hash, trackerid: trackerid], name: via_name(info_hash, trackerid))
  end

  defp via_name(info_hash, trackerid),
    do: {:via, :gproc, peer_name(info_hash, trackerid)}
  defp peer_name(info_hash, trackerid),
    do: {:n, :l, {__MODULE__, {info_hash, trackerid}}}

  def init(opts) do
    children = [
      worker(Tracker.File.Peer.State, [opts]),
      worker(Tracker.File.Peer.Fuse, [opts]),
      worker(Tracker.File.Peer.Announce, [opts])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
