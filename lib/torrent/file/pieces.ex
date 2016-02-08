defmodule Torrent.File.Pieces do
  use Supervisor

  def start_link(_default) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Torrent.File.Pieces.Controller, ["foo"]),
      worker(Torrent.File.Pieces.State, ["foo"]),
      # supervisor(Torrent.File.Pieces.Store, [])
    ]
    supervise(children, strategy: :one_for_one)
  end

end
