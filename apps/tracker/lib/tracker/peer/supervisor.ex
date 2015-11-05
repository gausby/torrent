defmodule Tracker.Peer.Supervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Tracker.Peer, [], restart: :transient)
    ]

    Logger.info "Starting #{__MODULE__}"
    supervise(children, strategy: :simple_one_for_one)
  end
end
