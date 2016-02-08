defmodule Torrent.File.PieceMonitor do
  use Supervisor

  def start_link(_test) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [

    ]
    supervise(children, strategy: :one_for_one)
  end

end
