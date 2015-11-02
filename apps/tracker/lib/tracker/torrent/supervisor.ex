defmodule Tracker.Torrent.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Tracker.Torrent, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def add(metainfo) do
    Supervisor.start_child(__MODULE__, [metainfo])
  end
end
