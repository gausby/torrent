defmodule Swarm do
  use Application

  @info_hash "xxxxxxxxxxxxxxxxxxxx"

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Swarm.Info, [@info_hash]),
      worker(Swarm.Peers, [@info_hash]),
      worker(Swarm.Acceptor, [@info_hash, 29182])
      # worker(Swarm.Tracker, []),
      # worker(Swarm.Controller, [])
    ]

    opts = [strategy: :one_for_one, name: Swarm.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
