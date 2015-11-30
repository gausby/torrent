defmodule Tracker do
  use Application
  use Supervisor
  require Logger

  def start(_type, _args) do
    __MODULE__.start_link
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Tracker.File, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

# defmodule Tracker do
#   use Application
#   require Logger

#   def start(_type, _args) do
#     import Supervisor.Spec, warn: false

#     children = [
#       supervisor(Tracker.Torrent.Supervisor, []),
#       supervisor(Tracker.Peer.Supervisor, []),
#     ]

#     opts = [strategy: :one_for_one, name: Tracker.Supervisor]
#     Logger.info "Starting #{__MODULE__}"
#     Supervisor.start_link(children, opts)
#   end
# end
