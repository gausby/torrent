defmodule Torrent.Supervisor do
  use Supervisor

  def start_link(opts) do
    opts = opts |> Enum.into(%{})
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    children = [
      worker(Torrent.Acceptor, [opts[:peer_id], opts[:port]]),
      worker(Torrent.PeerDiscovery, []),
      worker(Torrent.Processes, []),
      worker(Torrent.Controller, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
