defmodule Tracker do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Tracker.Torrent.Supervisor, []),
      supervisor(Tracker.Peer.Supervisor, []),
    ]

    opts = [strategy: :one_for_one, name: Tracker.Supervisor]
    Logger.info "Starting #{__MODULE__}"
    Supervisor.start_link(children, opts)
  end
end
